package repositories

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// User is a row from users (DB source of truth for profile fields).
type User struct {
	ID          uuid.UUID
	FirebaseUID string
	Email       *string
	DisplayName *string
	PhotoURL    *string
}

// UserRepository persists users in Postgres.
type UserRepository struct {
	pool *pgxpool.Pool
}

func NewUserRepository(pool *pgxpool.Pool) *UserRepository {
	return &UserRepository{pool: pool}
}

// UpsertByFirebaseUID inserts or updates a user by firebase_uid and returns the internal id.
func (r *UserRepository) UpsertByFirebaseUID(ctx context.Context, firebaseUID, email, displayName, photoURL string) (uuid.UUID, error) {
	const q = `
INSERT INTO users (firebase_uid, email, display_name, photo_url)
VALUES ($1, NULLIF($2, ''), NULLIF($3, ''), NULLIF($4, ''))
ON CONFLICT (firebase_uid) DO UPDATE SET
  email = COALESCE(EXCLUDED.email, users.email),
  display_name = EXCLUDED.display_name,
  photo_url = EXCLUDED.photo_url,
  updated_at = now()
RETURNING id`

	var id uuid.UUID
	err := r.pool.QueryRow(ctx, q, firebaseUID, email, displayName, photoURL).Scan(&id)
	if err != nil {
		return uuid.Nil, fmt.Errorf("upsert user: %w", err)
	}
	return id, nil
}

// GetByFirebaseUID loads a user by firebase_uid.
func (r *UserRepository) GetByFirebaseUID(ctx context.Context, firebaseUID string) (*User, error) {
	const q = `
SELECT id, firebase_uid, email, display_name, photo_url
FROM users
WHERE firebase_uid = $1`

	row := r.pool.QueryRow(ctx, q, firebaseUID)
	var u User
	var email, displayName, photoURL *string
	if err := row.Scan(&u.ID, &u.FirebaseUID, &email, &displayName, &photoURL); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	u.Email = email
	u.DisplayName = displayName
	u.PhotoURL = photoURL
	return &u, nil
}

type UserSearchResult struct {
	ID          uuid.UUID
	Email       string
	DisplayName *string
	PhotoURL    *string
}

func (r *UserRepository) SearchByEmailPrefix(ctx context.Context, prefix string, limit int) ([]UserSearchResult, error) {
	prefix = strings.TrimSpace(prefix)
	if prefix == "" {
		return nil, nil
	}
	if limit <= 0 || limit > 50 {
		limit = 10
	}
	const q = `
SELECT id, email, display_name, photo_url
FROM users
WHERE email IS NOT NULL
  AND email ILIKE ($1 || '%')
ORDER BY email ASC
LIMIT $2`
	rows, err := r.pool.Query(ctx, q, prefix, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []UserSearchResult
	for rows.Next() {
		var r0 UserSearchResult
		var dn, pu *string
		if err := rows.Scan(&r0.ID, &r0.Email, &dn, &pu); err != nil {
			return nil, err
		}
		r0.DisplayName = dn
		r0.PhotoURL = pu
		out = append(out, r0)
	}
	return out, rows.Err()
}
