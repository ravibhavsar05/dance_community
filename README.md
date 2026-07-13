# Dance Pulse (Dance Community App)

Dance Pulse is a mobile application built with Flutter designed for the dance community, enabling media sharing, 1v1 video battles, realtime messaging, and follower interactions.

---

## 🚀 Getting Started

### 1. Prerequisites
- **Flutter SDK**: Make sure you have Flutter installed and configured (SDK version `^3.10.0`).
- **Supabase Account**: You will need a Supabase project for backend, database, and storage configurations.

---

## 🔑 Environment Variables & Services Setup

Sensitive configurations (such as your Supabase API credentials and Firebase configuration files) must be set up locally and **never** be pushed to Git.

### 1. Supabase Environment Variables
1. **Copy the environment template**:
   ```bash
   cp .env.example .env
   ```
2. **Fill in your credentials** in `.env`:
   ```env
   SUPABASE_URL=https://your-project-id.supabase.co
   SUPABASE_ANON_KEY=your-supabase-anon-key
   ```
3. **Run or build the app** by passing the environment variables:
   ```bash
   # Run local dev build
   flutter run --dart-define-from-file=.env

   # Build Android APK / iOS App Bundle
   flutter build apk --dart-define-from-file=.env
   flutter build ipa --dart-define-from-file=.env
   ```

### 2. Firebase Configuration Files
To enable Firebase services:
1. Place your downloaded `google-services.json` file in [android/app/](file:///Users/akshay/Documents/Akshay/waypoint/kanhasoft%20github%20project/dance_community/android/app).
2. Place your downloaded `GoogleService-Info.plist` file in [ios/Runner/](file:///Users/akshay/Documents/Akshay/waypoint/kanhasoft%20github%20project/dance_community/ios/Runner).


> [!NOTE]
> If no `--dart-define-from-file` parameter is provided, the application will fallback to default credentials set in `lib/main.dart` for convenience.

---

## ⚡ Supabase Setup Guide

This project relies on Supabase for the database, user auth, storage, and realtime messaging. Follow these steps to configure your Supabase backend:

### 1. Database Schema
We provide a unified schema setup script in [supabase_schema.sql](file:///Users/akshay/Documents/Akshay/waypoint/kanhasoft%20github%20project/dance_community/supabase_schema.sql).
1. Open the [Supabase Dashboard](https://supabase.com/).
2. Select your project and navigate to the **SQL Editor** on the left menu.
3. Click **New Query**, paste the full contents of [supabase_schema.sql](file:///Users/akshay/Documents/Akshay/waypoint/kanhasoft%20github%20project/dance_community/supabase_schema.sql), and click **Run**.

This script automatically creates:
- Core tables (`users`, `clips`, `clip_likes`, `user_follows`, `comments`, `messages`, `battles`, `battle_queue`, `battle_votes`, `battle_likes`, `battle_comments`).
- Storage buckets (`media`, `posts`, `battle`).
- Row Level Security (RLS) tables and storage policies.
- Triggers, constraints, and realtime channel subscriptions.

---

### 📦 2. Storage Buckets
The application uploads user media, profile avatars, and battle clips to Supabase Storage. The storage buckets must be configured as **Public**.

The SQL script creates them automatically, but if you prefer to create them manually, ensure the following buckets exist and are marked **Public**:
- `media`: For general asset uploads.
- `posts`: For post videos, HLS transcoded playlists, thumbnails, and images.
- `battle`: For video battles, combined battle feeds, and logs.

#### Row Level Security (RLS) Storage Policies
For secure access control, the following storage policies are defined in our [supabase_schema.sql](file:///Users/akshay/Documents/Akshay/waypoint/kanhasoft%20github%20project/dance_community/supabase_schema.sql) file:
1. **Public Read Access**: Anyone can view files in the `media`, `posts`, and `battle` buckets.
2. **Authenticated Upload**: Only logged-in users can upload files, and uploads must go to a folder named after their own UID (e.g. `posts/{user_uid}/...`).
3. **Owner Update**: Users can only replace files in their own UID folders.
4. **Owner Delete**: Users can only delete files in their own UID folders.

---

### 💬 3. Realtime Messaging
Realtime sync is used to power direct messages and battle status. Realtime must be enabled for:
- `public.messages`
- `public.battles`

The SQL script automatically adds these tables to the `supabase_realtime` publication. You can verify this in your Supabase Dashboard under **Database** -> **Replication** -> **Source tables**.

---