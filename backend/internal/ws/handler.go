package ws

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	firebaseauth "firebase.google.com/go/v4/auth"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/gorilla/websocket"

	"github.com/apptest-messaging/backend/internal/repositories"
	"github.com/apptest-messaging/backend/internal/services"
)

const (
	writeWait = 10 * time.Second
	pongWait  = 70 * time.Second
	// pingPeriod must be less than pongWait.
	pingPeriod     = 30 * time.Second
	maxMessageSize = 1 << 20 // 1MB
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
	Convs    *repositories.ConversationRepository
	Msgs     *repositories.MessageRepository

	AllowedOrigins []string
}

func originAllowed(allowedOrigins []string, origin string) bool {
	for _, a := range allowedOrigins {
		a = strings.TrimSpace(a)
		if a == "" {
			continue
		}
		if a == "*" {
			return true
		}
		if strings.HasSuffix(a, "*") {
			prefix := strings.TrimSuffix(a, "*")
			if strings.HasPrefix(origin, prefix) {
				return true
			}
			continue
		}
		if origin == a {
			return true
		}
	}
	return false
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
			return originAllowed(deps.AllowedOrigins, origin)
		}

		wsConn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
		if err != nil {
			return
		}
		conn := &Conn{ws: wsConn, send: make(chan []byte, 32)}
		defer func() { _ = wsConn.Close() }()

		wsConn.SetReadLimit(maxMessageSize)

		userID, firebaseUID, ok := authHandshake(c.Request, deps.Firebase, deps.Me, wsConn)
		if !ok {
			return
		}
		selfID, err := uuid.Parse(userID)
		if err != nil {
			_ = sendAuthErr(wsConn, "invalid user id")
			return
		}

		deps.Hub.Register(userID, conn)
		defer deps.Hub.Unregister(userID, conn)

		_ = wsConn.SetReadDeadline(time.Now().Add(pongWait))
		wsConn.SetPongHandler(func(string) error {
			_ = wsConn.SetReadDeadline(time.Now().Add(pongWait))
			return nil
		})

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
			pingTicker := time.NewTicker(pingPeriod)
			defer pingTicker.Stop()

			for {
				select {
				case msg, ok := <-conn.send:
					if !ok {
						return
					}
					_ = wsConn.SetWriteDeadline(time.Now().Add(writeWait))
					if err := wsConn.WriteMessage(websocket.TextMessage, msg); err != nil {
						return
					}
				case <-pingTicker.C:
					_ = wsConn.SetWriteDeadline(time.Now().Add(writeWait))
					if err := wsConn.WriteMessage(websocket.PingMessage, nil); err != nil {
						return
					}
				}
			}
		}()

		for {
			_ = wsConn.SetReadDeadline(time.Now().Add(pongWait))
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
			case EventMsgSend:
				if strings.TrimSpace(env.ID) == "" {
					_ = sendErr(wsConn, ErrBadRequest, "missing id")
					continue
				}
				var data struct {
					ConversationID string `json:"conversationId"`
					Body           string `json:"body"`
					ReplyToSeq     *int64 `json:"replyToSeq"`
				}
				if err := json.Unmarshal(env.Data, &data); err != nil {
					_ = sendErr(wsConn, ErrBadRequest, "invalid data")
					continue
				}
				convID, err := uuid.Parse(strings.TrimSpace(data.ConversationID))
				if err != nil {
					_ = sendErr(wsConn, ErrBadRequest, "invalid conversationId")
					continue
				}
				body := strings.TrimSpace(data.Body)
				if body == "" {
					_ = sendErr(wsConn, ErrBadRequest, "empty body")
					continue
				}

				isMember, err := deps.Convs.IsMember(c.Request.Context(), convID, selfID)
				if err != nil || !isMember {
					_ = sendErr(wsConn, ErrUnauthorized, "not a member")
					continue
				}

				msg, _, err := deps.Msgs.CreateInConversation(
					c.Request.Context(),
					convID,
					selfID,
					strings.TrimSpace(env.ID),
					body,
					data.ReplyToSeq,
				)
				if err != nil {
					if errors.Is(err, repositories.ErrReplyTargetMissing) {
						_ = sendErr(wsConn, ErrBadRequest, err.Error())
						continue
					}
					_ = sendErr(wsConn, ErrInternal, "persist failed")
					continue
				}

				ackData := map[string]any{
					"conversationId": convID.String(),
					"messageId":      msg.ID.String(),
					"seq":            msg.Seq,
					"createdAt":      msg.CreatedAt.UTC().Format(time.RFC3339Nano),
				}
				if msg.ReplyToSeq != nil {
					ackData["replyToSeq"] = *msg.ReplyToSeq
				}
				ack := EnvelopeV1{
					V:    ProtocolVersionV1,
					T:    EventMsgAck,
					ID:   env.ID,
					Data: mustMarshal(ackData),
				}
				ackBytes, _ := json.Marshal(ack)
				conn.TrySend(ackBytes)

				newPayload := map[string]any{
					"conversationId": convID.String(),
					"messageId":      msg.ID.String(),
					"seq":            msg.Seq,
					"senderUserId":   msg.SenderUserID.String(),
					"body":           msg.Body,
					"createdAt":      msg.CreatedAt.UTC().Format(time.RFC3339Nano),
					"deliveredAt":    nil,
				}
				if msg.ReplyToSeq != nil {
					newPayload["replyToSeq"] = *msg.ReplyToSeq
				}
				newEnv := EnvelopeV1{
					V:    ProtocolVersionV1,
					T:    EventMsgNew,
					Data: mustMarshal(newPayload),
				}
				newBytes, _ := json.Marshal(newEnv)

				memberIDs, err := deps.Convs.ListMemberUserIDs(c.Request.Context(), convID)
				if err != nil {
					_ = sendErr(wsConn, ErrInternal, "fanout failed")
					continue
				}
				for _, uid := range memberIDs {
					deps.Hub.SendToUser(uid.String(), newBytes)
				}
			case EventMsgDelivered:
				var data struct {
					ConversationID string `json:"conversationId"`
					Seq            int64  `json:"seq"`
				}
				if err := json.Unmarshal(env.Data, &data); err != nil {
					_ = sendErr(wsConn, ErrBadRequest, "invalid data")
					continue
				}
				convID, err := uuid.Parse(strings.TrimSpace(data.ConversationID))
				if err != nil || data.Seq <= 0 {
					_ = sendErr(wsConn, ErrBadRequest, "invalid delivered ack")
					continue
				}
				isMember, err := deps.Convs.IsMember(c.Request.Context(), convID, selfID)
				if err != nil || !isMember {
					_ = sendErr(wsConn, ErrUnauthorized, "not a member")
					continue
				}
				senderID, deliveredAt, _, err := deps.Msgs.MarkDelivered(c.Request.Context(), convID, data.Seq)
				if err != nil {
					_ = sendErr(wsConn, ErrInternal, "delivered update failed")
					continue
				}
				if senderID == selfID {
					continue
				}
				ev := EnvelopeV1{
					V: ProtocolVersionV1,
					T: EventMsgDelivered,
					Data: mustMarshal(map[string]any{
						"conversationId": convID.String(),
						"seq":            data.Seq,
						"deliveredAt":    deliveredAt.UTC().Format(time.RFC3339Nano),
					}),
				}
				b2, _ := json.Marshal(ev)
				deps.Hub.SendToUser(senderID.String(), b2)
			case EventMsgDelete:
				var data struct {
					ConversationID string `json:"conversationId"`
					Seq            int64  `json:"seq"`
				}
				if err := json.Unmarshal(env.Data, &data); err != nil {
					_ = sendErr(wsConn, ErrBadRequest, "invalid data")
					continue
				}
				convID, err := uuid.Parse(strings.TrimSpace(data.ConversationID))
				if err != nil || data.Seq <= 0 {
					_ = sendErr(wsConn, ErrBadRequest, "invalid delete")
					continue
				}
				isMember, err := deps.Convs.IsMember(c.Request.Context(), convID, selfID)
				if err != nil || !isMember {
					_ = sendErr(wsConn, ErrUnauthorized, "not a member")
					continue
				}
				ts, err := deps.Msgs.SoftDelete(c.Request.Context(), convID, data.Seq, selfID)
				if err != nil {
					_ = sendErr(wsConn, ErrUnauthorized, "delete rejected")
					continue
				}
				ev := EnvelopeV1{
					V: ProtocolVersionV1,
					T: EventMsgDeleted,
					Data: mustMarshal(map[string]any{
						"conversationId": convID.String(),
						"seq":            data.Seq,
						"deletedAt":      ts.UTC().Format(time.RFC3339Nano),
						"body":           "Message deleted",
					}),
				}
				b2, _ := json.Marshal(ev)
				memberIDs, _ := deps.Convs.ListMemberUserIDs(c.Request.Context(), convID)
				for _, uid := range memberIDs {
					deps.Hub.SendToUser(uid.String(), b2)
				}
			case EventReadMark:
				var data struct {
					ConversationID string `json:"conversationId"`
					LastReadSeq    int64  `json:"lastReadSeq"`
				}
				if err := json.Unmarshal(env.Data, &data); err != nil {
					_ = sendErr(wsConn, ErrBadRequest, "invalid data")
					continue
				}
				convID, err := uuid.Parse(strings.TrimSpace(data.ConversationID))
				if err != nil || data.LastReadSeq < 0 {
					_ = sendErr(wsConn, ErrBadRequest, "invalid read mark")
					continue
				}
				isMember, err := deps.Convs.IsMember(c.Request.Context(), convID, selfID)
				if err != nil || !isMember {
					_ = sendErr(wsConn, ErrUnauthorized, "not a member")
					continue
				}
				_, _ = deps.Convs.MarkRead(c.Request.Context(), convID, selfID, data.LastReadSeq)
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
	_ = wsConn.SetWriteDeadline(time.Now().Add(writeWait))
	return wsConn.WriteMessage(websocket.TextMessage, b)
}

func mustMarshal(v any) json.RawMessage {
	b, _ := json.Marshal(v)
	return b
}
