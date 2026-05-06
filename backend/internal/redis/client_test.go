package redis

import (
	"context"
	"testing"
	"time"

	miniredis "github.com/alicebob/miniredis/v2"
)

func TestSetSessionUser_SetsAndRefreshesTTL(t *testing.T) {
	t.Parallel()

	mr := miniredis.RunT(t)
	ctx := context.Background()

	c, err := New("redis://" + mr.Addr() + "/0")
	if err != nil {
		t.Fatalf("New redis client: %v", err)
	}
	defer c.Close()

	uid := "uid123"
	payload := SessionPayload{
		UserID:         "user-1",
		Email:          "a@example.com",
		DisplayName:    "A",
		LastVerifiedAt: time.Now().UTC().Format(time.RFC3339),
	}

	if err := c.SetSessionUser(ctx, uid, payload); err != nil {
		t.Fatalf("SetSessionUser: %v", err)
	}

	key := "session:user:" + uid
	if !mr.Exists(key) {
		t.Fatalf("expected key %q to exist", key)
	}
	if got := mr.TTL(key); got != sessionTTL {
		t.Fatalf("expected TTL=%v, got %v", sessionTTL, got)
	}

	// Advance time in redis, then call again to refresh TTL back to sessionTTL.
	mr.FastForward(10 * time.Second)
	if got := mr.TTL(key); got >= sessionTTL {
		t.Fatalf("expected TTL to decrease after fast-forward, got %v", got)
	}

	if err := c.SetSessionUser(ctx, uid, payload); err != nil {
		t.Fatalf("SetSessionUser (refresh): %v", err)
	}
	if got := mr.TTL(key); got != sessionTTL {
		t.Fatalf("expected TTL refreshed back to %v, got %v", sessionTTL, got)
	}
}

