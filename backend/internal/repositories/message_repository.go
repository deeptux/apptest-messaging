package repositories

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type MessageRow struct {
	ID             uuid.UUID
	ConversationID uuid.UUID
	Seq            int64
	SenderUserID   uuid.UUID
	Body           string
	CreatedAt      time.Time
	DeliveredAt    *time.Time
}

type MessageRepository struct {
	pool *pgxpool.Pool
}

func NewMessageRepository(pool *pgxpool.Pool) *MessageRepository {
	return &MessageRepository{pool: pool}
}

func (r *MessageRepository) ListByConversationBeforeSeq(ctx context.Context, conversationID uuid.UUID, beforeSeq *int64, limit int) ([]MessageRow, error) {
	if limit <= 0 || limit > 200 {
		limit = 50
	}

	var rows pgx.Rows
	var err error
	if beforeSeq != nil {
		const q = `
SELECT id, conversation_id, seq, sender_user_id, body, created_at, delivered_at
FROM messages
WHERE conversation_id = $1 AND seq < $2
ORDER BY seq DESC
LIMIT $3`
		rows, err = r.pool.Query(ctx, q, conversationID, *beforeSeq, limit)
	} else {
		const q = `
SELECT id, conversation_id, seq, sender_user_id, body, created_at, delivered_at
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
		if err := rows.Scan(&m.ID, &m.ConversationID, &m.Seq, &m.SenderUserID, &m.Body, &m.CreatedAt, &deliveredAt); err != nil {
			return nil, err
		}
		m.DeliveredAt = deliveredAt
		out = append(out, m)
	}
	return out, rows.Err()
}
