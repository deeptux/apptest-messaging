package services

import (
	"context"
	"fmt"
	"strings"
	"time"

	firebaseauth "firebase.google.com/go/v4/auth"

	"github.com/apptest-messaging/backend/internal/redis"
	"github.com/apptest-messaging/backend/internal/repositories"
)

// MeProfile is returned as JSON for GET /api/v1/me (camelCase in HTTP layer).
type MeProfile struct {
	UserID            string  `json:"userId"`
	FirebaseUID       string  `json:"firebaseUid"`
	Email             *string `json:"email,omitempty"`
	DisplayName       *string `json:"displayName,omitempty"`
	PhotoURL          *string `json:"photoUrl,omitempty"`
	AnonymousUsername *string `json:"anonymousUsername,omitempty"`
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

	displayName := claimString(tok.Claims, "display_name")
	if strings.TrimSpace(displayName) == "" {
		displayName = displayNameFromToken(tok)
	}

	existing, err := s.users.GetByFirebaseUID(ctx, firebaseUID)
	if err != nil {
		return nil, err
	}

	emailStr := claimString(tok.Claims, "email")
	if existing != nil && existing.AnonymousUsername != nil && strings.TrimSpace(*existing.AnonymousUsername) != "" {
		emailStr = ""
		if strings.TrimSpace(displayName) == "" && existing.DisplayName != nil {
			displayName = *existing.DisplayName
		}
	}

	photoURL := pictureFromToken(tok)
	if existing != nil && existing.AnonymousUsername != nil && strings.TrimSpace(*existing.AnonymousUsername) != "" {
		if photoURL == "" && existing.PhotoURL != nil {
			photoURL = *existing.PhotoURL
		}
	}

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
		UserID:            u.ID.String(),
		FirebaseUID:       u.FirebaseUID,
		Email:             u.Email,
		DisplayName:       u.DisplayName,
		PhotoURL:          u.PhotoURL,
		AnonymousUsername: u.AnonymousUsername,
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
