-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.stories (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL,
  description text NOT NULL DEFAULT ''::text,
  createdat text NOT NULL,
  updatedat text NOT NULL,
  islocked integer NOT NULL DEFAULT 0,
  isdeleted integer NOT NULL DEFAULT 0,
  themelock text,
  coverimage text,
  CONSTRAINT stories_pkey PRIMARY KEY (id),
  CONSTRAINT stories_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.entries (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  storyid uuid NOT NULL,
  title text NOT NULL DEFAULT ''::text,
  content text NOT NULL DEFAULT ''::text,
  createdat text NOT NULL,
  updatedat text NOT NULL,
  timespentseconds integer NOT NULL DEFAULT 0,
  moodcolor text NOT NULL DEFAULT 'default'::text,
  headerimage text,
  headerimageratio text,
  images text NOT NULL DEFAULT '[]'::text,
  isdeleted integer NOT NULL DEFAULT 0,
  blocks_json text,
  textalignment text NOT NULL DEFAULT 'justify'::text,
  CONSTRAINT entries_pkey PRIMARY KEY (id),
  CONSTRAINT entries_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT entries_storyid_fkey FOREIGN KEY (storyid) REFERENCES public.stories(id)
);
CREATE TABLE public.todos (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL,
  iscompleted integer NOT NULL DEFAULT 0,
  createdat text NOT NULL,
  deadline text,
  isarchived integer NOT NULL DEFAULT 0,
  completedat text,
  CONSTRAINT todos_pkey PRIMARY KEY (id),
  CONSTRAINT todos_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.time_capsules (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  message text NOT NULL,
  createdat text NOT NULL,
  openat text NOT NULL,
  isopened integer NOT NULL DEFAULT 0,
  CONSTRAINT time_capsules_pkey PRIMARY KEY (id),
  CONSTRAINT time_capsules_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.published_entries (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
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
  entry_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT community_claps_pkey PRIMARY KEY (id),
  CONSTRAINT community_claps_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.published_entries(id),
  CONSTRAINT community_claps_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.community_comments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  entry_id uuid NOT NULL,
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
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  origin_entry_id uuid NOT NULL,
  inspiration_id uuid,
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
  CONSTRAINT write_backs_origin_entry_id_fkey FOREIGN KEY (origin_entry_id) REFERENCES public.published_entries(id),
  CONSTRAINT write_backs_inspiration_id_fkey FOREIGN KEY (inspiration_id) REFERENCES public.write_backs(id),
  CONSTRAINT write_backs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT write_backs_origin_author_id_fkey FOREIGN KEY (origin_author_id) REFERENCES auth.users(id)
);
CREATE TABLE public.reflection_replies (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  reflection_id uuid NOT NULL,
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
  reflection_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT reflection_claps_pkey PRIMARY KEY (reflection_id, user_id),
  CONSTRAINT reflection_claps_reflection_id_fkey FOREIGN KEY (reflection_id) REFERENCES public.write_backs(id),
  CONSTRAINT reflection_claps_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.community_views (
  entry_id uuid NOT NULL,
  user_id uuid NOT NULL,
  viewed_at timestamp with time zone DEFAULT now(),
  CONSTRAINT community_views_pkey PRIMARY KEY (entry_id, user_id),
  CONSTRAINT community_views_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.featured_entries (
  id integer GENERATED ALWAYS AS IDENTITY NOT NULL,
  entry_id uuid NOT NULL,
  featured_until timestamp with time zone NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT featured_entries_pkey PRIMARY KEY (id),
  CONSTRAINT featured_entries_entry_id_fkey FOREIGN KEY (entry_id) REFERENCES public.published_entries(id)
);