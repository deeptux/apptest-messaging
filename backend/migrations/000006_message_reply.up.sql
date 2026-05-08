-- Optional reply reference: which message in this thread is being quoted.
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS reply_to_seq BIGINT NULL;

ALTER TABLE messages
  ADD CONSTRAINT messages_reply_fk
    FOREIGN KEY (conversation_id, reply_to_seq)
    REFERENCES messages (conversation_id, seq)
    ON DELETE RESTRICT;
