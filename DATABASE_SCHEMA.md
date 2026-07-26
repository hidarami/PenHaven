| table_name         | column_name         | data_type                | is_nullable | column_default            |
| ------------------ | ------------------- | ------------------------ | ----------- | ------------------------- |
| community_claps    | id                  | uuid                     | NO          | gen_random_uuid()         |
| community_claps    | entry_id            | text                     | NO          | null                      |
| community_claps    | user_id             | uuid                     | NO          | null                      |
| community_claps    | created_at          | timestamp with time zone | NO          | now()                     |
| community_comments | id                  | uuid                     | NO          | gen_random_uuid()         |
| community_comments | entry_id            | text                     | NO          | null                      |
| community_comments | user_id             | uuid                     | NO          | null                      |
| community_comments | display_name        | text                     | YES         | null                      |
| community_comments | body                | text                     | NO          | null                      |
| community_comments | is_anonymous        | boolean                  | NO          | false                     |
| community_comments | created_at          | timestamp with time zone | NO          | now()                     |
| community_comments | profile_image_url   | text                     | YES         | null                      |
| community_views    | entry_id            | text                     | NO          | null                      |
| community_views    | user_id             | uuid                     | NO          | null                      |
| community_views    | viewed_at           | timestamp with time zone | YES         | now()                     |
| entries            | id                  | text                     | NO          | null                      |
| entries            | user_id             | uuid                     | NO          | null                      |
| entries            | storyId             | text                     | NO          | null                      |
| entries            | title               | text                     | NO          | ''::text                  |
| entries            | content             | text                     | NO          | ''::text                  |
| entries            | createdAt           | text                     | NO          | null                      |
| entries            | updatedAt           | text                     | NO          | null                      |
| entries            | timeSpentSeconds    | integer                  | NO          | 0                         |
| entries            | moodColor           | text                     | NO          | 'default'::text           |
| entries            | headerImage         | text                     | YES         | null                      |
| entries            | headerImageRatio    | text                     | YES         | null                      |
| entries            | images              | text                     | NO          | '[]'::text                |
| entries            | isDeleted           | integer                  | NO          | 0                         |
| entries            | blocks_json         | text                     | YES         | null                      |
| entries            | textAlignment       | text                     | NO          | 'justify'::text           |
| published_entries  | id                  | text                     | NO          | null                      |
| published_entries  | user_id             | uuid                     | NO          | null                      |
| published_entries  | title               | text                     | NO          | ''::text                  |
| published_entries  | content             | text                     | NO          | ''::text                  |
| published_entries  | blocks_json         | text                     | YES         | null                      |
| published_entries  | is_anonymous        | boolean                  | NO          | false                     |
| published_entries  | display_name        | text                     | YES         | null                      |
| published_entries  | clap_count          | integer                  | NO          | 0                         |
| published_entries  | comment_count       | integer                  | NO          | 0                         |
| published_entries  | created_at          | timestamp with time zone | NO          | now()                     |
| published_entries  | updated_at          | timestamp with time zone | NO          | now()                     |
| published_entries  | header_image        | text                     | YES         | null                      |
| published_entries  | category            | text                     | YES         | null                      |
| published_entries  | profile_image_url   | text                     | YES         | null                      |
| reflection_claps   | reflection_id       | text                     | NO          | null                      |
| reflection_claps   | user_id             | uuid                     | NO          | null                      |
| reflection_claps   | created_at          | timestamp with time zone | YES         | now()                     |
| reflection_replies | id                  | text                     | NO          | (gen_random_uuid())::text |
| reflection_replies | reflection_id       | text                     | NO          | null                      |
| reflection_replies | user_id             | uuid                     | NO          | null                      |
| reflection_replies | body                | text                     | NO          | null                      |
| reflection_replies | is_anonymous        | boolean                  | YES         | false                     |
| reflection_replies | display_name        | text                     | YES         | null                      |
| reflection_replies | created_at          | timestamp with time zone | YES         | now()                     |
| reflection_replies | profile_image_url   | text                     | YES         | null                      |
| stories            | id                  | text                     | NO          | null                      |
| stories            | user_id             | uuid                     | NO          | null                      |
| stories            | title               | text                     | NO          | null                      |
| stories            | description         | text                     | NO          | ''::text                  |
| stories            | createdAt           | text                     | NO          | null                      |
| stories            | updatedAt           | text                     | NO          | null                      |
| stories            | isLocked            | integer                  | NO          | 0                         |
| stories            | isDeleted           | integer                  | NO          | 0                         |
| time_capsules      | id                  | text                     | NO          | null                      |
| time_capsules      | user_id             | uuid                     | NO          | null                      |
| time_capsules      | message             | text                     | NO          | null                      |
| time_capsules      | createdAt           | text                     | NO          | null                      |
| time_capsules      | openAt              | text                     | NO          | null                      |
| time_capsules      | isOpened            | integer                  | NO          | 0                         |
| todos              | id                  | text                     | NO          | null                      |
| todos              | user_id             | uuid                     | NO          | null                      |
| todos              | title               | text                     | NO          | null                      |
| todos              | isCompleted         | integer                  | NO          | 0                         |
| todos              | createdAt           | text                     | NO          | null                      |
| todos              | deadline            | text                     | YES         | null                      |
| todos              | isArchived          | integer                  | NO          | 0                         |
| todos              | completedAt         | text                     | YES         | null                      |
| write_backs        | id                  | text                     | NO          | null                      |
| write_backs        | origin_entry_id     | text                     | NO          | null                      |
| write_backs        | inspiration_id      | text                     | YES         | null                      |
| write_backs        | user_id             | uuid                     | NO          | null                      |
| write_backs        | origin_author_id    | uuid                     | YES         | null                      |
| write_backs        | title               | text                     | YES         | ''::text                  |
| write_backs        | content             | text                     | YES         | ''::text                  |
| write_backs        | blocks_json         | text                     | YES         | null                      |
| write_backs        | is_private          | boolean                  | NO          | true                      |
| write_backs        | is_anonymous        | boolean                  | NO          | false                     |
| write_backs        | display_name        | text                     | YES         | null                      |
| write_backs        | header_image        | text                     | YES         | null                      |
| write_backs        | category            | text                     | YES         | null                      |
| write_backs        | clap_count          | integer                  | YES         | 0                         |
| write_backs        | reply_count         | integer                  | YES         | 0                         |
| write_backs        | created_at          | timestamp with time zone | YES         | now()                     |
| write_backs        | origin_title        | text                     | YES         | null                      |
| write_backs        | origin_author       | text                     | YES         | null                      |
| write_backs        | origin_excerpt      | text                     | YES         | null                      |
| write_backs        | origin_header_image | text                     | YES         | null                      |
| write_backs        | inspiration_author  | text                     | YES         | null                      |
| write_backs        | inspiration_title   | text                     | YES         | null                      |
| write_backs        | profile_image_url   | text                     | YES         | null                      |

| table_name         | column_name    | referenced_table  | referenced_column |
| ------------------ | -------------- | ----------------- | ----------------- |
| community_claps    | entry_id       | published_entries | id                |
| community_comments | entry_id       | published_entries | id                |
| reflection_claps   | reflection_id  | write_backs       | id                |
| reflection_replies | reflection_id  | write_backs       | id                |
| write_backs        | inspiration_id | write_backs       | id                |

| schemaname | tablename          | policyname                                                | cmd    | permissive | roles    | qual                                                                                                                                                                   | with_check             |
| ---------- | ------------------ | --------------------------------------------------------- | ------ | ---------- | -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| public     | community_claps    | Anyone reads claps                                        | SELECT | PERMISSIVE | {public} | true                                                                                                                                                                   | null                   |
| public     | community_claps    | Auth users clap                                           | INSERT | PERMISSIVE | {public} | null                                                                                                                                                                   | (auth.uid() = user_id) |
| public     | community_claps    | Users unclap                                              | DELETE | PERMISSIVE | {public} | (auth.uid() = user_id)                                                                                                                                                 | null                   |
| public     | community_comments | Anyone reads comments                                     | SELECT | PERMISSIVE | {public} | true                                                                                                                                                                   | null                   |
| public     | community_comments | Auth users comment                                        | INSERT | PERMISSIVE | {public} | null                                                                                                                                                                   | (auth.uid() = user_id) |
| public     | community_comments | Entry authors can delete comments on their entries        | DELETE | PERMISSIVE | {public} | ((auth.uid() = user_id) OR (auth.uid() IN ( SELECT published_entries.user_id
   FROM published_entries
  WHERE (published_entries.id = community_comments.entry_id)))) | null                   |
| public     | community_comments | Users delete own                                          | DELETE | PERMISSIVE | {public} | (auth.uid() = user_id)                                                                                                                                                 | null                   |
| public     | entries            | Users own their entries                                   | ALL    | PERMISSIVE | {public} | (auth.uid() = user_id)                                                                                                                                                 | null                   |
| public     | published_entries  | Anyone reads entries                                      | SELECT | PERMISSIVE | {public} | true                                                                                                                                                                   | null                   |
| public     | published_entries  | Auth users publish                                        | INSERT | PERMISSIVE | {public} | null                                                                                                                                                                   | (auth.uid() = user_id) |
| public     | published_entries  | Authors delete                                            | DELETE | PERMISSIVE | {public} | (auth.uid() = user_id)                                                                                                                                                 | null                   |
| public     | published_entries  | Authors update                                            | UPDATE | PERMISSIVE | {public} | (auth.uid() = user_id)                                                                                                                                                 | null                   |
| public     | reflection_claps   | Reflection claps visible to all                           | SELECT | PERMISSIVE | {public} | true                                                                                                                                                                   | null                   |
| public     | reflection_claps   | Users can delete their own claps                          | DELETE | PERMISSIVE | {public} | (auth.uid() = user_id)                                                                                                                                                 | null                   |
| public     | reflection_claps   | Users can insert their own claps                          | INSERT | PERMISSIVE | {public} | null                                                                                                                                                                   | (auth.uid() = user_id) |
| public     | reflection_replies | Replies visible to all                                    | SELECT | PERMISSIVE | {public} | true                                                                                                                                                                   | null                   |
| public     | reflection_replies | Users can delete their own replies                        | DELETE | PERMISSIVE | {public} | (auth.uid() = user_id)                                                                                                                                                 | null                   |
| public     | reflection_replies | Users can insert replies                                  | INSERT | PERMISSIVE | {public} | null                                                                                                                                                                   | (auth.uid() = user_id) |
| public     | stories            | Users own their stories                                   | ALL    | PERMISSIVE | {public} | (auth.uid() = user_id)                                                                                                                                                 | null                   |
| public     | time_capsules      | Users own their capsules                                  | ALL    | PERMISSIVE | {public} | (auth.uid() = user_id)                                                                                                                                                 | null                   |
| public     | todos              | Users own their todos                                     | ALL    | PERMISSIVE | {public} | (auth.uid() = user_id)                                                                                                                                                 | null                   |
| public     | write_backs        | Private write backs visible to writer and original author | SELECT | PERMISSIVE | {public} | ((is_private = true) AND ((auth.uid() = user_id) OR (auth.uid() = origin_author_id)))                                                                                  | null                   |
| public     | write_backs        | Public reflections visible to all                         | SELECT | PERMISSIVE | {public} | (is_private = false)                                                                                                                                                   | null                   |
| public     | write_backs        | Users can delete their own                                | DELETE | PERMISSIVE | {public} | (auth.uid() = user_id)                                                                                                                                                 | null                   |
| public     | write_backs        | Users can insert their own                                | INSERT | PERMISSIVE | {public} | null                                                                                                                                                                   | (auth.uid() = user_id) |
| public     | write_backs        | Users can update their own                                | UPDATE | PERMISSIVE | {public} | (auth.uid() = user_id)                                                                                                                                                 | null                   |