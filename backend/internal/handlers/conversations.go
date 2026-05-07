package handlers

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"github.com/apptest-messaging/backend/internal/middleware"
	"github.com/apptest-messaging/backend/internal/services"
)

func ConversationsDirect(chat *services.ChatService, me *services.MeService) gin.HandlerFunc {
	type req struct {
		OtherUserID string `json:"otherUserId"`
	}
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

		var body req
		if err := c.ShouldBindJSON(&body); err != nil || strings.TrimSpace(body.OtherUserID) == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "badRequest", "message": "otherUserId required"})
			return
		}
		otherID, err := uuid.Parse(strings.TrimSpace(body.OtherUserID))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "badRequest", "message": "invalid otherUserId"})
			return
		}

		conv, err := chat.OpenOrCreateDirect(c.Request.Context(), selfID, otherID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "badRequest", "message": err.Error()})
			return
		}
		c.JSON(http.StatusOK, gin.H{
			"conversationId": conv.ID.String(),
			"kind":           conv.Kind,
			"lastSeq":        conv.LastSeq,
			"lastMessageAt":  conv.LastMessageAt,
		})
	}
}

func Inbox(chat *services.ChatService, me *services.MeService) gin.HandlerFunc {
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

		limit := 50
		if v := strings.TrimSpace(c.Query("limit")); v != "" {
			if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 100 {
				limit = n
			}
		}

		rows, err := chat.ListInbox(c.Request.Context(), selfID, limit)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal", "message": "failed to load inbox"})
			return
		}

		out := make([]gin.H, 0, len(rows))
		for _, r := range rows {
			unread := r.LastSeq - r.MyLastReadSeq
			if unread < 0 {
				unread = 0
			}
			out = append(out, gin.H{
				"conversationId": r.ConversationID.String(),
				"kind":           r.Kind,
				"lastSeq":        r.LastSeq,
				"lastMessageAt":  r.LastMessageAt,
				"lastReadSeq":    r.MyLastReadSeq,
				"unreadCount":    unread,
				"otherUser": gin.H{
					"userId":      r.OtherUserID.String(),
					"email":       r.OtherEmail,
					"displayName": r.OtherName,
					"photoUrl":    r.OtherPhotoURL,
				},
			})
		}
		c.JSON(http.StatusOK, gin.H{"conversations": out})
	}
}

func ConversationMessages(chat *services.ChatService, me *services.MeService) gin.HandlerFunc {
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

		convID, err := uuid.Parse(c.Param("conversationId"))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "badRequest", "message": "invalid conversationId"})
			return
		}

		limit := 50
		if v := strings.TrimSpace(c.Query("limit")); v != "" {
			if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 200 {
				limit = n
			}
		}
		var beforeSeq *int64
		if v := strings.TrimSpace(c.Query("beforeSeq")); v != "" {
			if n, err := strconv.ParseInt(v, 10, 64); err == nil && n > 0 {
				beforeSeq = &n
			}
		}

		rows, err := chat.ListMessages(c.Request.Context(), convID, selfID, beforeSeq, limit)
		if err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "forbidden", "message": "not a member"})
			return
		}
		out := make([]gin.H, 0, len(rows))
		var nextBefore *int64
		for i, m := range rows {
			if i == len(rows)-1 {
				v := m.Seq
				nextBefore = &v
			}
			out = append(out, gin.H{
				"messageId":      m.ID.String(),
				"conversationId": m.ConversationID.String(),
				"seq":            m.Seq,
				"senderUserId":   m.SenderUserID.String(),
				"body":           m.Body,
				"createdAt":      m.CreatedAt,
				"deliveredAt":    m.DeliveredAt,
			})
		}
		c.JSON(http.StatusOK, gin.H{
			"messages":      out,
			"nextBeforeSeq": nextBefore,
		})
	}
}

func ConversationRead(chat *services.ChatService, me *services.MeService) gin.HandlerFunc {
	type req struct {
		LastReadSeq int64 `json:"lastReadSeq"`
	}
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

		convID, err := uuid.Parse(c.Param("conversationId"))
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "badRequest", "message": "invalid conversationId"})
			return
		}

		var body req
		if err := c.ShouldBindJSON(&body); err != nil || body.LastReadSeq < 0 {
			c.JSON(http.StatusBadRequest, gin.H{"error": "badRequest", "message": "lastReadSeq required"})
			return
		}

		newSeq, err := chat.MarkRead(c.Request.Context(), convID, selfID, body.LastReadSeq)
		if err != nil {
			c.JSON(http.StatusForbidden, gin.H{"error": "forbidden", "message": "not a member"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"conversationId": convID.String(), "lastReadSeq": newSeq})
	}
}
