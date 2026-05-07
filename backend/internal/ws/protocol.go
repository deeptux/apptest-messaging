package ws

import "encoding/json"

// EnvelopeV1 is the top-level WebSocket message wrapper (protocol version 1).
// JSON field names are camelCase across the system.
type EnvelopeV1 struct {
	V    int             `json:"v"`
	T    string          `json:"t"`
	ID   string          `json:"id,omitempty"`
	Data json.RawMessage `json:"data,omitempty"`
}

const ProtocolVersionV1 = 1

// Client -> Server events.
const (
	EventAuth         = "auth"
	EventPing         = "ping"
	EventMsgSend      = "msg.send"
	EventMsgDelivered = "msg.delivered"
	EventReadMark     = "read.mark"
)

// Server -> Client events.
const (
	EventAuthOK      = "auth.ok"
	EventAuthErr     = "auth.err"
	EventPong        = "pong"
	EventMsgNew      = "msg.new"
	EventMsgAck      = "msg.ack"
	EventConvUpdated = "conv.updated"
	EventErr         = "err"
)

// Error codes (used in `auth.err` and `err`).
const (
	ErrUnauthorized = "unauthorized"
	ErrBadRequest   = "badRequest"
	ErrNotFound     = "notFound"
	ErrConflict     = "conflict"
	ErrRateLimited  = "rateLimited"
	ErrInternal     = "internal"
)

