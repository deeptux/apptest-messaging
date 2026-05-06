package middleware

import (
	"net/http"
	"strings"

	firebaseauth "firebase.google.com/go/v4/auth"
	"github.com/gin-gonic/gin"
)

const (
	ctxKeyFirebaseToken = "firebaseToken"
)

// FirebaseAuth verifies Authorization: Bearer <Firebase ID token>.
// On success, stores the decoded token in Gin context.
func FirebaseAuth(client *firebaseauth.Client) gin.HandlerFunc {
	return func(c *gin.Context) {
		h := strings.TrimSpace(c.GetHeader("Authorization"))
		const prefix = "Bearer "
		if !strings.HasPrefix(h, prefix) {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error":   "unauthorized",
				"message": "missing bearer token",
			})
			c.Abort()
			return
		}
		raw := strings.TrimSpace(strings.TrimPrefix(h, prefix))
		if raw == "" {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error":   "unauthorized",
				"message": "empty bearer token",
			})
			c.Abort()
			return
		}

		tok, err := client.VerifyIDToken(c.Request.Context(), raw)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error":   "unauthorized",
				"message": "invalid token",
			})
			c.Abort()
			return
		}

		c.Set(ctxKeyFirebaseToken, tok)
		c.Next()
	}
}

// FirebaseToken reads the verified Firebase token from Gin context.
func FirebaseToken(c *gin.Context) (*firebaseauth.Token, bool) {
	v, ok := c.Get(ctxKeyFirebaseToken)
	if !ok || v == nil {
		return nil, false
	}
	tok, ok := v.(*firebaseauth.Token)
	return tok, ok
}

