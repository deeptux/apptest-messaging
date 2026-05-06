package handlers

import (
	"github.com/gin-gonic/gin"
)

// Health responds for load balancers without touching dependencies.
func Health(c *gin.Context) {
	c.JSON(200, gin.H{"status": "ok"})
}
