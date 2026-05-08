## WebSocket protocol v1 (Phase 2 — chat works)

JSON is **camelCase** across the system. Message ordering is **`seq`**
(canonical), and timestamps are RFC3339 (`createdAt`, `deliveredAt`).

### Endpoint

- **URL**: `GET /ws`
- **Auth**: first client message must be `auth` with a Firebase **ID token**
  (same token type used for REST `Authorization: Bearer ...`).

### Envelope (v1)

All WS frames are JSON objects:

```json
{ "v": 1, "t": "event.name", "id": "clientGeneratedId", "data": { } }
```

- `v` (number, required): protocol version (always `1` in Phase 2).
- `t` (string, required): event type.
- `id` (string, optional): client-generated idempotency key / correlation id.
- `data` (object, optional): payload (shape depends on `t`).

### Event list

Client → Server:

- `auth` data `{ "idToken": "..." }`
- `ping` data `{ "ts": "2026-05-08T00:00:00Z" }` (optional `ts`)
- `msg.send` data `{ "conversationId": "...", "body": "utf8 text" }`
- `msg.delivered` data `{ "conversationId": "...", "seq": 123 }`
- `read.mark` data `{ "conversationId": "...", "lastReadSeq": 123 }`

Server → Client:

- `auth.ok` data `{ "userId": "...", "firebaseUid": "...", "serverTime": "..." }`
- `auth.err` data `{ "code": "unauthorized", "message": "invalid token" }`
- `pong` data `{ "ts": "..." }`
- `msg.ack` data `{ "conversationId": "...", "messageId": "...", "seq": 123, "createdAt": "..." }`
- `msg.new` data `{ "conversationId": "...", "messageId": "...", "seq": 123, "senderUserId": "...", "body": "...", "createdAt": "...", "deliveredAt": null }`
- `msg.delivered` data `{ "conversationId": "...", "seq": 123, "deliveredAt": "..." }`
- `conv.updated` data `{ "conversationId": "...", "lastSeq": 123, "lastMessageAt": "..." }`
- `err` data `{ "code": "badRequest", "message": "..." }`

Notes:

- `msg.send` uses envelope `id` as the **idempotency key** within the
  conversation. Clients should set it to a stable UUID per send attempt.
- `msg.ack` is sent only to the sender. `msg.new` is fanned out to all members
  (including the sender) to keep all clients in sync.

### Error codes

- `unauthorized`
- `badRequest`
- `notFound`
- `conflict`
- `rateLimited`
- `internal`

### Heartbeat + timeouts

- Client sends `ping` every **~25s** while connected.
- Server responds with `pong`.
- Server may close the connection if it receives **no frames** for ~70s (to avoid
  zombie sockets). The server also sends periodic WS-level ping frames.

### Reconnect + “missed messages” sync

Railway may sleep when idle; reconnects are expected.

- On reconnect, client should:
  - REST-sync inbox.
  - For the active conversation, fetch latest messages and then paginate older
    by `beforeSeq` as needed.
  - Re-send any locally pending messages with the **same envelope `id`** so the
    server dedupes on `(conversationId, idempotencyKey)`.

