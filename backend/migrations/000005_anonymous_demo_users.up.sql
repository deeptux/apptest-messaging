-- Demo anonymous accounts: unique handle + friendly display labels for chat.

ALTER TABLE users
  ADD COLUMN IF NOT EXISTS anonymous_username TEXT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_users_anonymous_username_lower
  ON users (lower(trim(anonymous_username)))
  WHERE anonymous_username IS NOT NULL AND trim(anonymous_username) <> '';
