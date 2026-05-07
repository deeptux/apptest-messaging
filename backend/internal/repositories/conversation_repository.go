package repositories

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Conversation struct {
	ID            uuid.UUID
	Kind          string
	DirectUser1ID *uuid.UUID
	DirectUser2ID *uuid.UUID
	LastSeq       int64
	LastMessageAt *time.Time
}

type InboxRow struct {
	ConversationID uuid.UUID
	Kind           string
	LastSeq        int64
	LastMessageAt  *time.Time
	MyLastReadSeq  int64
	OtherUserID    uuid.UUID
	OtherEmail     *string
	OtherName      *string
	OtherPhotoURL  *string
}

type ConversationRepository struct {
	pool *pgxpool.Pool
}

func NewConversationRepository(pool *pgxpool.Pool) *ConversationRepository {
	return &ConversationRepository{pool: pool}
}

func (r *ConversationRepository) UpsertDirectConversation(ctx context.Context, user1ID, user2ID uuid.UUID) (*Conversation, error) {
	const q = `
INSERT INTO conversations (kind, direct_user1_id, direct_user2_id)
VALUES ('direct', $1, $2)
ON CONFLICT (direct_user1_id, direct_user2_id) WHERE kind = 'direct'
DO UPDATE SET updated_at = now()
RETURNING id, kind, direct_user1_id, direct_user2_id, last_seq, last_message_at`
	row := r.pool.QueryRow(ctx, q, user1ID, user2ID)
	var c Conversation
	var u1, u2 uuid.UUID
	var lastAt *time.Time
	if err := row.Scan(&c.ID, &c.Kind, &u1, &u2, &c.LastSeq, &lastAt); err != nil {
		return nil, err
	}
	c.DirectUser1ID = &u1
	c.DirectUser2ID = &u2
	c.LastMessageAt = lastAt
	return &c, nil
}

func (r *ConversationRepository) EnsureMember(ctx context.Context, conversationID, userID uuid.UUID) error {
	const q = `
INSERT INTO conversation_members (conversation_id, user_id)
VALUES ($1, $2)
ON CONFLICT (conversation_id, user_id) DO NOTHING`
	_, err := r.pool.Exec(ctx, q, conversationID, userID)
	return err
}

func (r *ConversationRepository) IsMember(ctx context.Context, conversationID, userID uuid.UUID) (bool, error) {
	const q = `
SELECT 1
FROM conversation_members
WHERE conversation_id = $1 AND user_id = $2`
	var one int
	err := r.pool.QueryRow(ctx, q, conversationID, userID).Scan(&one)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

func (r *ConversationRepository) ListMemberUserIDs(ctx context.Context, conversationID uuid.UUID) ([]uuid.UUID, error) {
	const q = `
SELECT user_id
FROM conversation_members
WHERE conversation_id = $1`
	rows, err := r.pool.Query(ctx, q, conversationID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

func (r *ConversationRepository) ListInbox(ctx context.Context, userID uuid.UUID, limit int) ([]InboxRow, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	const q = `
SELECT
  c.id,
  c.kind,
  c.last_seq,
  c.last_message_at,
  cm.last_read_seq,
  ou.id,
  ou.email,
  ou.display_name,
  ou.photo_url
FROM conversation_members cm
JOIN conversations c ON c.id = cm.conversation_id
JOIN conversation_members cm2 ON cm2.conversation_id = c.id AND cm2.user_id <> $1
JOIN users ou ON ou.id = cm2.user_id
WHERE cm.user_id = $1
ORDER BY c.last_message_at DESC NULLS LAST, c.id
LIMIT $2`
	rows, err := r.pool.Query(ctx, q, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []InboxRow
	for rows.Next() {
		var r0 InboxRow
		var lastAt *time.Time
		if err := rows.Scan(
			&r0.ConversationID,
			&r0.Kind,
			&r0.LastSeq,
			&lastAt,
			&r0.MyLastReadSeq,
			&r0.OtherUserID,
			&r0.OtherEmail,
			&r0.OtherName,
			&r0.OtherPhotoURL,
		); err != nil {
			return nil, err
		}
		r0.LastMessageAt = lastAt
		out = append(out, r0)
	}
	return out, rows.Err()
}

func (r *ConversationRepository) MarkRead(ctx context.Context, conversationID, userID uuid.UUID, lastReadSeq int64) (int64, error) {
	const q = `
UPDATE conversation_members
SET last_read_seq = GREATEST(last_read_seq, $3),
    updated_at = now()
WHERE conversation_id = $1 AND user_id = $2
RETURNING last_read_seq`
	var newSeq int64
	if err := r.pool.QueryRow(ctx, q, conversationID, userID, lastReadSeq).Scan(&newSeq); err != nil {
		return 0, err
	}
	return newSeq, nil
}
