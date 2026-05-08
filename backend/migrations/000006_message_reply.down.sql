ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_reply_fk;
ALTER TABLE messages DROP COLUMN IF EXISTS reply_to_seq;
