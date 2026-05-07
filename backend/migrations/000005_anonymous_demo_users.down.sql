DROP INDEX IF EXISTS ux_users_anonymous_username_lower;
ALTER TABLE users DROP COLUMN IF EXISTS anonymous_username;
