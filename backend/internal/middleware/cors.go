package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
)

func originAllowed(allowedOrigins []string, origin string) bool {
	for _, a := range allowedOrigins {
		a = strings.TrimSpace(a)
		if a == "" {
			continue
		}
		// Dev escape hatch: "*" means allow any origin.
		if a == "*" {
			return true
		}
		// Simple wildcard support: "http://localhost:*" matches any port.
		if strings.HasSuffix(a, "*") {
			prefix := strings.TrimSuffix(a, "*")
			if strings.HasPrefix(origin, prefix) {
				return true
			}
			continue
		}
		if origin == a {
			return true
		}
	}
	return false
}

// CORSAllowlist rejects browser requests whose Origin is not in the allowlist.
// Requests without an Origin header (e.g. curl, many mobile stacks) are allowed through.
func CORSAllowlist(allowedOrigins []string) gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := strings.TrimSpace(c.GetHeader("Origin"))
		if origin != "" {
			if !originAllowed(allowedOrigins, origin) {
				c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
					"error":   "forbidden",
					"message": "origin not allowed",
				})
				return
			}
			c.Header("Access-Control-Allow-Origin", origin)
			c.Header("Access-Control-Allow-Credentials", "true")
		}

		c.Header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Authorization, Content-Type")

		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}
