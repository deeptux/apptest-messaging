package handlers

import (
	"context"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	appredis "github.com/apptest-messaging/backend/internal/redis"
)

// ReadyDeps are checked by GET /readyz.
type ReadyDeps struct {
	Pool  *pgxpool.Pool
	Redis *appredis.Client
}

// Ready returns 200 when Postgres and Redis respond; otherwise 503 with details.
func Ready(deps ReadyDeps) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(c.Request.Context(), 2*time.Second)
		defer cancel()

		details := map[string]string{}
		if err := deps.Pool.Ping(ctx); err != nil {
			details["postgres"] = err.Error()
		}
		if err := deps.Redis.Ping(ctx); err != nil {
			details["redis"] = err.Error()
		}

		if len(details) > 0 {
			c.JSON(503, gin.H{
				"status":  "degraded",
				"details": details,
			})
			return
		}

		c.JSON(200, gin.H{"status": "ready"})
	}
}
