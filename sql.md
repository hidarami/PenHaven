-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.stories (
  id text NOT NULL,
  user_id uuid NOT NULL,
  title text NOT NULL,
  description text NOT NULL DEFAULT ''::text,
  createdAt text NOT NULL,
  updatedAt text NOT NULL,
  isLocked integer NOT NULL DEFAULT 0,
  isDeleted integer NOT NULL DEFAULT 0,
  CONSTRAINT stories_pkey PRIMARY KEY (id),
  CONSTRAINT stories_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.entries (
  id text NOT NULL,
  user_id uuid NOT NULL,
  storyId text NOT NULL,
  title text NOT NULL DEFAULT ''::text,
  content text NOT NULL DEFAULT ''::text,
  createdAt text NOT NULL,
  updatedAt text NOT NULL,
  timeSpentSeconds integer NOT NULL DEFAULT 0,
  moodColor text NOT NULL DEFAULT 'default'::text,
  headerImage text,
  headerImageRatio text,
  images text NOT NULL DEFAULT '[]'::text,
  isDeleted integer NOT NULL DEFAULT 0,
  blocks_json text,
  textAlignment text NOT NULL DEFAULT 'justify'::text,
  CONSTRAINT entries_pkey PRIMARY KEY (id),
  CONSTRAINT entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.todos (
  id text NOT NULL,
  user_id uuid NOT NULL,
  title text NOT NULL,
  isCompleted integer NOT NULL DEFAULT 0,
  createdAt text NOT NULL,
  deadline text,
  isArchived integer NOT NULL DEFAULT 0,
  completedAt text,
  CONSTRAINT todos_pkey PRIMARY KEY (id),
  CONSTRAINT todos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.time_capsules (
  id text NOT NULL,
  user_id uuid NOT NULL,
  message text NOT NULL,
  createdAt text NOT NULL,
  openAt text NOT NULL,
  isOpened integer NOT NULL DEFAULT 0,
  CONSTRAINT time_capsules_pkey PRIMARY KEY (id),
  CONSTRAINT time_capsules_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.published_entries (
  id text NOT NULL,
  user_id uuid NOT NULL,
  title text NOT NULL DEFAULT ''::text,
  content text NOT NULL DEFAULT ''::text,
  blocks_json text,
  is_anonymous boolean NOT NULL DEFAULT false,
  display_name text,
  clap_count integer NOT NULL DEFAULT 0,
  comment_count integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  header_image text,
  category text,
  profile_image_url text,
  CONSTRAINT published_entries_pkey PRIMARY KEY (id),
  CONSTRAINT published_entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.community_claps (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entry_id text NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT community_claps_pkey PRIMARY KEY (id),
  CONSTRAINT community_claps_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.published_entries(id),
  CONSTRAINT community_claps_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.community_comments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entry_id text NOT NULL,
  user_id uuid NOT NULL,
  display_name text,
  body text NOT NULL,
  is_anonymous boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  profile_image_url text,
  CONSTRAINT community_comments_pkey PRIMARY KEY (id),
  CONSTRAINT community_comments_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.published_entries(id),
  CONSTRAINT community_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.write_backs (
  id text NOT NULL,
  origin_entry_id text NOT NULL,
  inspiration_id text,
  user_id uuid NOT NULL,
  origin_author_id uuid,
  title text DEFAULT ''::text,
  content text DEFAULT ''::text,
  blocks_json text,
  is_private boolean NOT NULL DEFAULT true,
  is_anonymous boolean NOT NULL DEFAULT false,
  display_name text,
  header_image text,
  category text,
  clap_count integer DEFAULT 0,
  reply_count integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  origin_title text,
  origin_author text,
  origin_excerpt text,
  origin_header_image text,
  inspiration_author text,
  inspiration_title text,
  profile_image_url text,
  CONSTRAINT write_backs_pkey PRIMARY KEY (id),
  CONSTRAINT write_backs_inspiration_id_fkey FOREIGN KEY (inspiration_id) REFERENCES public.write_backs(id),
  CONSTRAINT write_backs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT write_backs_origin_author_id_fkey FOREIGN KEY (origin_author_id) REFERENCES auth.users(id)
);
CREATE TABLE public.reflection_replies (
  id text NOT NULL DEFAULT (gen_random_uuid())::text,
  reflection_id text NOT NULL,
  user_id uuid NOT NULL,
  body text NOT NULL,
  is_anonymous boolean DEFAULT false,
  display_name text,
  created_at timestamp with time zone DEFAULT now(),
  profile_image_url text,
  CONSTRAINT reflection_replies_pkey PRIMARY KEY (id),
  CONSTRAINT reflection_replies_reflection_id_fkey FOREIGN KEY (reflection_id) REFERENCES public.write_backs(id),
  CONSTRAINT reflection_replies_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.reflection_claps (
  reflection_id text NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT reflection_claps_pkey PRIMARY KEY (reflection_id, user_id),
  CONSTRAINT reflection_claps_reflection_id_fkey FOREIGN KEY (reflection_id) REFERENCES public.write_backs(id),
  CONSTRAINT reflection_claps_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.community_views (
  entry_id text NOT NULL,
  user_id uuid NOT NULL,
  viewed_at timestamp with time zone DEFAULT now(),
  CONSTRAINT community_views_pkey PRIMARY KEY (entry_id, user_id)
);
CREATE TABLE public.featured_entries (
  id integer NOT NULL DEFAULT nextval('featured_entries_id_seq'::regclass),
  entry_id text NOT NULL,
  featured_until timestamp with time zone NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT featured_entries_pkey PRIMARY KEY (id),
  CONSTRAINT featured_entries_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.published_entries(id)
);