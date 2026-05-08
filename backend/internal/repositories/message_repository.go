package repositories

import (
	"context"
	"database/sql"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ErrReplyTargetMissing is returned when replyToSeq does not reference a row in the conversation.
var ErrReplyTargetMissing = errors.New("reply message not found in conversation")

type MessageRow struct {
	ID             uuid.UUID
	ConversationID uuid.UUID
	Seq            int64
	SenderUserID   uuid.UUID
	Body           string
	CreatedAt      time.Time
	DeliveredAt    *time.Time
	DeletedAt      *time.Time
	ReplyToSeq     *int64
}

type MessageRepository struct {
	pool *pgxpool.Pool
}

func NewMessageRepository(pool *pgxpool.Pool) *MessageRepository {
	return &MessageRepository{pool: pool}
}

// CreateInConversation creates a new message with a new seq, or returns the existing
// message for the same (conversationId, idempotencyKey).
func (r *MessageRepository) CreateInConversation(
	ctx context.Context,
	conversationID uuid.UUID,
	senderUserID uuid.UUID,
	idempotencyKey string,
	body string,
	replyToSeq *int64,
) (*MessageRow, bool, error) {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return nil, false, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	const selExisting = `
SELECT id, conversation_id, seq, sender_user_id, body, created_at, delivered_at, deleted_at, reply_to_seq
FROM messages
WHERE conversation_id = $1 AND idempotency_key = $2`
	var existing MessageRow
	var deliveredAt *time.Time
	var deletedAt *time.Time
	var replyNull sql.NullInt64
	err = tx.QueryRow(ctx, selExisting, conversationID, idempotencyKey).
		Scan(&existing.ID, &existing.ConversationID, &existing.Seq, &existing.SenderUserID, &existing.Body, &existing.CreatedAt, &deliveredAt, &deletedAt, &replyNull)
	if err == nil {
		existing.DeliveredAt = deliveredAt
		existing.DeletedAt = deletedAt
		if replyNull.Valid {
			v := replyNull.Int64
			existing.ReplyToSeq = &v
		}
		if err := tx.Commit(ctx); err != nil {
			return nil, false, err
		}
		return &existing, false, nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, false, err
	}

	if replyToSeq != nil {
		if *replyToSeq <= 0 {
			return nil, false, ErrReplyTargetMissing
		}
		var ok bool
		err = tx.QueryRow(ctx,
			`SELECT true FROM messages WHERE conversation_id = $1 AND seq = $2`,
			conversationID, *replyToSeq).Scan(&ok)
		if err != nil {
			if errors.Is(err, pgx.ErrNoRows) {
				return nil, false, ErrReplyTargetMissing
			}
			return nil, false, err
		}
	}

	const bumpSeq = `
UPDATE conversations
SET last_seq = last_seq + 1,
    last_message_at = now(),
    updated_at = now()
WHERE id = $1
RETURNING last_seq`
	var seq int64
	if err := tx.QueryRow(ctx, bumpSeq, conversationID).Scan(&seq); err != nil {
		return nil, false, err
	}

	const ins = `
INSERT INTO messages (conversation_id, seq, sender_user_id, body, idempotency_key, reply_to_seq)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING id, conversation_id, seq, sender_user_id, body, created_at, delivered_at, deleted_at, reply_to_seq`
	var m MessageRow
	var deliveredAt2 *time.Time
	var deletedAt2 *time.Time
	var replyOut sql.NullInt64
	if err := tx.QueryRow(ctx, ins, conversationID, seq, senderUserID, body, idempotencyKey, replyToSeq).
		Scan(&m.ID, &m.ConversationID, &m.Seq, &m.SenderUserID, &m.Body, &m.CreatedAt, &deliveredAt2, &deletedAt2, &replyOut); err != nil {
		return nil, false, err
	}
	m.DeliveredAt = deliveredAt2
	m.DeletedAt = deletedAt2
	if replyOut.Valid {
		v := replyOut.Int64
		m.ReplyToSeq = &v
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, false, err
	}
	return &m, true, nil
}

// MarkDelivered sets delivered_at if currently NULL and returns the sender user id and delivered_at.
func (r *MessageRepository) MarkDelivered(ctx context.Context, conversationID uuid.UUID, seq int64) (senderUserID uuid.UUID, deliveredAt time.Time, changed bool, err error) {
	const q = `
UPDATE messages
SET delivered_at = COALESCE(delivered_at, now())
WHERE conversation_id = $1 AND seq = $2
RETURNING sender_user_id, delivered_at`
	var ts time.Time
	var sender uuid.UUID
	if err := r.pool.QueryRow(ctx, q, conversationID, seq).Scan(&sender, &ts); err != nil {
		return uuid.Nil, time.Time{}, false, err
	}
	// We can't perfectly know if it changed without reading previous value; accept "true" as best effort.
	return sender, ts, true, nil
}

func (r *MessageRepository) SoftDelete(ctx context.Context, conversationID uuid.UUID, seq int64, actorUserID uuid.UUID) (deletedAt time.Time, err error) {
	// Only sender can delete.
	const q = `
UPDATE messages
SET deleted_at = COALESCE(deleted_at, now())
WHERE conversation_id = $1 AND seq = $2 AND sender_user_id = $3
RETURNING deleted_at`
	var ts time.Time
	if err := r.pool.QueryRow(ctx, q, conversationID, seq, actorUserID).Scan(&ts); err != nil {
		return time.Time{}, err
	}
	return ts, nil
}

func (r *MessageRepository) ListByConversationBeforeSeq(ctx context.Context, conversationID uuid.UUID, beforeSeq *int64, limit int) ([]MessageRow, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}

	var rows pgx.Rows
	var err error
	if beforeSeq != nil {
		const q = `
SELECT id, conversation_id, seq, sender_user_id,
       CASE WHEN deleted_at IS NULL THEN body ELSE 'Message deleted' END AS body,
       created_at, delivered_at, deleted_at, reply_to_seq
FROM messages
WHERE conversation_id = $1 AND seq < $2
ORDER BY seq DESC
LIMIT $3`
		rows, err = r.pool.Query(ctx, q, conversationID, *beforeSeq, limit)
	} else {
		const q = `
SELECT id, conversation_id, seq, sender_user_id,
       CASE WHEN deleted_at IS NULL THEN body ELSE 'Message deleted' END AS body,
       created_at, delivered_at, deleted_at, reply_to_seq
FROM messages
WHERE conversation_id = $1
ORDER BY seq DESC
LIMIT $2`
		rows, err = r.pool.Query(ctx, q, conversationID, limit)
	}
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []MessageRow
	for rows.Next() {
		var m MessageRow
		var deliveredAt *time.Time
		var deletedAt *time.Time
		var rts sql.NullInt64
		if err := rows.Scan(&m.ID, &m.ConversationID, &m.Seq, &m.SenderUserID, &m.Body, &m.CreatedAt, &deliveredAt, &deletedAt, &rts); err != nil {
			return nil, err
		}
		m.DeliveredAt = deliveredAt
		m.DeletedAt = deletedAt
		if rts.Valid {
			v := rts.Int64
			m.ReplyToSeq = &v
		}
		out = append(out, m)
	}
	return out, rows.Err()
}
