package repositories

import (
	"context"
	"errors"
	"fmt"

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
