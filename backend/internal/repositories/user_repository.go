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
	ID                uuid.UUID
	FirebaseUID       string
	Email             *string
	DisplayName       *string
	PhotoURL          *string
	AnonymousUsername *string
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
  display_name = CASE
    WHEN COALESCE(EXCLUDED.display_name, '') = '' THEN users.display_name
    ELSE EXCLUDED.display_name
  END,
  photo_url = CASE
    WHEN COALESCE(EXCLUDED.photo_url, '') = '' THEN users.photo_url
    ELSE EXCLUDED.photo_url
  END,
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
SELECT id, firebase_uid, email, display_name, photo_url, anonymous_username
FROM users
WHERE firebase_uid = $1`

	row := r.pool.QueryRow(ctx, q, firebaseUID)
	var u User
	var email, displayName, photoURL, anon *string
	if err := row.Scan(&u.ID, &u.FirebaseUID, &email, &displayName, &photoURL, &anon); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	u.Email = email
	u.DisplayName = displayName
	u.PhotoURL = photoURL
	u.AnonymousUsername = anon
	return &u, nil
}

type UserSearchResult struct {
	ID                uuid.UUID
	Email             string
	DisplayName       *string
	PhotoURL          *string
	AnonymousUsername *string
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
SELECT id, COALESCE(email, '') AS email, display_name, photo_url, anonymous_username
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
		var dn, pu, an *string
		if err := rows.Scan(&r0.ID, &r0.Email, &dn, &pu, &an); err != nil {
			return nil, err
		}
		r0.DisplayName = dn
		r0.PhotoURL = pu
		r0.AnonymousUsername = an
		out = append(out, r0)
	}
	return out, rows.Err()
}

// SearchContactPrefix searches others by email prefix, anonymous handle prefix, or display name substring.
func (r *UserRepository) SearchContactPrefix(ctx context.Context, self uuid.UUID, needle string, limit int) ([]UserSearchResult, error) {
	needle = strings.TrimSpace(needle)
	if needle == "" || len(needle) > 72 {
		return nil, nil
	}
	if limit <= 0 || limit > 50 {
		limit = 10
	}
	const sq = `
SELECT id, COALESCE(email, '') AS email, display_name, photo_url, anonymous_username
FROM users
WHERE id <> $1
  AND (
    (email IS NOT NULL AND email ILIKE ($2::text || '%'))
    OR (anonymous_username IS NOT NULL AND anonymous_username ILIKE ($2::text || '%'))
    OR (display_name IS NOT NULL AND display_name ILIKE ('%' || $2 || '%'))
  )
ORDER BY COALESCE(display_name, email, anonymous_username) ASC
LIMIT $3`
	rows, err := r.pool.Query(ctx, sq, self, needle, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []UserSearchResult
	for rows.Next() {
		var r0 UserSearchResult
		var dn, pu, an *string
		if err := rows.Scan(&r0.ID, &r0.Email, &dn, &pu, &an); err != nil {
			return nil, err
		}
		r0.DisplayName = dn
		r0.PhotoURL = pu
		r0.AnonymousUsername = an
		out = append(out, r0)
	}
	return out, rows.Err()
}

// GetByAnonymousUsername returns demo anonymous row keyed by lowercase handle.
func (r *UserRepository) GetByAnonymousUsername(ctx context.Context, normalizedUsername string) (*User, error) {
	normalizedUsername = strings.TrimSpace(strings.ToLower(normalizedUsername))
	const q = `
SELECT id, firebase_uid, email, display_name, photo_url, anonymous_username
FROM users
WHERE lower(trim(anonymous_username)) = lower($1)
LIMIT 1`
	row := r.pool.QueryRow(ctx, q, normalizedUsername)
	var u User
	var email, displayName, photoURL, anon *string
	if err := row.Scan(&u.ID, &u.FirebaseUID, &email, &displayName, &photoURL, &anon); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	u.Email = email
	u.DisplayName = displayName
	u.PhotoURL = photoURL
	u.AnonymousUsername = anon
	return &u, nil
}

// ExistsDisplayNameCI checks display_name collisions case-insensitive (ASCII demo).
func (r *UserRepository) ExistsDisplayNameCI(ctx context.Context, display string) (bool, error) {
	display = strings.TrimSpace(display)
	if display == "" {
		return false, nil
	}
	const q = `SELECT EXISTS(SELECT 1 FROM users WHERE lower(trim(display_name)) = lower(trim($1)) LIMIT 1)`
	var ok bool
	if err := r.pool.QueryRow(ctx, q, display).Scan(&ok); err != nil {
		return false, err
	}
	return ok, nil
}

// InsertAnonymousDemo inserts a Firebase-backed anonymous demo account row.
func (r *UserRepository) InsertAnonymousDemo(ctx context.Context, firebaseUID, normalizedUsername, displayName string) (uuid.UUID, error) {
	normalizedUsername = strings.TrimSpace(strings.ToLower(normalizedUsername))
	const q = `
INSERT INTO users (firebase_uid, email, display_name, photo_url, anonymous_username)
VALUES ($1, NULL, $2, NULL, $3)
RETURNING id`
	var id uuid.UUID
	err := r.pool.QueryRow(ctx, q, firebaseUID, strings.TrimSpace(displayName), normalizedUsername).Scan(&id)
	if err != nil {
		return uuid.Nil, err
	}
	return id, nil
}

// DeleteByFirebaseUID removes a user row — used only to roll back a failed signup.
func (r *UserRepository) DeleteByFirebaseUID(ctx context.Context, firebaseUID string) error {
	const q = `DELETE FROM users WHERE firebase_uid = $1`
	_, err := r.pool.Exec(ctx, q, firebaseUID)
	return err
}
