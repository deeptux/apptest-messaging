-- Phase 2 chat persistence: conversations, members, messages (seq-ordered).

CREATE TABLE IF NOT EXISTS conversations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kind TEXT NOT NULL,
  direct_user1_id UUID NULL REFERENCES users(id) ON DELETE CASCADE,
  direct_user2_id UUID NULL REFERENCES users(id) ON DELETE CASCADE,
  last_seq BIGINT NOT NULL DEFAULT 0,
  last_message_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT conversations_kind_check CHECK (kind IN ('direct')),
  CONSTRAINT conversations_direct_users_present CHECK (
    (kind <> 'direct')
    OR (direct_user1_id IS NOT NULL AND direct_user2_id IS NOT NULL AND direct_user1_id <> direct_user2_id)
  )
);

-- Prevent duplicate direct threads.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_conversations_direct_pair
  ON conversations (direct_user1_id, direct_user2_id)
  WHERE kind = 'direct';

CREATE INDEX IF NOT EXISTS idx_conversations_last_message_at
  ON conversations (last_message_at DESC NULLS LAST, id);

CREATE TABLE IF NOT EXISTS conversation_members (
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  last_read_seq BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_conversation_members_user
  ON conversation_members (user_id, conversation_id);

CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  seq BIGINT NOT NULL,
  sender_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  delivered_at TIMESTAMPTZ NULL,
  CONSTRAINT messages_seq_positive CHECK (seq > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_messages_conversation_seq
  ON messages (conversation_id, seq);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_messages_idempotency
  ON messages (conversation_id, idempotency_key);

CREATE INDEX IF NOT EXISTS idx_messages_conversation_seq_desc
  ON messages (conversation_id, seq DESC);

