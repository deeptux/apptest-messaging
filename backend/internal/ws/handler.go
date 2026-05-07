package ws

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	firebaseauth "firebase.google.com/go/v4/auth"
	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"

	"github.com/apptest-messaging/backend/internal/services"
)

type Conn struct {
	ws   *websocket.Conn
	send chan []byte
}

func (c *Conn) TrySend(b []byte) {
	select {
	case c.send <- b:
	default:
		_ = c.ws.Close()
	}
}

type HandlerDeps struct {
	Firebase *firebaseauth.Client
	Me       *services.MeService
	Hub      *Hub

	AllowedOrigins []string
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  4096,
	WriteBufferSize: 4096,
	CheckOrigin: func(r *http.Request) bool {
		origin := strings.TrimSpace(r.Header.Get("Origin"))
		if origin == "" {
			return true
		}
		return false
	},
}

func Handler(deps HandlerDeps) gin.HandlerFunc {
	return func(c *gin.Context) {
		upgrader.CheckOrigin = func(r *http.Request) bool {
			origin := strings.TrimSpace(r.Header.Get("Origin"))
			if origin == "" {
				return true
			}
			for _, a := range deps.AllowedOrigins {
				if a == origin {
					return true
				}
			}
			return false
		}

		wsConn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			return
		}
		conn := &Conn{ws: wsConn, send: make(chan []byte, 32)}
		defer func() { _ = wsConn.Close() }()

		wsConn.SetReadLimit(1 << 20) // 1MB

		userID, firebaseUID, ok := authHandshake(c.Request, deps.Firebase, deps.Me, wsConn)
		if !ok {
			return
		}

		deps.Hub.Register(userID, conn)
		defer deps.Hub.Unregister(userID, conn)

		_ = writeEnvelope(wsConn, EnvelopeV1{
			V: ProtocolVersionV1,
			T: EventAuthOK,
			Data: mustMarshal(map[string]any{
				"userId":      userID,
				"firebaseUid": firebaseUID,
				"serverTime":  time.Now().UTC().Format(time.RFC3339),
			}),
		})

		done := make(chan struct{})
		go func() {
			defer close(done)
			for msg := range conn.send {
				_ = wsConn.SetWriteDeadline(time.Now().Add(10 * time.Second))
				if err := wsConn.WriteMessage(websocket.TextMessage, msg); err != nil {
					return
				}
			}
		}()

		for {
			_, b, err := wsConn.ReadMessage()
			if err != nil {
				break
			}
			var env EnvelopeV1
			if err := json.Unmarshal(b, &env); err != nil {
				_ = sendErr(wsConn, ErrBadRequest, "invalid json")
				continue
			}
			if env.V != ProtocolVersionV1 {
				_ = sendErr(wsConn, ErrBadRequest, "unsupported protocol version")
				continue
			}
			switch env.T {
			case EventPing:
				_ = writeEnvelope(wsConn, EnvelopeV1{
					V:    ProtocolVersionV1,
					T:    EventPong,
					ID:   env.ID,
					Data: env.Data,
				})
			default:
				_ = sendErr(wsConn, ErrBadRequest, "unknown event")
			}
		}

		close(conn.send)
		<-done
	}
}

func authHandshake(r *http.Request, fb *firebaseauth.Client, me *services.MeService, wsConn *websocket.Conn) (userID, firebaseUID string, ok bool) {
	_ = wsConn.SetReadDeadline(time.Now().Add(10 * time.Second))
	_, b, err := wsConn.ReadMessage()
	if err != nil {
		return "", "", false
	}
	_ = wsConn.SetReadDeadline(time.Time{})

	var env EnvelopeV1
	if err := json.Unmarshal(b, &env); err != nil {
		_ = sendAuthErr(wsConn, "invalid json")
		return "", "", false
	}
	if env.V != ProtocolVersionV1 || env.T != EventAuth {
		_ = sendAuthErr(wsConn, "first message must be auth")
		return "", "", false
	}
	var data struct {
		IDToken string `json:"idToken"`
	}
	if err := json.Unmarshal(env.Data, &data); err != nil || strings.TrimSpace(data.IDToken) == "" {
		_ = sendAuthErr(wsConn, "missing idToken")
		return "", "", false
	}

	tok, err := fb.VerifyIDToken(r.Context(), strings.TrimSpace(data.IDToken))
	if err != nil {
		_ = sendAuthErr(wsConn, "invalid token")
		return "", "", false
	}

	prof, err := me.SyncFromToken(r.Context(), tok)
	if err != nil {
		_ = sendAuthErr(wsConn, "failed to sync profile")
		return "", "", false
	}
	return prof.UserID, prof.FirebaseUID, true
}

func sendAuthErr(wsConn *websocket.Conn, message string) error {
	return writeEnvelope(wsConn, EnvelopeV1{
		V: ProtocolVersionV1,
		T: EventAuthErr,
		Data: mustMarshal(map[string]any{
			"code":    ErrUnauthorized,
			"message": message,
		}),
	})
}

func sendErr(wsConn *websocket.Conn, code, message string) error {
	return writeEnvelope(wsConn, EnvelopeV1{
		V: ProtocolVersionV1,
		T: EventErr,
		Data: mustMarshal(map[string]any{
			"code":    code,
			"message": message,
		}),
	})
}

func writeEnvelope(wsConn *websocket.Conn, env EnvelopeV1) error {
	b, err := json.Marshal(env)
	if err != nil {
		return err
	}
	_ = wsConn.SetWriteDeadline(time.Now().Add(10 * time.Second))
	return wsConn.WriteMessage(websocket.TextMessage, b)
}

func mustMarshal(v any) json.RawMessage {
	b, _ := json.Marshal(v)
	return b
}
