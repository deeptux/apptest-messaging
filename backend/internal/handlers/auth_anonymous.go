package handlers

import (
	"context"
	"log"
	"net/http"
	"regexp"
	"strings"

	firebaseauth "firebase.google.com/go/v4/auth"
	"github.com/gin-gonic/gin"

	"github.com/apptest-messaging/backend/internal/repositories"
	"github.com/apptest-messaging/backend/internal/services"
)

var anonymousUsernameDemo = regexp.MustCompile(`^[a-z0-9_]{3,24}$`)

// AnonymousDemoSignIn exposes POST /api/v1/auth/anonymous (no Bearer required).
// Demo-safe: whoever knows the handle can authenticate as that Firebase user row.
func AnonymousDemoSignIn(users *repositories.UserRepository, fbAuth *firebaseauth.Client) gin.HandlerFunc {
	type reqBody struct {
		Username string `json:"username"`
	}
	return func(c *gin.Context) {
		var body reqBody
		if err := c.ShouldBindJSON(&body); err != nil || strings.TrimSpace(body.Username) == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "badRequest", "message": "username required"})
			return
		}
		norm := strings.ToLower(strings.TrimSpace(body.Username))
		if !anonymousUsernameDemo.MatchString(norm) {
			c.JSON(http.StatusBadRequest, gin.H{
				"error":   "badRequest",
				"message": "username must be 3-24 chars: lowercase letters, digits, underscore",
			})
			return
		}

		ctx := c.Request.Context()

		exist, err := users.GetByAnonymousUsername(ctx, norm)
		if err != nil {
			log.Printf("anon auth lookup: %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal", "message": "lookup failed"})
			return
		}

		if exist != nil {
			tok, terr := anonymousMintCustomToken(ctx, fbAuth, exist.FirebaseUID, exist.DisplayName)
			if terr != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "internal", "message": "token mint failed"})
				return
			}
			c.JSON(http.StatusOK, gin.H{
				"customToken":       tok,
				"anonymousUsername": norm,
				"displayName":       derefString(exist.DisplayName),
				"isNew":             false,
				"userId":            exist.ID.String(),
				"firebaseUid":       exist.FirebaseUID,
			})
			return
		}

		record, cerr := fbAuth.CreateUser(ctx, (&firebaseauth.UserToCreate{}))
		if cerr != nil {
			log.Printf("firebase create anon: %v", cerr)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal", "message": "could not create session"})
			return
		}
		uid := record.UID

		display := ""
		foundName := false
		for i := 0; i < 48; i++ {
			display = services.RandomFriendlyPhrase()
			taken, terr := users.ExistsDisplayNameCI(ctx, display)
			if terr != nil {
				log.Printf("anon friendly name probe: %v", terr)
				_ = fbAuth.DeleteUser(ctx, uid)
				c.JSON(http.StatusInternalServerError, gin.H{"error": "internal", "message": "name probe failed"})
				return
			}
			if !taken {
				foundName = true
				break
			}
		}
		if !foundName {
			_ = fbAuth.DeleteUser(ctx, uid)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal", "message": "could not assign unique chat name"})
			return
		}

		if _, ierr := users.InsertAnonymousDemo(ctx, uid, norm, display); ierr != nil {
			_ = fbAuth.DeleteUser(ctx, uid)
			log.Printf("anon insert user: %v", ierr)
			c.JSON(http.StatusConflict, gin.H{
				"error":   "conflict",
				"message": "someone claimed that username — try signing in instead",
			})
			return
		}

		tok, terr := anonymousMintCustomToken(ctx, fbAuth, uid, &display)
		if terr != nil {
			_ = users.DeleteByFirebaseUID(ctx, uid)
			_ = fbAuth.DeleteUser(ctx, uid)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal", "message": "token mint failed"})
			return
		}

		row, lerr := users.GetByFirebaseUID(ctx, uid)
		if lerr != nil || row == nil {
			log.Printf("anon load after insert: %v", lerr)
			_ = fbAuth.DeleteUser(ctx, uid)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "internal", "message": "load failed"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"customToken":       tok,
			"anonymousUsername": norm,
			"displayName":       display,
			"isNew":             true,
			"userId":            row.ID.String(),
			"firebaseUid":       row.FirebaseUID,
		})
	}
}

func anonymousMintCustomToken(ctx context.Context, fbAuth *firebaseauth.Client, firebaseUID string, display *string) (string, error) {
	if display != nil && *display != "" {
		return fbAuth.CustomTokenWithClaims(ctx, firebaseUID, map[string]interface{}{
			"display_name": *display,
		})
	}
	return fbAuth.CustomToken(ctx, firebaseUID)
}

func derefString(p *string) string {
	if p == nil {
		return ""
	}
	return *p
}
