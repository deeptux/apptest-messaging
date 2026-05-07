package ws

import (
	"sync"
)

// Hub tracks active websocket connections by internal user id.
type Hub struct {
	mu    sync.RWMutex
	conns map[string]map[*Conn]struct{}
}

func NewHub() *Hub {
	return &Hub{
		conns: make(map[string]map[*Conn]struct{}),
	}
}

func (h *Hub) Register(userID string, c *Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.conns[userID] == nil {
		h.conns[userID] = make(map[*Conn]struct{})
	}
	h.conns[userID][c] = struct{}{}
}

func (h *Hub) Unregister(userID string, c *Conn) {
	h.mu.Lock()
	defer h.mu.Unlock()
	m := h.conns[userID]
	if m == nil {
		return
	}
	delete(m, c)
	if len(m) == 0 {
		delete(h.conns, userID)
	}
}

func (h *Hub) SendToUser(userID string, msg []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for c := range h.conns[userID] {
		c.TrySend(msg)
	}
}
