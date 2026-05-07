package config

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

// Config holds runtime configuration loaded from the environment.
type Config struct {
	Port                             string
	DatabaseURL                      string
	DatabaseSchema                   string
	RedisURL                         string
	CORSAllowedOrigins               []string
	GoogleApplicationCredentialsPath string
}

// Load reads required configuration from environment variables.
func Load() (*Config, error) {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	if _, err := strconv.Atoi(port); err != nil {
		return nil, fmt.Errorf("PORT must be numeric: %w", err)
	}

	dbURL := strings.TrimSpace(os.Getenv("DATABASE_URL"))
	if dbURL == "" {
		return nil, fmt.Errorf("DATABASE_URL is required")
	}

	redisURL := strings.TrimSpace(os.Getenv("REDIS_URL"))
	if redisURL == "" {
		return nil, fmt.Errorf("REDIS_URL is required")
	}

	corsRaw := strings.TrimSpace(os.Getenv("CORS_ALLOWED_ORIGINS"))
	var corsOrigins []string
	for _, p := range strings.Split(corsRaw, ",") {
		p = strings.TrimSpace(p)
		if p != "" {
			corsOrigins = append(corsOrigins, p)
		}
	}

	credsPath := strings.TrimSpace(os.Getenv("GOOGLE_APPLICATION_CREDENTIALS"))
	if credsPath == "" {
		return nil, fmt.Errorf("GOOGLE_APPLICATION_CREDENTIALS is required (path to Firebase service account JSON)")
	}

	dbSchema := strings.TrimSpace(os.Getenv("DATABASE_SCHEMA"))

	return &Config{
		Port:                             port,
		DatabaseURL:                      dbURL,
		DatabaseSchema:                   dbSchema,
		RedisURL:                         redisURL,
		CORSAllowedOrigins:               corsOrigins,
		GoogleApplicationCredentialsPath: credsPath,
	}, nil
}
