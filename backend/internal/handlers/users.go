package handlers

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/apptest-messaging/backend/internal/middleware"
	"github.com/apptest-messaging/backend/internal/services"
)

func UsersSearch(chat *services.ChatService, me *services.MeService) gin.HandlerFunc {
	return func(c *gin.Context) {
		tok, ok := middleware.FirebaseToken(c)
		if !ok || tok == nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized", "message": "missing token context"})
			return
		}
		prof, err := me.SyncFromToken(c.Request.Context(), tok)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal", "message": "failed to load profile"})
			return
		}
		selfID, err := uuid.Parse(prof.UserID)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal", "message": "invalid user id"})
			return
		}

		q := strings.TrimSpace(c.Query("q"))
		if q == "" {
			q = strings.TrimSpace(c.Query("email"))
		}
		if len(q) < 2 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "badRequest", "message": "q or email query (min 2 chars) required"})
			return
		}

		rows, err := chat.SearchContacts(c.Request.Context(), selfID, q, 10)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal", "message": "search failed"})
			return
		}

		out := make([]gin.H, 0, len(rows))
		for _, r := range rows {
			if r.ID == selfID {
				continue
			}
			h := gin.H{
				"userId":      r.ID.String(),
				"email":       r.Email,
				"displayName": r.DisplayName,
				"photoUrl":    r.PhotoURL,
			}
			if r.AnonymousUsername != nil && *r.AnonymousUsername != "" {
				h["anonymousUsername"] = *r.AnonymousUsername
			}
			out = append(out, h)
		}
		c.JSON(http.StatusOK, gin.H{"users": out})
	}
}
