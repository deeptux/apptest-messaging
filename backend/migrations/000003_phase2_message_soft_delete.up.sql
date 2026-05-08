ALTER TABLE messages
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ NULL;

CREATE INDEX IF NOT EXISTS idx_messages_conversation_deleted_at
  ON messages (conversation_id, deleted_at);

