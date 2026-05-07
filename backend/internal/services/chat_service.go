package services

import (
	"context"
	"fmt"
	"sort"

	"github.com/google/uuid"

	"github.com/apptest-messaging/backend/internal/repositories"
)

type ChatService struct {
	users *repositories.UserRepository
	convs *repositories.ConversationRepository
	msgs  *repositories.MessageRepository
}

func NewChatService(users *repositories.UserRepository, convs *repositories.ConversationRepository, msgs *repositories.MessageRepository) *ChatService {
	return &ChatService{users: users, convs: convs, msgs: msgs}
}

func (s *ChatService) SearchUsersByEmailPrefix(ctx context.Context, prefix string, limit int) ([]repositories.UserSearchResult, error) {
	return s.users.SearchByEmailPrefix(ctx, prefix, limit)
}

// SearchContacts matches email prefixes, anonymous usernames, or display_name substrings (demo).
func (s *ChatService) SearchContacts(ctx context.Context, selfID uuid.UUID, q string, limit int) ([]repositories.UserSearchResult, error) {
	return s.users.SearchContactPrefix(ctx, selfID, q, limit)
}

func (s *ChatService) OpenOrCreateDirect(ctx context.Context, selfID, otherID uuid.UUID) (*repositories.Conversation, error) {
	if selfID == otherID {
		return nil, fmt.Errorf("cannot create direct conversation with self")
	}
	a := []uuid.UUID{selfID, otherID}
	sort.Slice(a, func(i, j int) bool { return a[i].String() < a[j].String() })
	conv, err := s.convs.UpsertDirectConversation(ctx, a[0], a[1])
	if err != nil {
		return nil, err
	}
	if err := s.convs.EnsureMember(ctx, conv.ID, selfID); err != nil {
		return nil, err
	}
	if err := s.convs.EnsureMember(ctx, conv.ID, otherID); err != nil {
		return nil, err
	}
	return conv, nil
}

func (s *ChatService) ListInbox(ctx context.Context, selfID uuid.UUID, limit int) ([]repositories.InboxRow, error) {
	return s.convs.ListInbox(ctx, selfID, limit)
}

func (s *ChatService) ListMessages(ctx context.Context, conversationID, selfID uuid.UUID, beforeSeq *int64, limit int) ([]repositories.MessageRow, error) {
	ok, err := s.convs.IsMember(ctx, conversationID, selfID)
	if err != nil {
		return nil, err
	}
	if !ok {
		return nil, fmt.Errorf("not a member")
	}
	return s.msgs.ListByConversationBeforeSeq(ctx, conversationID, beforeSeq, limit)
}

func (s *ChatService) MarkRead(ctx context.Context, conversationID, selfID uuid.UUID, lastReadSeq int64) (int64, error) {
	ok, err := s.convs.IsMember(ctx, conversationID, selfID)
	if err != nil {
		return 0, err
	}
	if !ok {
		return 0, fmt.Errorf("not a member")
	}
	return s.convs.MarkRead(ctx, conversationID, selfID, lastReadSeq)
}

func (s *ChatService) HideConversation(ctx context.Context, conversationID, selfID uuid.UUID) error {
	ok, err := s.convs.IsMember(ctx, conversationID, selfID)
	if err != nil {
		return err
	}
	if !ok {
		return fmt.Errorf("not a member")
	}
	return s.convs.Hide(ctx, conversationID, selfID)
}
