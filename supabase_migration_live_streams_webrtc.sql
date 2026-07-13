-- ============================================================================
-- Migration: Add WebRTC signalling columns to live_streams
-- ============================================================================
-- Run this in Supabase Dashboard → SQL Editor → New Query if your
-- live_streams table was created before these columns were added to
-- the schema (you'll see error PGRST204 / "Could not find the 'answer_sdp'
-- column of 'live_streams' in the schema cache").
-- ============================================================================

ALTER TABLE public.live_streams
  ADD COLUMN IF NOT EXISTS offer_sdp             TEXT,
  ADD COLUMN IF NOT EXISTS answer_sdp            TEXT,
  ADD COLUMN IF NOT EXISTS ice_candidates_host   JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS ice_candidates_viewer JSONB DEFAULT '[]'::jsonb;
