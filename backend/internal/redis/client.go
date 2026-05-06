package redis

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	libredis "github.com/redis/go-redis/v9"
)

const sessionTTL = 86400 * time.Second

// SessionPayload is stored JSON-encoded at session:user:{firebaseUID} (camelCase JSON tags).
type SessionPayload struct {
	UserID         string `json:"userId"`
	Email          string `json:"email,omitempty"`
	DisplayName    string `json:"displayName,omitempty"`
	LastVerifiedAt string `json:"lastVerifiedAt"`
}

// Client wraps go-redis with app-specific helpers.
type Client struct {
	rdb *libredis.Client
}

// New parses REDIS_URL and returns a connected client (Ping in main/ready).
func New(redisURL string) (*Client, error) {
	opt, err := libredis.ParseURL(redisURL)
	if err != nil {
		return nil, fmt.Errorf("parse redis url: %w", err)
	}
	return &Client{rdb: libredis.NewClient(opt)}, nil
}

// Raw exposes the underlying client for health checks.
func (c *Client) Raw() *libredis.Client { return c.rdb }

// Ping runs Redis PING.
func (c *Client) Ping(ctx context.Context) error {
	return c.rdb.Ping(ctx).Err()
}

// Close closes the Redis client.
func (c *Client) Close() error {
	return c.rdb.Close()
}

// SetSessionUser sets session:user:{firebaseUID} with TTL 86400s (refreshed on each call).
func (c *Client) SetSessionUser(ctx context.Context, firebaseUID string, payload SessionPayload) error {
	key := fmt.Sprintf("session:user:%s", firebaseUID)
	b, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	return c.rdb.Set(ctx, key, b, sessionTTL).Err()
}

// GetSessionUser reads session:user:{firebaseUID} (optional helper for debugging/tests).
func (c *Client) GetSessionUser(ctx context.Context, firebaseUID string) (*SessionPayload, error) {
	key := fmt.Sprintf("session:user:%s", firebaseUID)
	val, err := c.rdb.Get(ctx, key).Result()
	if err == libredis.Nil {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var p SessionPayload
	if err := json.Unmarshal([]byte(val), &p); err != nil {
		return nil, err
	}
	return &p, nil
}
