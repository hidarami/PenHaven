## Table `stories`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `text` | Primary |
| `user_id` | `uuid` |  |
| `title` | `text` |  |
| `description` | `text` |  |
| `createdAt` | `text` |  |
| `updatedAt` | `text` |  |
| `isLocked` | `int4` |  |
| `isDeleted` | `int4` |  |

## Table `entries`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `text` | Primary |
| `user_id` | `uuid` |  |
| `storyId` | `text` |  |
| `title` | `text` |  |
| `content` | `text` |  |
| `createdAt` | `text` |  |
| `updatedAt` | `text` |  |
| `timeSpentSeconds` | `int4` |  |
| `moodColor` | `text` |  |
| `headerImage` | `text` |  Nullable |
| `headerImageRatio` | `text` |  Nullable |
| `images` | `text` |  |
| `isDeleted` | `int4` |  |
| `blocks_json` | `text` |  Nullable |
| `textAlignment` | `text` |  |

## Table `todos`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `text` | Primary |
| `user_id` | `uuid` |  |
| `title` | `text` |  |
| `isCompleted` | `int4` |  |
| `createdAt` | `text` |  |
| `deadline` | `text` |  Nullable |
| `isArchived` | `int4` |  |
| `completedAt` | `text` |  Nullable |

## Table `time_capsules`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `text` | Primary |
| `user_id` | `uuid` |  |
| `message` | `text` |  |
| `createdAt` | `text` |  |
| `openAt` | `text` |  |
| `isOpened` | `int4` |  |

## Table `published_entries`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `text` | Primary |
| `user_id` | `uuid` |  |
| `title` | `text` |  |
| `content` | `text` |  |
| `blocks_json` | `text` |  Nullable |
| `is_anonymous` | `bool` |  |
| `display_name` | `text` |  Nullable |
| `clap_count` | `int4` |  |
| `comment_count` | `int4` |  |
| `created_at` | `timestamptz` |  |
| `updated_at` | `timestamptz` |  |
| `header_image` | `text` |  Nullable |
| `category` | `text` |  Nullable |
| `profile_image_url` | `text` |  Nullable |

## Table `community_claps`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `entry_id` | `text` |  |
| `user_id` | `uuid` |  |
| `created_at` | `timestamptz` |  |

## Table `community_comments`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `uuid` | Primary |
| `entry_id` | `text` |  |
| `user_id` | `uuid` |  |
| `display_name` | `text` |  Nullable |
| `body` | `text` |  |
| `is_anonymous` | `bool` |  |
| `created_at` | `timestamptz` |  |
| `profile_image_url` | `text` |  Nullable |

## Table `write_backs`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `text` | Primary |
| `origin_entry_id` | `text` |  |
| `inspiration_id` | `text` |  Nullable |
| `user_id` | `uuid` |  |
| `origin_author_id` | `uuid` |  Nullable |
| `title` | `text` |  Nullable |
| `content` | `text` |  Nullable |
| `blocks_json` | `text` |  Nullable |
| `is_private` | `bool` |  |
| `is_anonymous` | `bool` |  |
| `display_name` | `text` |  Nullable |
| `header_image` | `text` |  Nullable |
| `category` | `text` |  Nullable |
| `clap_count` | `int4` |  Nullable |
| `reply_count` | `int4` |  Nullable |
| `created_at` | `timestamptz` |  Nullable |
| `origin_title` | `text` |  Nullable |
| `origin_author` | `text` |  Nullable |
| `origin_excerpt` | `text` |  Nullable |
| `origin_header_image` | `text` |  Nullable |
| `inspiration_author` | `text` |  Nullable |
| `inspiration_title` | `text` |  Nullable |
| `profile_image_url` | `text` |  Nullable |

## Table `reflection_replies`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `text` | Primary |
| `reflection_id` | `text` |  |
| `user_id` | `uuid` |  |
| `body` | `text` |  |
| `is_anonymous` | `bool` |  Nullable |
| `display_name` | `text` |  Nullable |
| `created_at` | `timestamptz` |  Nullable |
| `profile_image_url` | `text` |  Nullable |

## Table `reflection_claps`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `reflection_id` | `text` | Primary |
| `user_id` | `uuid` | Primary |
| `created_at` | `timestamptz` |  Nullable |

## Table `community_views`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `entry_id` | `text` | Primary |
| `user_id` | `uuid` | Primary |
| `viewed_at` | `timestamptz` |  Nullable |

## Table `featured_entries`

### Columns

| Name | Type | Constraints |
|------|------|-------------|
| `id` | `int4` | Primary |
| `entry_id` | `text` |  |
| `featured_until` | `timestamptz` |  |
| `created_at` | `timestamptz` |  |

## RLS Policies

### `entries`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `Users own their entries` | ALL | public | PERMISSIVE | `(auth.uid() = user_id)` | — |

### `stories`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `Users own their stories` | ALL | public | PERMISSIVE | `(auth.uid() = user_id)` | — |

### `todos`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `Users own their todos` | ALL | public | PERMISSIVE | `(auth.uid() = user_id)` | — |

### `time_capsules`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `Users own their capsules` | ALL | public | PERMISSIVE | `(auth.uid() = user_id)` | — |

### `community_claps`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `Users unclap` | DELETE | public | PERMISSIVE | `(auth.uid() = user_id)` | — |
| `Auth users clap` | INSERT | public | PERMISSIVE | — | `(auth.uid() = user_id)` |
| `Anyone reads claps` | SELECT | public | PERMISSIVE | `true` | — |

### `write_backs`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `Private write backs visible to writer origin and inspiration au` | SELECT | public | PERMISSIVE | `((is_private = true) AND ((auth.uid() = user_id) OR (auth.uid() = origin_author_id) OR (auth.uid() = ( SELECT wb2.user_id    FROM write_backs wb2   WHERE (wb2.id = write_backs.inspiration_id)))))` | — |
| `Users can delete their own` | DELETE | public | PERMISSIVE | `(auth.uid() = user_id)` | — |
| `Users can update their own` | UPDATE | public | PERMISSIVE | `(auth.uid() = user_id)` | — |
| `Users can insert their own` | INSERT | public | PERMISSIVE | — | `(auth.uid() = user_id)` |
| `Public reflections visible to all` | SELECT | public | PERMISSIVE | `(is_private = false)` | — |

### `reflection_claps`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `Users can delete their own claps` | DELETE | public | PERMISSIVE | `(auth.uid() = user_id)` | — |
| `Users can insert their own claps` | INSERT | public | PERMISSIVE | — | `(auth.uid() = user_id)` |
| `Reflection claps visible to all` | SELECT | public | PERMISSIVE | `true` | — |

### `community_comments`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `Entry authors can delete comments on their entries` | DELETE | public | PERMISSIVE | `((auth.uid() = user_id) OR (auth.uid() IN ( SELECT published_entries.user_id    FROM published_entries   WHERE (published_entries.id = community_comments.entry_id))))` | — |
| `Users delete own` | DELETE | public | PERMISSIVE | `(auth.uid() = user_id)` | — |
| `Auth users comment` | INSERT | public | PERMISSIVE | — | `(auth.uid() = user_id)` |
| `Anyone reads comments` | SELECT | public | PERMISSIVE | `true` | — |

### `published_entries`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `Authors delete` | DELETE | public | PERMISSIVE | `(auth.uid() = user_id)` | — |
| `Authors update` | UPDATE | public | PERMISSIVE | `(auth.uid() = user_id)` | — |
| `Auth users publish` | INSERT | public | PERMISSIVE | — | `(auth.uid() = user_id)` |
| `Anyone reads entries` | SELECT | public | PERMISSIVE | `true` | — |

### `reflection_replies`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `Users can delete their own replies` | DELETE | public | PERMISSIVE | `(auth.uid() = user_id)` | — |
| `Users can insert replies` | INSERT | public | PERMISSIVE | — | `(auth.uid() = user_id)` |
| `Replies visible to all` | SELECT | public | PERMISSIVE | `true` | — |

### `featured_entries`

| Policy | Command | Roles | Action | USING | WITH CHECK |
|--------|---------|-------|--------|-------|------------|
| `Authenticated users can delete featured` | DELETE | public | PERMISSIVE | `(auth.role() = 'authenticated'::text)` | — |
| `Authenticated users can set featured` | INSERT | public | PERMISSIVE | — | `(auth.role() = 'authenticated'::text)` |
| `Anyone reads featured` | SELECT | public | PERMISSIVE | `true` | — |

