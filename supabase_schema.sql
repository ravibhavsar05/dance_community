-- ============================================================================
-- Supabase Database Schema for Dance Pulse / Dance Community
-- ============================================================================
-- This script sets up all tables, relationships, triggers, RLS policies,
-- storage buckets, and realtime configurations based on the CRUD operations 
-- defined in the project's codebase.
--
-- How to import into Supabase:
-- 1. Go to the Supabase Dashboard (https://supabase.com).
-- 2. Open your project.
-- 3. Go to the "SQL Editor" section on the left sidebar.
-- 4. Click "New Query" and paste the contents of this file.
-- 5. Click "Run" to execute the script.
-- ============================================================================

-- Enable pgcrypto extension for UUID generation if needed
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. DROP EXISTING TABLES (Clean Slate Setup - Optional/Safe)
-- ============================================================================
DROP TABLE IF EXISTS public.battle_comments CASCADE;
DROP TABLE IF EXISTS public.battle_likes CASCADE;
DROP TABLE IF EXISTS public.battle_votes CASCADE;
DROP TABLE IF EXISTS public.battles CASCADE;
DROP TABLE IF EXISTS public.battle_queue CASCADE;
DROP TABLE IF EXISTS public.messages CASCADE;
DROP TABLE IF EXISTS public.comments CASCADE;
DROP TABLE IF EXISTS public.user_follows CASCADE;
DROP TABLE IF EXISTS public.clip_likes CASCADE;
DROP TABLE IF EXISTS public.clips CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

-- ============================================================================
-- 2. CREATE TABLES
-- ============================================================================

-- --- USERS TABLE ---
-- Synchronized with Supabase's auth.users table
CREATE TABLE public.users (
    uid UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT NOT NULL,
    avatar_url TEXT,
    bio TEXT,
    followers_count INTEGER DEFAULT 0,
    following_count INTEGER DEFAULT 0,
    likes_count INTEGER DEFAULT 0,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- --- CLIPS TABLE ---
-- Dance video clips and editing parameters
CREATE TABLE public.clips (
    id TEXT PRIMARY KEY,
    video_url TEXT NOT NULL,
    thumbnail_url TEXT,
    media_items TEXT, -- Stores complete multi-media JSON array to avoid overflow limits
    caption TEXT,
    music_name TEXT DEFAULT 'Original Audio',
    music_artist TEXT,
    dancer_uid UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    likes INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0,
    shares_count INTEGER DEFAULT 0,
    dance_style TEXT DEFAULT 'Freestyle',
    crop_aspect_ratio NUMERIC DEFAULT 0.5625,
    filter_type TEXT DEFAULT 'none',
    brightness NUMERIC DEFAULT 1.0,
    start_time_ms INTEGER DEFAULT 0,
    end_time_ms INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- --- CLIP LIKES TABLE ---
-- Maps many-to-many relationship of user likes on clips
CREATE TABLE public.clip_likes (
    user_uid UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    clip_id TEXT NOT NULL REFERENCES public.clips(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_uid, clip_id)
);

-- --- USER FOLLOWS TABLE ---
-- Tracks following/follower relationships between users
CREATE TABLE public.user_follows (
    follower_uid UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    following_uid UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (follower_uid, following_uid),
    CONSTRAINT cannot_follow_self CHECK (follower_uid <> following_uid)
);

-- --- COMMENTS TABLE ---
-- Comments on clips (denormalized user info as per app model requirements)
CREATE TABLE public.comments (
    id TEXT PRIMARY KEY,
    clip_id TEXT NOT NULL REFERENCES public.clips(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    avatar_url TEXT,
    comment_text TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT now()
);

-- --- MESSAGES TABLE ---
-- Direct messaging between users
CREATE TABLE public.messages (
    id TEXT PRIMARY KEY,
    chat_room_id TEXT NOT NULL,
    sender_uid UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    receiver_uid UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    message_text TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT now(),
    is_edited BOOLEAN DEFAULT false
);

-- --- BATTLE QUEUE TABLE ---
-- Queue for 1v1 battle matchmaking
CREATE TABLE public.battle_queue (
    user_uid UUID PRIMARY KEY REFERENCES public.users(uid) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- --- BATTLES TABLE ---
-- 1v1 battle matches, voting state, WebRTC SDPs, and ICE signaling candidates
CREATE TABLE public.battles (
    id TEXT PRIMARY KEY,
    user1_uid UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    user2_uid UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    user1_video_url TEXT,
    user2_video_url TEXT,
    combined_video_url TEXT,
    status TEXT DEFAULT 'matched', -- 'matched', 'ongoing', 'completed'
    first_dancer_uid UUID REFERENCES public.users(uid) ON DELETE SET NULL,
    user1_votes INTEGER DEFAULT 0,
    user2_votes INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    voting_ends_at TIMESTAMPTZ NOT NULL,
    winner_uid UUID REFERENCES public.users(uid) ON DELETE SET NULL,
    forfeit_winner_uid UUID REFERENCES public.users(uid) ON DELETE SET NULL,
    offer_sdp TEXT,
    answer_sdp TEXT,
    ice_candidates_user1 JSONB DEFAULT '[]'::jsonb,
    ice_candidates_user2 JSONB DEFAULT '[]'::jsonb,
    likes INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0
);

-- --- BATTLE VOTES TABLE ---
-- Tracks individual votes in battles to prevent double-voting
CREATE TABLE public.battle_votes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    battle_id TEXT NOT NULL REFERENCES public.battles(id) ON DELETE CASCADE,
    voter_uid UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    voted_for_uid UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE (battle_id, voter_uid)
);

-- --- BATTLE LIKES TABLE ---
-- Maps many-to-many relationship of user likes on battle events
CREATE TABLE public.battle_likes (
    user_uid UUID NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    battle_id TEXT NOT NULL REFERENCES public.battles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_uid, battle_id)
);

-- --- BATTLE COMMENTS TABLE ---
-- Comments on battle events (denormalized user info as per app model requirements)
CREATE TABLE public.battle_comments (
    id TEXT PRIMARY KEY,
    battle_id TEXT NOT NULL REFERENCES public.battles(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    avatar_url TEXT,
    comment_text TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT now()
);

-- ============================================================================
-- 3. SUPABASE STORAGE BUCKETS CONFIGURATION
-- ============================================================================
-- Creates buckets required for file uploads if they do not exist
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('media', 'media', true),
  ('posts', 'posts', true),
  ('battle', 'battle', true)
ON CONFLICT (id) DO NOTHING;


-- ============================================================================
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clip_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.battle_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.battles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.battle_votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.battle_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.battle_comments ENABLE ROW LEVEL SECURITY;

-- --- USERS POLICIES ---
CREATE POLICY "Public Read Profiles" ON public.users 
    FOR SELECT USING (true);
CREATE POLICY "Allow Profile Creation" ON public.users 
    FOR INSERT WITH CHECK (true); -- FK to auth.users handles validation securely
CREATE POLICY "Owner Update Profile" ON public.users 
    FOR UPDATE USING (auth.uid() = uid);

-- --- CLIPS POLICIES ---
CREATE POLICY "Public Read Clips" ON public.clips 
    FOR SELECT USING (true);
CREATE POLICY "Authenticated Create Clips" ON public.clips 
    FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND auth.uid() = dancer_uid);
CREATE POLICY "Owner Update Clips" ON public.clips 
    FOR UPDATE USING (auth.uid() = dancer_uid);
CREATE POLICY "Owner Delete Clips" ON public.clips 
    FOR DELETE USING (auth.uid() = dancer_uid);

-- --- CLIP LIKES POLICIES ---
CREATE POLICY "Public Read Clip Likes" ON public.clip_likes 
    FOR SELECT USING (true);
CREATE POLICY "Authenticated Insert Clip Like" ON public.clip_likes 
    FOR INSERT WITH CHECK (auth.uid() = user_uid);
CREATE POLICY "Authenticated Delete Clip Like" ON public.clip_likes 
    FOR DELETE USING (auth.uid() = user_uid);

-- --- USER FOLLOWS POLICIES ---
CREATE POLICY "Public Read Follows" ON public.user_follows 
    FOR SELECT USING (true);
CREATE POLICY "Authenticated Insert Follow" ON public.user_follows 
    FOR INSERT WITH CHECK (auth.uid() = follower_uid);
CREATE POLICY "Authenticated Delete Follow" ON public.user_follows 
    FOR DELETE USING (auth.uid() = follower_uid);

-- --- COMMENTS POLICIES ---
CREATE POLICY "Public Read Comments" ON public.comments 
    FOR SELECT USING (true);
CREATE POLICY "Authenticated Insert Comments" ON public.comments 
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Authenticated Delete/Update Comments" ON public.comments 
    FOR ALL USING (auth.role() = 'authenticated');

-- --- MESSAGES POLICIES ---
CREATE POLICY "Read Own Messages" ON public.messages 
    FOR SELECT USING (auth.uid() = sender_uid OR auth.uid() = receiver_uid);
CREATE POLICY "Insert Own Messages" ON public.messages 
    FOR INSERT WITH CHECK (auth.uid() = sender_uid);
CREATE POLICY "Update Own Messages" ON public.messages 
    FOR UPDATE USING (auth.uid() = sender_uid);
CREATE POLICY "Delete Own Messages" ON public.messages 
    FOR DELETE USING (auth.uid() = sender_uid);

-- --- BATTLE QUEUE POLICIES ---
CREATE POLICY "Public Read Queue" ON public.battle_queue 
    FOR SELECT USING (true);
CREATE POLICY "Owner Insert Queue" ON public.battle_queue 
    FOR INSERT WITH CHECK (auth.uid() = user_uid);
CREATE POLICY "Owner Delete Queue" ON public.battle_queue 
    FOR DELETE USING (auth.role() = 'authenticated');

-- --- BATTLES POLICIES ---
CREATE POLICY "Public Read Battles" ON public.battles 
    FOR SELECT USING (true);
CREATE POLICY "Authenticated Insert Battle" ON public.battles 
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Authenticated Update Battle" ON public.battles 
    FOR UPDATE USING (auth.role() = 'authenticated');
CREATE POLICY "Authenticated Delete Battle" ON public.battles 
    FOR DELETE USING (auth.role() = 'authenticated');

-- --- BATTLE VOTES POLICIES ---
CREATE POLICY "Public Read Battle Votes" ON public.battle_votes 
    FOR SELECT USING (true);
CREATE POLICY "Authenticated Vote" ON public.battle_votes 
    FOR INSERT WITH CHECK (auth.uid() = voter_uid);

-- --- BATTLE LIKES POLICIES ---
CREATE POLICY "Public Read Battle Likes" ON public.battle_likes 
    FOR SELECT USING (true);
CREATE POLICY "Authenticated Insert Battle Like" ON public.battle_likes 
    FOR INSERT WITH CHECK (auth.uid() = user_uid);
CREATE POLICY "Authenticated Delete Battle Like" ON public.battle_likes 
    FOR DELETE USING (auth.uid() = user_uid);

-- --- BATTLE COMMENTS POLICIES ---
CREATE POLICY "Public Read Battle Comments" ON public.battle_comments 
    FOR SELECT USING (true);
CREATE POLICY "Authenticated Insert Battle Comments" ON public.battle_comments 
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');
CREATE POLICY "Authenticated Delete/Update Battle Comments" ON public.battle_comments 
    FOR ALL USING (auth.role() = 'authenticated');


-- ============================================================================
-- ============================================================================
-- 5. STORAGE OBJECTS POLICIES
-- ============================================================================
-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 1. SELECT (Read) policy: Allow anyone to view files in media, posts, and battle buckets
DROP POLICY IF EXISTS "Public Read Access" ON storage.objects;
CREATE POLICY "Public Read Access" ON storage.objects
    FOR SELECT USING (bucket_id IN ('media', 'posts', 'battle'));

-- 2. INSERT (Upload) policy: Allow authenticated users to upload to their own UID folder
DROP POLICY IF EXISTS "Authenticated User Upload" ON storage.objects;
CREATE POLICY "Authenticated User Upload" ON storage.objects
    FOR INSERT WITH CHECK (
        auth.role() = 'authenticated'
        AND bucket_id IN ('media', 'posts', 'battle')
        AND auth.uid()::text = split_part(name, '/', 1)
    );

-- 3. UPDATE policy: Allow users to update files in their own folder
DROP POLICY IF EXISTS "Owner Update Access" ON storage.objects;
CREATE POLICY "Owner Update Access" ON storage.objects
    FOR UPDATE USING (
        auth.role() = 'authenticated'
        AND bucket_id IN ('media', 'posts', 'battle')
        AND auth.uid()::text = split_part(name, '/', 1)
    );

-- 4. DELETE policy: Allow users to delete files in their own folder
DROP POLICY IF EXISTS "Owner Delete Access" ON storage.objects;
CREATE POLICY "Owner Delete Access" ON storage.objects
    FOR DELETE USING (
        auth.role() = 'authenticated'
        AND bucket_id IN ('media', 'posts', 'battle')
        AND auth.uid()::text = split_part(name, '/', 1)
    );
-- ============================================================================


-- ============================================================================
-- 6. SUPABASE REALTIME CONFIGURATION
-- ============================================================================
-- Enables realtime listening for the messages and battles tables.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    ALTER PUBLICATION supabase_realtime ADD TABLE public.battles;
  ELSE
    CREATE PUBLICATION supabase_realtime FOR TABLE public.messages, public.battles;
  END IF;
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;
