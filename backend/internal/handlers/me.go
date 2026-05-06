package handlers

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/apptest-messaging/backend/internal/middleware"
	"github.com/apptest-messaging/backend/internal/services"
)

// Me returns GET /api/v1/me handler.
func Me(me *services.MeService) gin.HandlerFunc {
	return func(c *gin.Context) {
		tok, ok := middleware.FirebaseToken(c)
		if !ok || tok == nil {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error":   "unauthorized",
				"message": "missing token context",
			})
			return
		}

		prof, err := me.SyncFromToken(c.Request.Context(), tok)
		if err != nil {
			log.Printf("me sync: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{
				"error":   "internal",
				"message": "failed to load profile",
			})
			return
		}

		c.JSON(http.StatusOK, prof)
	}
}
