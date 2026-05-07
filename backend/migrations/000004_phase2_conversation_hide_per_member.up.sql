ALTER TABLE conversation_members
ADD COLUMN IF NOT EXISTS hidden_at TIMESTAMPTZ NULL;

CREATE INDEX IF NOT EXISTS idx_conversation_members_hidden_at
  ON conversation_members (user_id, hidden_at);

