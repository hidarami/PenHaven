| table_name         | column_name         | data_type                |
| ------------------ | ------------------- | ------------------------ |
| community_claps    | id                  | uuid                     |
| community_claps    | entry_id            | text                     |
| community_claps    | user_id             | uuid                     |
| community_claps    | created_at          | timestamp with time zone |
| community_comments | id                  | uuid                     |
| community_comments | entry_id            | text                     |
| community_comments | user_id             | uuid                     |
| community_comments | display_name        | text                     |
| community_comments | body                | text                     |
| community_comments | is_anonymous        | boolean                  |
| community_comments | created_at          | timestamp with time zone |
| entries            | id                  | text                     |
| entries            | user_id             | uuid                     |
| entries            | storyId             | text                     |
| entries            | title               | text                     |
| entries            | content             | text                     |
| entries            | createdAt           | text                     |
| entries            | updatedAt           | text                     |
| entries            | timeSpentSeconds    | integer                  |
| entries            | moodColor           | text                     |
| entries            | headerImage         | text                     |
| entries            | headerImageRatio    | text                     |
| entries            | images              | text                     |
| entries            | isDeleted           | integer                  |
| entries            | blocks_json         | text                     |
| entries            | textAlignment       | text                     |
| published_entries  | id                  | text                     |
| published_entries  | user_id             | uuid                     |
| published_entries  | title               | text                     |
| published_entries  | content             | text                     |
| published_entries  | blocks_json         | text                     |
| published_entries  | is_anonymous        | boolean                  |
| published_entries  | display_name        | text                     |
| published_entries  | clap_count          | integer                  |
| published_entries  | comment_count       | integer                  |
| published_entries  | created_at          | timestamp with time zone |
| published_entries  | updated_at          | timestamp with time zone |
| published_entries  | header_image        | text                     |
| published_entries  | category            | text                     |
| reflection_claps   | reflection_id       | text                     |
| reflection_claps   | user_id             | uuid                     |
| reflection_replies | id                  | text                     |
| reflection_replies | reflection_id       | text                     |
| reflection_replies | user_id             | uuid                     |
| reflection_replies | body                | text                     |
| reflection_replies | is_anonymous        | boolean                  |
| reflection_replies | display_name        | text                     |
| reflection_replies | created_at          | timestamp with time zone |
| stories            | id                  | text                     |
| stories            | user_id             | uuid                     |
| stories            | title               | text                     |
| stories            | description         | text                     |
| stories            | createdAt           | text                     |
| stories            | updatedAt           | text                     |
| stories            | isLocked            | integer                  |
| stories            | isDeleted           | integer                  |
| time_capsules      | id                  | text                     |
| time_capsules      | user_id             | uuid                     |
| time_capsules      | message             | text                     |
| time_capsules      | createdAt           | text                     |
| time_capsules      | openAt              | text                     |
| time_capsules      | isOpened            | integer                  |
| todos              | id                  | text                     |
| todos              | user_id             | uuid                     |
| todos              | title               | text                     |
| todos              | isCompleted         | integer                  |
| todos              | createdAt           | text                     |
| todos              | deadline            | text                     |
| todos              | isArchived          | integer                  |
| todos              | completedAt         | text                     |
| write_backs        | id                  | text                     |
| write_backs        | origin_entry_id     | text                     |
| write_backs        | inspiration_id      | text                     |
| write_backs        | user_id             | uuid                     |
| write_backs        | origin_author_id    | uuid                     |
| write_backs        | title               | text                     |
| write_backs        | content             | text                     |
| write_backs        | blocks_json         | text                     |
| write_backs        | is_private          | boolean                  |
| write_backs        | is_anonymous        | boolean                  |
| write_backs        | display_name        | text                     |
| write_backs        | header_image        | text                     |
| write_backs        | category            | text                     |
| write_backs        | clap_count          | integer                  |
| write_backs        | reply_count         | integer                  |
| write_backs        | created_at          | timestamp with time zone |
| write_backs        | origin_title        | text                     |
| write_backs        | origin_author       | text                     |
| write_backs        | origin_excerpt      | text                     |
| write_backs        | origin_header_image | text                     |
| write_backs        | inspiration_author  | text                     |
| write_backs        | inspiration_title   | text                     |

CREATE OR REPLACE FUNCTION increment_reflection_clap(p_id text)
RETURNS void AS $$
  UPDATE write_backs SET clap_count = clap_count + 1 WHERE id = p_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION decrement_reflection_clap(p_id text)
RETURNS void AS $$
  UPDATE write_backs SET clap_count = GREATEST(0, clap_count - 1) WHERE id = p_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION increment_clap_count(p_entry_id text)
RETURNS void AS $$
  UPDATE published_entries SET clap_count = clap_count + 1 WHERE id = p_entry_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION decrement_clap_count(p_entry_id text)
RETURNS void AS $$
  UPDATE published_entries SET clap_count = GREATEST(0, clap_count - 1) WHERE id = p_entry_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION increment_comment_count(p_entry_id text)
RETURNS void AS $$
  UPDATE published_entries SET comment_count = comment_count + 1 WHERE id = p_entry_id;
$$ LANGUAGE sql;

-- MISSING: community_views table (referenced in code but absent from schema)
CREATE TABLE IF NOT EXISTS community_views (
  entry_id  TEXT        NOT NULL,
  user_id   UUID        NOT NULL,
  viewed_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (entry_id, user_id)
);

-- MISSING: reflection reply count increment function
CREATE OR REPLACE FUNCTION increment_reply_count(p_id text)
RETURNS void AS $$
  UPDATE write_backs SET reply_count = reply_count + 1 WHERE id = p_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION decrement_reply_count(p_id text)
RETURNS void AS $$
  UPDATE write_backs SET reply_count = GREATEST(0, reply_count - 1) WHERE id = p_id;
$$ LANGUAGE sql;

-- MISSING: add created_at to reflection_claps if not present
ALTER TABLE reflection_claps
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- NOTE: The following columns are TEXT but should ideally be UUID.
-- They work as-is since Uuid().v4() produces valid UUID strings stored as text.
-- To migrate cleanly in future, change these to UUID type:
--   write_backs.id, write_backs.origin_entry_id, write_backs.inspiration_id
--   published_entries.id, entries.id, stories.id
--   reflection_replies.id
-- Do NOT change these now without a full data migration — existing rows have text UUIDs.