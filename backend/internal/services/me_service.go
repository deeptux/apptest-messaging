package services

import (
	"context"
	"fmt"
	"time"

	firebaseauth "firebase.google.com/go/v4/auth"

	"github.com/apptest-messaging/backend/internal/redis"
	"github.com/apptest-messaging/backend/internal/repositories"
)

// MeProfile is returned as JSON for GET /api/v1/me (camelCase in HTTP layer).
type MeProfile struct {
	UserID      string  `json:"userId"`
	FirebaseUID string  `json:"firebaseUid"`
	Email       *string `json:"email,omitempty"`
	DisplayName *string `json:"displayName,omitempty"`
	PhotoURL    *string `json:"photoUrl,omitempty"`
}

// MeService upserts the user row and Redis session after Firebase verification.
type MeService struct {
	users *repositories.UserRepository
	cache *redis.Client
}

func NewMeService(users *repositories.UserRepository, cache *redis.Client) *MeService {
	return &MeService{users: users, cache: cache}
}

// SyncFromToken upserts from Firebase ID token claims and returns persisted profile.
func (s *MeService) SyncFromToken(ctx context.Context, tok *firebaseauth.Token) (*MeProfile, error) {
	if tok == nil {
		return nil, fmt.Errorf("nil token")
	}

	firebaseUID := tok.UID
	if firebaseUID == "" {
		return nil, fmt.Errorf("missing uid claim")
	}

	// Firebase ID tokens expose standard OIDC-style claims in Claims (email, name, picture).
	emailStr := claimString(tok.Claims, "email")
	displayName := displayNameFromToken(tok)
	photoURL := pictureFromToken(tok)

	id, err := s.users.UpsertByFirebaseUID(ctx, firebaseUID, emailStr, displayName, photoURL)
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC().Format(time.RFC3339)
	sess := redis.SessionPayload{
		UserID:         id.String(),
		Email:          emailStr,
		DisplayName:    displayName,
		LastVerifiedAt: now,
	}
	if err := s.cache.SetSessionUser(ctx, firebaseUID, sess); err != nil {
		return nil, fmt.Errorf("redis session: %w", err)
	}

	u, err := s.users.GetByFirebaseUID(ctx, firebaseUID)
	if err != nil {
		return nil, err
	}
	if u == nil {
		return nil, fmt.Errorf("user missing after upsert")
	}

	return toMeProfile(u), nil
}

func toMeProfile(u *repositories.User) *MeProfile {
	return &MeProfile{
		UserID:      u.ID.String(),
		FirebaseUID: u.FirebaseUID,
		Email:       u.Email,
		DisplayName: u.DisplayName,
		PhotoURL:    u.PhotoURL,
	}
}

func displayNameFromToken(tok *firebaseauth.Token) string {
	if v := claimString(tok.Claims, "name"); v != "" {
		return v
	}
	return claimString(tok.Claims, "display_name")
}

func pictureFromToken(tok *firebaseauth.Token) string {
	if v := claimString(tok.Claims, "picture"); v != "" {
		return v
	}
	return claimString(tok.Claims, "photo_url")
}

func claimString(m map[string]interface{}, key string) string {
	if m == nil {
		return ""
	}
	raw, ok := m[key]
	if !ok || raw == nil {
		return ""
	}
	s, ok := raw.(string)
	if !ok {
		return ""
	}
	return s
}
