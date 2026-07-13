import 'package:firebasecrashreport/app/utils/app_logger.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:firebasecrashreport/app/data/models/dance_models.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class SupabaseStore {
  static const int votingDurationHours = 48;
  static final SupabaseStore instance = SupabaseStore._init();
  SupabaseStore._init();

  SupabaseClient get _client => Supabase.instance.client;

  static DancerProfile _profileFromMap(Map<String, dynamic> data) {
    final String rawBio = data['bio'] as String? ?? '';
    String cleanBio = rawBio;
    String? gender;
    DateTime? dateOfBirth;

    // Parse [gender:...]
    final genderRegExp = RegExp(r'\[gender:([^\]]+)\]');
    final genderMatch = genderRegExp.firstMatch(rawBio);
    if (genderMatch != null) {
      gender = genderMatch.group(1);
      cleanBio = cleanBio.replaceAll(genderMatch.group(0)!, '');
    }

    // Parse [dob:...]
    final dobRegExp = RegExp(r'\[dob:([^\]]+)\]');
    final dobMatch = dobRegExp.firstMatch(rawBio);
    if (dobMatch != null) {
      final dobString = dobMatch.group(1);
      dateOfBirth = DateTime.tryParse(dobString ?? '');
      cleanBio = cleanBio.replaceAll(dobMatch.group(0)!, '');
    }

    cleanBio = cleanBio.trim();

    return DancerProfile(
      uid: data['uid'] as String,
      username: data['username'] as String,
      displayName: data['display_name'] as String,
      avatarUrl: data['avatar_url'] as String? ?? defaultAvatarUrl,
      bio: cleanBio,
      followersCount: data['followers_count'] as int? ?? 0,
      followingCount: data['following_count'] as int? ?? 0,
      likesCount: data['likes_count'] as int? ?? 0,
      isVerified: data['is_verified'] as bool? ?? false,
      danceStyles: const ["Hip Hop", "Freestyle"],
      gender: gender,
      dateOfBirth: dateOfBirth,
    );
  }

  // --- CRUD API METHODS ---

  Future<DancerProfile?> getUserProfile(String uid) async {
    if (uid == 'guest') {
      return null;
    }
    try {
      final response = await _client.from('users').select().eq('uid', uid).maybeSingle();

      if (response != null) {
        return _profileFromMap(response);
      }

      // If user profile is missing but the session matches the requested UID, auto-create it
      final currentUser = _client.auth.currentUser;
      if (currentUser != null && currentUser.id == uid) {
        final email = currentUser.email ?? "dancer";
        final username = email.split('@').first;
        final fallbackProfile = DancerProfile(
          uid: uid,
          username: "${username}_${DateTime.now().millisecondsSinceEpoch % 1000}",
          displayName: username,
          avatarUrl: defaultAvatarUrl,
          bio: "Just joined the Dance Community! 🕺💃",
          followersCount: 0,
          followingCount: 0,
          likesCount: 0,
          danceStyles: const ["All Styles"],
        );
        await saveUserProfile(fallbackProfile);
        return fallbackProfile;
      }

      return null;
    } catch (e) {
      appLog("Error in getUserProfile: $e");
      return null;
    }
  }

  Future<void> saveUserProfile(DancerProfile profile) async {
    try {
      String dbBio = profile.bio;
      if (profile.gender != null) {
        dbBio += ' [gender:${profile.gender}]';
      }
      if (profile.dateOfBirth != null) {
        dbBio += ' [dob:${profile.dateOfBirth!.toIso8601String()}]';
      }

      await _client.from('users').upsert({
        'uid': profile.uid,
        'username': profile.username,
        'display_name': profile.displayName,
        'avatar_url': profile.avatarUrl,
        'bio': dbBio,
        'followers_count': profile.followersCount,
        'following_count': profile.followingCount,
        'likes_count': profile.likesCount,
        'is_verified': profile.isVerified,
      });
    } catch (e) {
      appLog("Error in saveUserProfile: $e");
    }
  }

  Future<List<DanceClip>> getClips(String currentUid) async {
    try {
      final clipsResponse = await _client
          .from('clips')
          .select('*, users!clips_dancer_uid_fkey(*)')
          .order('created_at', ascending: false);

      final List<dynamic> clipsList = clipsResponse as List<dynamic>;

      final Set<String> likedClipIds = {};
      final Set<String> followedDancerUids = {};

      if (currentUid != 'guest') {
        final likedResponse = await _client.from('clip_likes').select('clip_id').eq('user_uid', currentUid);
        likedClipIds.addAll((likedResponse as List<dynamic>).map((row) => row['clip_id'] as String));

        final followedResponse = await _client
            .from('user_follows')
            .select('following_uid')
            .eq('follower_uid', currentUid);
        followedDancerUids.addAll((followedResponse as List<dynamic>)
            .map((row) => row['following_uid'] as String));
      }

      final List<DanceClip> clips = [];
      for (var row in clipsList) {
        final id = row['id'] as String;
        final dancerUid = row['dancer_uid'] as String;

        final userData = (row['users'] ?? row['users!clips_dancer_uid_fkey']) as Map<String, dynamic>?;
        final dancerName = userData?['username'] as String? ?? 'dancer';
        final dancerAvatar = userData?['avatar_url'] as String? ?? defaultAvatarUrl;

        clips.add(
          DanceClip(
            id: id,
            videoUrl: row['video_url'] as String,
            thumbnailUrl: row['thumbnail_url'] as String? ?? '',
            caption: row['caption'] as String? ?? '',
            musicName: row['music_name'] as String? ?? 'Original Audio',
            musicArtist: row['music_artist'] as String? ?? '',
            dancerUid: dancerUid,
            dancerName: dancerName,
            dancerAvatar: dancerAvatar,
            likes: row['likes'] as int? ?? 0,
            commentsCount: row['comments_count'] as int? ?? 0,
            sharesCount: row['shares_count'] as int? ?? 0,
            danceStyle: row['dance_style'] as String? ?? 'Freestyle',
            isLikedByMe: likedClipIds.contains(id),
            isFollowedByMe: followedDancerUids.contains(dancerUid),
            cropAspectRatio: (row['crop_aspect_ratio'] as num?)?.toDouble() ?? 0.5625,
            filterType: row['filter_type'] as String? ?? 'none',
            brightness: (row['brightness'] as num?)?.toDouble() ?? 1.0,
            startTimeMs: row['start_time_ms'] as int? ?? 0,
            endTimeMs: row['end_time_ms'] as int? ?? 0,
            // Read multi-media JSON from dedicated column (avoids VARCHAR(512) overflow)
            mediaItemsJson: row['media_items'] as String?,
          ),
        );
      }
      return clips;
    } catch (e) {
      appLog("Error in getClips: $e");
      rethrow;
    }
  }

  bool _isVideoFile(String path) {
    final pathLower = path.toLowerCase();
    if (pathLower.endsWith('.mp4') ||
        pathLower.endsWith('.mov') ||
        pathLower.endsWith('.mkv') ||
        pathLower.endsWith('.3gp') ||
        pathLower.endsWith('.avi') ||
        pathLower.endsWith('.webm') ||
        pathLower.endsWith('.m4v')) {
      return true;
    }
    if (pathLower.endsWith('.jpg') ||
        pathLower.endsWith('.jpeg') ||
        pathLower.endsWith('.png') ||
        pathLower.endsWith('.webp') ||
        pathLower.endsWith('.gif') ||
        pathLower.endsWith('.heic') ||
        pathLower.endsWith('.heif')) {
      return false;
    }
    // Fallback: picked file from image_picker
    return !pathLower.contains('image_picker') && !pathLower.contains('avatar');
  }

  Future<String> _uploadMediaFile(
    String localPath,
    String userUid, {
    String? postId,
    String? bucket,
    String? customPrefix,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      return localPath;
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${localPath.split('/').last}';
    final isVideo = _isVideoFile(localPath);
    final targetBuckets = bucket != null
        ? [bucket]
        : (isVideo
              ? ['videos', 'media', 'clips', 'posts', 'post', 'video']
              : ['media', 'posts', 'post', 'clips', 'images', 'image']);

    final attempts = <Map<String, String>>[];
    if (customPrefix != null && customPrefix.isNotEmpty) {
      for (var bucketName in targetBuckets) {
        attempts.add({'bucket': bucketName, 'path': '$customPrefix/$fileName'});
      }
    } else {
      if (postId != null && postId.isNotEmpty) {
        for (var bucket in targetBuckets) {
          attempts.addAll([
            {'bucket': bucket, 'path': 'post/$postId/$fileName'},
            {'bucket': bucket, 'path': '$postId/$fileName'},
            {'bucket': bucket, 'path': 'posts/$postId/$fileName'},
          ]);
        }
        // userUid nested prefixes for User ID restricted RLS policies
        for (var bucket in targetBuckets) {
          attempts.addAll([
            {'bucket': bucket, 'path': '$userUid/$postId/$fileName'},
            {'bucket': bucket, 'path': '$userUid/post/$postId/$fileName'},
            {'bucket': bucket, 'path': '$userUid/posts/$postId/$fileName'},
          ]);
        }
      }
      for (var bucket in targetBuckets) {
        attempts.addAll([
          {'bucket': bucket, 'path': '$userUid/$fileName'},
        ]);
      }
    }

    final errors = <String>[];
    final currentUser = _client.auth.currentUser;
    appLog("--- Upload Info ---");
    appLog("Authenticated User ID (auth.uid): ${currentUser?.id}");
    appLog("Authenticated User Role: ${currentUser?.role}");
    appLog("User UID passed to method: $userUid");
    appLog("-------------------");
    for (var attempt in attempts) {
      final bucket = attempt['bucket']!;
      final storagePath = attempt['path']!;
      try {
        await _client.storage
            .from(bucket)
            .upload(storagePath, file, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));
        final publicUrl = _client.storage.from(bucket).getPublicUrl(storagePath);
        final authenticatedUrl = publicUrl.replaceFirst('/object/public/', '/object/authenticated/');
        appLog("Successfully uploaded to $bucket: $authenticatedUrl");
        return authenticatedUrl;
      } catch (e) {
        final errorMsg = "Bucket: $bucket, Path: $storagePath, Error: $e";
        appLog("Failed to upload: $errorMsg");
        errors.add(errorMsg);
      }
    }
    throw Exception(
      "StorageUploadException: Failed to upload file $fileName to any configured Supabase bucket/path combination.\nErrors:\n${errors.join('\n')}",
    );
  }

  Future<File?> _resizeAndCompressImage(img.Image decodedImage, String sizeFolder, Directory tempDir) async {
    try {
      int? width;
      int? height;
      int quality = 85;

      switch (sizeFolder) {
        case 'thumb':
          width = 150;
          height = 150;
          quality = 60;
          break;
        case 'small':
          width = 320;
          height = 320;
          quality = 70;
          break;
        case 'medium':
          width = 640;
          height = 640;
          quality = 80;
          break;
        case 'large':
          width = 1080;
          height = 1080;
          quality = 85;
          break;
        case 'original':
        default:
          quality = 90;
          break;
      }

      img.Image resizedImage;
      if (width != null && height != null) {
        resizedImage = img.copyResize(decodedImage, width: width, height: height);
      } else {
        resizedImage = decodedImage;
      }

      final compressedBytes = img.encodeJpg(resizedImage, quality: quality);
      final compressedFile = File('${tempDir.path}/$sizeFolder.jpg');
      await compressedFile.writeAsBytes(compressedBytes);
      return compressedFile;
    } catch (e) {
      appLog("Error compressing image for $sizeFolder: $e");
      return null;
    }
  }

  Future<String> _uploadMediaFileWithSizeFolders(
    String localPath,
    String userUid, {
    String? postId,
    String? bucket,
    String? customPrefix,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      return localPath;
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${localPath.split('/').last}';
    final folders = ['original', 'thumb', 'small', 'medium', 'large'];

    final isVideo = _isVideoFile(localPath);
    final targetBuckets = bucket != null
        ? [bucket]
        : (isVideo
              ? ['videos', 'media', 'clips', 'posts', 'post', 'video']
              : ['media', 'posts', 'post', 'clips', 'images', 'image']);

    final configs = <Map<String, String>>[];
    if (customPrefix != null && customPrefix.isNotEmpty) {
      for (var bucketName in targetBuckets) {
        configs.add({'bucket': bucketName, 'prefix': customPrefix});
      }
    } else {
      if (postId != null && postId.isNotEmpty) {
        for (var bucketName in targetBuckets) {
          configs.addAll([
            {'bucket': bucketName, 'prefix': 'post/$postId'},
            {'bucket': bucketName, 'prefix': postId},
            {'bucket': bucketName, 'prefix': 'posts/$postId'},
          ]);
        }
        // userUid nested prefixes for User ID restricted RLS policies
        for (var bucketName in targetBuckets) {
          configs.addAll([
            {'bucket': bucketName, 'prefix': '$userUid/$postId'},
            {'bucket': bucketName, 'prefix': '$userUid/post/$postId'},
            {'bucket': bucketName, 'prefix': '$userUid/posts/$postId'},
          ]);
        }
      }
      for (var bucketName in targetBuckets) {
        configs.addAll([
          {'bucket': bucketName, 'prefix': userUid},
        ]);
      }
    }

    img.Image? decodedImage;
    Directory? tempDir;
    if (!isVideo) {
      try {
        final bytes = await file.readAsBytes();
        decodedImage = img.decodeImage(bytes);
        if (decodedImage != null) {
          tempDir = Directory.systemTemp.createTempSync('img_compress_');
        }
      } catch (e) {
        appLog("Failed to pre-decode image for sizing/compression: $e");
      }
    }

    final errors = <String>[];
    final currentUser = _client.auth.currentUser;
    appLog("--- Upload Info (Sized Folders) ---");
    appLog("Authenticated User ID (auth.uid): ${currentUser?.id}");
    appLog("Authenticated User Role: ${currentUser?.role}");
    appLog("User UID passed to method: $userUid");
    appLog("------------------------------------");
    try {
      for (var config in configs) {
        final bucketName = config['bucket']!;
        final prefix = config['prefix']!;
        bool uploadSuccess = true;
        String resultUrl = '';

        for (var folder in folders) {
          final storagePath = '$prefix/$folder/$fileName';
          File fileToUpload = file;
          File? tempCompressedFile;

          if (decodedImage != null && tempDir != null) {
            tempCompressedFile = await _resizeAndCompressImage(decodedImage, folder, tempDir);
            if (tempCompressedFile != null && await tempCompressedFile.exists()) {
              fileToUpload = tempCompressedFile;
            }
          }

          try {
            await _client.storage
                .from(bucketName)
                .upload(storagePath, fileToUpload, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));
            if (folder == 'original') {
              final publicUrl = _client.storage.from(bucketName).getPublicUrl(storagePath);
              resultUrl = publicUrl.replaceFirst('/object/public/', '/object/authenticated/');
            }
          } catch (e) {
            final errorMsg = "Bucket: $bucketName, Path: $storagePath, Error: $e";
            appLog("Failed to upload: $errorMsg");
            errors.add(errorMsg);
            uploadSuccess = false;
            break;
          }
        }

        if (uploadSuccess && resultUrl.isNotEmpty) {
          appLog(
            "Successfully uploaded all compressed sizes to bucket $bucketName under prefix $prefix. Original URL: $resultUrl",
          );
          return resultUrl;
        }
      }
    } finally {
      if (tempDir != null && tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (e) {
          appLog("Error deleting temp image compression dir: $e");
        }
      }
    }

    try {
      return await _uploadMediaFile(localPath, userUid, postId: postId, bucket: bucket, customPrefix: customPrefix);
    } catch (e) {
      throw Exception(
        "StorageUploadException: Failed to upload file $fileName to any configured Supabase bucket/path combination.\n"
        "Sized Folder Upload Errors:\n${errors.join('\n')}\n"
        "Single File Upload Error:\n$e",
      );
    }
  }

  static String getSizedImageUrl(String url, String size) {
    if (url.startsWith('http') && url.contains('/original/')) {
      return url.replaceFirst('/original/', '/$size/');
    }
    return url;
  }

  static Map<String, String>? getHeadersForUrl(String url) {
    if (url.contains('/object/authenticated/')) {
      final jwt = Supabase.instance.client.auth.currentSession?.accessToken;
      if (jwt != null) {
        return {'Authorization': 'Bearer $jwt'};
      }
    }
    return null;
  }

  static String getChatRoomId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? 'chat_${uid1}_$uid2' : 'chat_${uid2}_$uid1';
  }

  Future<Map<String, String>> _uploadVideoHLS(
    String localPath,
    String userUid, {
    String? postId,
    String? bucket,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      return {'videoUrl': localPath, 'thumbnailUrl': localPath};
    }

    final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();
    final cacheDir = await getTemporaryDirectory();
    final tempDir = Directory('${cacheDir.path}/hls_transcode_$uniqueId');
    await tempDir.create(recursive: true);

    final m3u8File = File('${tempDir.path}/playlist.m3u8');
    final thumbFile = File('${tempDir.path}/cover.jpg');

    // HLS copy segmenting command: copy video and audio codecs (extremely fast, zero re-encoding time)
    final ffmpegCommand = '-i "$localPath" -codec copy -hls_time 6 -hls_list_size 0 -f hls "${m3u8File.path}"';

    // Extract thumbnail frame at 0.5s (high quality jpeg)
    final thumbCommand = '-y -i "$localPath" -ss 00:00:00.500 -vframes 1 "${thumbFile.path}"';

    String uploadedThumbUrl = '';

    try {
      appLog("Executing FFmpeg command for thumbnail: $thumbCommand");
      final thumbSession = await FFmpegKit.execute(thumbCommand);
      final thumbReturnCode = await thumbSession.getReturnCode();
      final hasThumb = ReturnCode.isSuccess(thumbReturnCode) && await thumbFile.exists();

      if (hasThumb) {
        try {
          uploadedThumbUrl = await _uploadMediaFileWithSizeFolders(
            thumbFile.path,
            userUid,
            postId: postId,
            bucket: bucket,
          );
          appLog("Extracted thumbnail successfully uploaded to sized folders: $uploadedThumbUrl");
        } catch (e) {
          appLog("Failed to upload extracted thumbnail: $e");
        }
      }

      appLog("Executing FFmpeg command for HLS: $ffmpegCommand");
      var session = await FFmpegKit.execute(ffmpegCommand);
      var returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        appLog("FFmpeg copy-codec HLS failed. Retrying with full H.264/AAC transcoding...");
        // Clean up partial files in temp directory
        try {
          if (m3u8File.existsSync()) m3u8File.deleteSync();
          for (var entity in tempDir.listSync()) {
            if (entity is File && entity.path.endsWith('.ts')) {
              entity.deleteSync();
            }
          }
        } catch (_) {}

        final fallbackTranscodeCommand = '-y -i "$localPath" -c:v libx264 -c:a aac -pix_fmt yuv420p -preset ultrafast -hls_time 6 -hls_list_size 0 -f hls "${m3u8File.path}"';
        appLog("Executing FFmpeg transcode fallback for HLS: $fallbackTranscodeCommand");
        session = await FFmpegKit.execute(fallbackTranscodeCommand);
        returnCode = await session.getReturnCode();
      }

      if (ReturnCode.isSuccess(returnCode)) {
        appLog("FFmpeg HLS conversion succeeded!");

        final files = tempDir.listSync();

        final targetBuckets = bucket != null ? [bucket] : ['videos', 'media', 'clips', 'posts', 'post', 'video'];
        final configs = <Map<String, String>>[];
        if (postId != null && postId.isNotEmpty) {
          for (var bucketName in targetBuckets) {
            configs.addAll([
              if (bucket == null) ...[
                {'bucket': 'posts', 'prefix': 'post/$postId/videos/hls/$uniqueId'},
                {'bucket': 'posts', 'prefix': '$postId/videos/hls/$uniqueId'},
                {'bucket': 'posts', 'prefix': 'posts/$postId/videos/hls/$uniqueId'},
                {'bucket': bucketName, 'prefix': 'post/$postId/videos/hls/$uniqueId'},
                {'bucket': bucketName, 'prefix': '$postId/videos/hls/$uniqueId'},
              ],
            ]);
          }
          // userUid nested prefixes for User ID restricted RLS policies
          for (var bucketName in targetBuckets) {
            configs.addAll([
              if (bucket == null) ...[
                {'bucket': 'posts', 'prefix': '$userUid/$postId/videos/hls/$uniqueId'},
                {'bucket': 'posts', 'prefix': '$userUid/post/$postId/videos/hls/$uniqueId'},
                {'bucket': 'posts', 'prefix': '$userUid/posts/$postId/videos/hls/$uniqueId'},
                {'bucket': bucketName, 'prefix': '$userUid/post/$postId/videos/hls/$uniqueId'},
                {'bucket': bucketName, 'prefix': '$userUid/posts/$postId/videos/hls/$uniqueId'},
              ],
              {'bucket': bucketName, 'prefix': '$userUid/$postId/videos/hls/$uniqueId'},
            ]);
          }
        }
        for (var bucketName in targetBuckets) {
          configs.addAll([
            {'bucket': bucketName, 'prefix': '$userUid/videos/hls/$uniqueId'},
          ]);
        }

        final uploadErrors = <String>[];

        for (var config in configs) {
          final bucketName = config['bucket']!;
          final prefix = config['prefix']!;
          bool uploadSuccess = true;
          String playlistUrl = '';

          for (var entity in files) {
            if (entity is File) {
              final fileName = entity.path.split('/').last;
              // Do not upload cover.jpg to the HLS folder, it was already uploaded by _uploadMediaFileWithSizeFolders
              if (fileName == 'cover.jpg') {
                continue;
              }

              final storagePath = '$prefix/$fileName';
              try {
                await _client.storage
                    .from(bucketName)
                    .upload(storagePath, entity, fileOptions: const FileOptions(cacheControl: '3600', upsert: true));
                if (fileName == 'playlist.m3u8') {
                  playlistUrl = _client.storage.from(bucketName).getPublicUrl(storagePath);
                }
              } catch (e) {
                final errMsg = "Failed to upload HLS file $fileName to bucket $bucketName under prefix $prefix: $e. Auth UID: ${_client.auth.currentUser?.id}, Target UID: $userUid";
                appLog(errMsg);
                uploadErrors.add(errMsg);
                uploadSuccess = false;
                break;
              }
            }
          }

          if (uploadSuccess && playlistUrl.isNotEmpty) {
            appLog(
              "Successfully uploaded all HLS files to bucket $bucketName under prefix $prefix. Playlist URL: $playlistUrl",
            );
            try {
              tempDir.deleteSync(recursive: true);
            } catch (e) {
              appLog("Failed to clean up temp HLS dir: $e");
            }
            return {
              'videoUrl': playlistUrl,
              'thumbnailUrl': uploadedThumbUrl.isNotEmpty ? uploadedThumbUrl : playlistUrl,
            };
          }
        }
        throw Exception("Failed to upload HLS files to any configured storage bucket/prefix combination. Errors:\n${uploadErrors.join('\n')}");
      } else {
        final logs = await session.getAllLogs();
        final failLog = logs.map((l) => l.getMessage()).join('\n');
        throw Exception("FFmpeg HLS conversion failed: $failLog");
      }
    } catch (e) {
      appLog("Error during FFmpeg HLS conversion/upload: $e");
      rethrow;
    } finally {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    }
  }

  Future<void> insertClip(DanceClip clip) async {
    try {
      String videoUrl = clip.videoUrl;
      String thumbnailUrl = clip.thumbnailUrl;
      String? mediaItemsJson; // Written to the `media_items` TEXT column

      if (videoUrl.startsWith('[') && videoUrl.endsWith(']')) {
        final List<dynamic> items = jsonDecode(videoUrl);
        final List<Map<String, dynamic>> uploadedItems = [];

        for (var item in items) {
          final map = Map<String, dynamic>.from(item);
          String localUrl = map['url'] ?? '';
          String type = map['type'] ?? 'image';

          if (localUrl.isNotEmpty && !localUrl.startsWith('http://') && !localUrl.startsWith('https://')) {
            if (type == 'video') {
              final result = await _uploadVideoHLS(localUrl, clip.dancerUid, postId: clip.id, bucket: 'posts');
              map['url'] = result['videoUrl']!;
              map['thumbnailUrl'] = result['thumbnailUrl']!;
            } else {
              map['url'] = await _uploadMediaFileWithSizeFolders(
                localUrl,
                clip.dancerUid,
                postId: clip.id,
                bucket: 'posts',
              );
            }
          }
          uploadedItems.add(map);
        }

        // Store the full JSON in media_items (TEXT column — no length limit)
        mediaItemsJson = jsonEncode(uploadedItems);

        // video_url stores only the first item's URL so VARCHAR(512) is never exceeded
        if (uploadedItems.isNotEmpty) {
          final firstItem = uploadedItems.first;
          videoUrl = (firstItem['url'] as String?) ?? '';
          thumbnailUrl = firstItem['type'] == 'video'
              ? (firstItem['thumbnailUrl'] ?? firstItem['url'])
              : firstItem['url'];
        }
      } else {
        // If videoUrl is a local file, upload it
        if (!videoUrl.startsWith('http://') && !videoUrl.startsWith('https://')) {
          final isVideo = _isVideoFile(videoUrl);
          if (isVideo) {
            final result = await _uploadVideoHLS(videoUrl, clip.dancerUid, postId: clip.id, bucket: 'posts');
            videoUrl = result['videoUrl']!;
            thumbnailUrl = result['thumbnailUrl']!;
          } else {
            videoUrl = await _uploadMediaFileWithSizeFolders(
              videoUrl,
              clip.dancerUid,
              postId: clip.id,
              bucket: 'posts',
            );
          }
        }

        // If thumbnailUrl is a local file (and wasn't already uploaded during _uploadVideoHLS), upload it
        if (!thumbnailUrl.startsWith('http://') && !thumbnailUrl.startsWith('https://')) {
          thumbnailUrl = await _uploadMediaFileWithSizeFolders(
            thumbnailUrl,
            clip.dancerUid,
            postId: clip.id,
            bucket: 'posts',
          );
        }
      }

      await _client.from('clips').insert({
        'id': clip.id,
        'video_url': videoUrl,
        'thumbnail_url': thumbnailUrl,
        'media_items': mediaItemsJson, // TEXT column — stores full multi-media JSON
        'caption': clip.caption,
        'music_name': clip.musicName,
        'music_artist': clip.musicArtist,
        'dancer_uid': clip.dancerUid,
        'likes': clip.likes,
        'comments_count': clip.commentsCount,
        'shares_count': clip.sharesCount,
        'dance_style': clip.danceStyle,
        'crop_aspect_ratio': clip.cropAspectRatio,
        'filter_type': clip.filterType,
        'brightness': clip.brightness,
        'start_time_ms': clip.startTimeMs,
        'end_time_ms': clip.endTimeMs,
      });
    } catch (e) {
      appLog("Error in insertClip: $e");
      rethrow;
    }
  }

  Future<void> deleteClip(String clipId) async {
    try {
      final clipResponse = await _client.from('clips').select('likes, dancer_uid').eq('id', clipId).maybeSingle();

      if (clipResponse != null) {
        final likes = clipResponse['likes'] as int? ?? 0;
        final dancerUid = clipResponse['dancer_uid'] as String?;

        if (dancerUid != null && likes > 0) {
          try {
            final dancerProfile = await _client.from('users').select('likes_count').eq('uid', dancerUid).single();
            final newLikesCount = (dancerProfile['likes_count'] as int? ?? 0) - likes;

            await _client
                .from('users')
                .update({'likes_count': newLikesCount >= 0 ? newLikesCount : 0})
                .eq('uid', dancerUid);
          } catch (e) {
            appLog("Could not update dancer likes count on clip deletion: $e");
          }
        }
      }

      await _client.from('clip_likes').delete().eq('clip_id', clipId);

      await _client.from('comments').delete().eq('clip_id', clipId);

      await _client.from('clips').delete().eq('id', clipId);
    } catch (e) {
      appLog("Error in deleteClip: $e");
      rethrow;
    }
  }

  Future<void> updateClip(
    String clipId, {
    required String caption,
    required String danceStyle,
    required String musicName,
    required String musicArtist,
  }) async {
    try {
      await _client
          .from('clips')
          .update({'caption': caption, 'dance_style': danceStyle, 'music_name': musicName, 'music_artist': musicArtist})
          .eq('id', clipId);
    } catch (e) {
      appLog("Error in updateClip: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> toggleLike(String clipId, String userUid) async {
    try {
      final existing = await _client
          .from('clip_likes')
          .select()
          .eq('user_uid', userUid)
          .eq('clip_id', clipId)
          .maybeSingle();

      bool isLiked;
      int delta;
      if (existing != null) {
        await _client.from('clip_likes').delete().eq('user_uid', userUid).eq('clip_id', clipId);
        isLiked = false;
        delta = -1;
      } else {
        await _client.from('clip_likes').insert({'user_uid': userUid, 'clip_id': clipId});
        isLiked = true;
        delta = 1;
      }

      final clipResponse = await _client.from('clips').select('likes, dancer_uid').eq('id', clipId).single();
      final newLikes = (clipResponse['likes'] as int? ?? 0) + delta;
      final dancerUid = clipResponse['dancer_uid'] as String;

      await _client.from('clips').update({'likes': newLikes}).eq('id', clipId);

      try {
        final dancerProfile = await _client.from('users').select('likes_count').eq('uid', dancerUid).single();
        final newLikesCount = (dancerProfile['likes_count'] as int? ?? 0) + delta;

        await _client.from('users').update({'likes_count': newLikesCount}).eq('uid', dancerUid);
      } catch (e) {
        appLog("Could not update dancer likes count: $e");
      }

      return {'isLikedByMe': isLiked, 'likes': newLikes};
    } catch (e) {
      appLog("Error in toggleLike: $e");
      rethrow;
    }
  }

  Future<bool> toggleFollow(String followerUid, String followingUid) async {
    try {
      final existing = await _client
          .from('user_follows')
          .select()
          .eq('follower_uid', followerUid)
          .eq('following_uid', followingUid)
          .maybeSingle();

      bool isFollowed;
      int delta;
      if (existing != null) {
        await _client.from('user_follows').delete().eq('follower_uid', followerUid).eq('following_uid', followingUid);
        isFollowed = false;
        delta = -1;
      } else {
        await _client.from('user_follows').insert({'follower_uid': followerUid, 'following_uid': followingUid});
        isFollowed = true;
        delta = 1;
      }

      try {
        final followerProfile = await _client.from('users').select('following_count').eq('uid', followerUid).single();
        final newFollowing = (followerProfile['following_count'] as int? ?? 0) + delta;
        await _client.from('users').update({'following_count': newFollowing}).eq('uid', followerUid);
      } catch (e) {
        appLog("Could not update follower profile: $e");
      }

      try {
        final followingProfile = await _client.from('users').select('followers_count').eq('uid', followingUid).single();
        final newFollowers = (followingProfile['followers_count'] as int? ?? 0) + delta;
        await _client.from('users').update({'followers_count': newFollowers}).eq('uid', followingUid);
      } catch (e) {
        appLog("Could not update following profile: $e");
      }

      return isFollowed;
    } catch (e) {
      appLog("Error in toggleFollow: $e");
      rethrow;
    }
  }

  Future<List<Comment>> getComments(String clipId) async {
    try {
      final response = await _client
          .from('comments')
          .select()
          .eq('clip_id', clipId)
          .order('timestamp', ascending: false);

      final List<dynamic> list = response as List<dynamic>;
      return list
          .map(
            (c) => Comment(
              id: c['id'] as String,
              username: c['username'] as String,
              avatarUrl: c['avatar_url'] as String? ?? defaultAvatarUrl,
              commentText: c['comment_text'] as String,
              timestamp: DateTime.parse(c['timestamp'] as String),
            ),
          )
          .toList();
    } catch (e) {
      appLog("Error in getComments: $e");
      rethrow;
    }
  }

  Future<void> addComment(String clipId, Comment comment) async {
    try {
      await _client.from('comments').insert({
        'id': comment.id,
        'clip_id': clipId,
        'username': comment.username,
        'avatar_url': comment.avatarUrl,
        'comment_text': comment.commentText,
        'timestamp': comment.timestamp.toIso8601String(),
      });

      final clipResponse = await _client.from('clips').select('comments_count').eq('id', clipId).single();
      final currentComments = (clipResponse['comments_count'] as int? ?? 0) + 1;
      await _client.from('clips').update({'comments_count': currentComments}).eq('id', clipId);
    } catch (e) {
      appLog("Error in addComment: $e");
      rethrow;
    }
  }

  Future<List<ChatRoom>> getChatRooms(String currentUid) async {
    if (currentUid == 'guest') {
      return [];
    }
    try {
      final response = await _client
          .from('messages')
          .select()
          .or('sender_uid.eq.$currentUid,receiver_uid.eq.$currentUid')
          .order('timestamp', ascending: true);

      final msgsList = response as List<dynamic>;
      final Map<String, List<ChatMessage>> roomsMap = {};

      for (var m in msgsList) {
        final senderUid = m['sender_uid'] as String;
        final receiverUid = m['receiver_uid'] as String;
        final roomId = getChatRoomId(senderUid, receiverUid);
        if (!roomsMap.containsKey(roomId)) {
          roomsMap[roomId] = [];
        }
        roomsMap[roomId]!.add(
          ChatMessage(
            id: m['id'] as String,
            senderId: senderUid,
            receiverId: receiverUid,
            text: m['message_text'] as String,
            timestamp: (() {
              final tStr = m['timestamp'] as String;
              final hasTz = RegExp(r'(Z|([+-]\d{2}(:?\d{2})?))$').hasMatch(tStr);
              return DateTime.parse(hasTz ? tStr : '${tStr}Z').toUtc();
            })(),
          ),
        );
      }

      final List<ChatRoom> chatRooms = [];
      for (var entry in roomsMap.entries) {
        final roomId = entry.key;
        final roomMsgs = entry.value;

        String otherUid = '';
        if (roomMsgs.isNotEmpty) {
          otherUid = roomMsgs.first.senderId == currentUid ? roomMsgs.first.receiverId : roomMsgs.first.senderId;
        } else {
          final parts = roomId.replaceFirst('chat_', '').split('_');
          otherUid = parts.first == currentUid ? parts.last : parts.first;
        }

        DancerProfile? otherUser = await getUserProfile(otherUid);
        otherUser ??= DancerProfile(
          uid: otherUid,
          username: "dancer_${otherUid.substring(0, (otherUid.length > 4 ? 4 : otherUid.length))}",
          displayName: "Dancer ${otherUid.substring(0, (otherUid.length > 4 ? 4 : otherUid.length))}",
          avatarUrl: defaultAvatarUrl,
          bio: "Hey there! I am using Dance Pulse.",
          followersCount: 0,
          followingCount: 0,
          likesCount: 0,
          danceStyles: const ["Freestyle"],
        );

        chatRooms.add(ChatRoom(id: roomId, otherUser: otherUser, messages: roomMsgs));
      }
      return chatRooms;
    } catch (e) {
      appLog("Error in getChatRooms: $e");
      rethrow;
    }
  }

  Future<void> insertMessage(ChatMessage message, String chatRoomId) async {
    try {
      await _client.from('messages').insert({
        'id': message.id,
        'chat_room_id': chatRoomId,
        'sender_uid': message.senderId,
        'receiver_uid': message.receiverId,
        'message_text': message.text,
        'timestamp': message.timestamp.toIso8601String(),
      });
    } catch (e) {
      appLog("Error in insertMessage: $e");
      rethrow;
    }
  }

  Future<void> updateMessage(String messageId, String newText) async {
    try {
      await _client.from('messages').update({'message_text': newText, 'is_edited': true}).eq('id', messageId);
    } catch (e) {
      appLog("Error in updateMessage: $e");
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _client.from('messages').delete().eq('id', messageId);
    } catch (e) {
      appLog("Error in deleteMessage: $e");
      rethrow;
    }
  }

  Future<List<DanceClip>> getLikedClips(String currentUid) async {
    if (currentUid == 'guest') {
      return [];
    }
    try {
      final likedRows = await _client.from('clip_likes').select('clip_id').eq('user_uid', currentUid);

      final clipIds = (likedRows as List<dynamic>).map((row) => row['clip_id'] as String).toList();
      if (clipIds.isEmpty) return [];

      final clips = await getClips(currentUid);
      return clips.where((c) => clipIds.contains(c.id)).toList();
    } catch (e) {
      appLog("Error in getLikedClips: $e");
      return [];
    }
  }

  // --- CREDENTIALS & SESSIONS ---

  Future<DancerProfile?> authenticateUser(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user != null) {
        return await getUserProfile(user.id);
      }
      return null;
    } catch (e) {
      appLog("Error in authenticateUser: $e");
      rethrow;
    }
  }

  Future<bool> isEmailRegistered(String email) async {
    return false;
  }

  Future<bool> isUsernameRegistered(String username) async {
    try {
      final response = await _client.from('users').select().eq('username', username).maybeSingle();
      return response != null;
    } catch (e) {
      appLog("Error in isUsernameRegistered: $e");
      return false;
    }
  }

  Future<DancerProfile?> getProfileByUsername(String username) async {
    try {
      final response = await _client.from('users').select().eq('username', username).maybeSingle();
      if (response != null) {
        return _profileFromMap(response);
      }
      return null;
    } catch (e) {
      appLog("Error in getProfileByUsername: $e");
      return null;
    }
  }

  Future<DancerProfile?> registerUser({
    required DancerProfile profile,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(email: email, password: password);
      final user = response.user;
      if (user != null) {
        final newProfile = DancerProfile(
          uid: user.id,
          username: profile.username,
          displayName: profile.displayName,
          avatarUrl: profile.avatarUrl.isNotEmpty ? profile.avatarUrl : defaultAvatarUrl,
          bio: profile.bio,
          followersCount: profile.followersCount,
          followingCount: profile.followingCount,
          likesCount: profile.likesCount,
          isVerified: profile.isVerified,
          danceStyles: profile.danceStyles,
        );
        await saveUserProfile(newProfile);
        return newProfile;
      }
      return null;
    } catch (e) {
      appLog("Error in registerUser: $e");
      rethrow;
    }
  }

  Future<void> persistSession(String? uid) async {
    if (uid == null) {
      try {
        // Clear local session cache instantly and reliably
        await _client.auth.signOut(scope: SignOutScope.local);
      } catch (e) {
        appLog("Error in local signOut: $e");
      }

      // Attempt to notify server asynchronously in the background (do not await)
      _client.auth.signOut().catchError((err) {
        appLog("Error in background global signOut: $err");
        return null;
      });
    }
  }

  Future<String?> getPersistedSessionUid() async {
    return _client.auth.currentSession?.user.id;
  }

  Future<List<DancerProfile>> searchUsers(String query) async {
    try {
      if (query.isEmpty) {
        final response = await _client.from('users').select().limit(10);
        final List<dynamic> list = response as List<dynamic>;
        return list.map((d) => _profileFromMap(d as Map<String, dynamic>)).toList();
      }
      final response = await _client.from('users').select().or('username.ilike.%$query%,display_name.ilike.%$query%').limit(20);

      final List<dynamic> list = response as List<dynamic>;
      return list.map((d) => _profileFromMap(d as Map<String, dynamic>)).toList();
    } catch (e) {
      appLog("Error in searchUsers: $e");
      return [];
    }
  }

  Future<String> uploadAvatar(String localPath, String userUid) async {
    try {
      final avatarUrl = await _uploadMediaFileWithSizeFolders(
        localPath,
        userUid,
        bucket: 'media',
        customPrefix: 'avatars/$userUid',
      );
      return avatarUrl;
    } catch (e) {
      appLog("Error uploading avatar to sized folders in media bucket: $e");
      return localPath;
    }
  }

  // --- 1v1 BATTLE MATCHMAKING APIS ---

  Future<void> joinMatchmakingQueue(String userUid) async {
    try {
      await _client.from('battle_queue').upsert({'user_uid': userUid, 'created_at': DateTime.now().toIso8601String()});
      appLog("User $userUid joined battle queue.");
    } catch (e) {
      appLog("Error in joinMatchmakingQueue: $e");
      rethrow;
    }
  }

  Future<void> leaveMatchmakingQueue(String userUid) async {
    try {
      await _client.from('battle_queue').delete().eq('user_uid', userUid);
      appLog("User $userUid left battle queue.");
    } catch (e) {
      appLog("Error in leaveMatchmakingQueue: $e");
    }
  }

  Future<DanceBattle?> checkForAvailableMatch(String userUid) async {
    try {
      // Find someone in queue who is NOT the current user
      final queueResponse = await _client
          .from('battle_queue')
          .select()
          .neq('user_uid', userUid)
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (queueResponse != null) {
        final opponentUid = queueResponse['user_uid'] as String;

        // Try to match: remove both from queue first and select deleted rows to verify atomicity
        final List<dynamic> deleteResponse = await _client
            .from('battle_queue')
            .delete()
            .or('user_uid.eq.$userUid,user_uid.eq.$opponentUid')
            .select();

        if (deleteResponse.length < 2) {
          // One of the users was already matched and deleted by another process.
          // If we deleted ourselves, we must re-insert ourselves back to continue searching.
          final wasIDeleted = deleteResponse.any((item) => item['user_uid'] == userUid);
          if (wasIDeleted) {
            await _client.from('battle_queue').insert({'user_uid': userUid});
          }
          return null;
        }

        // Create a new battle
        final battleId = 'battle_${DateTime.now().millisecondsSinceEpoch}';
        final now = DateTime.now();
        final votingEndsAt = now.add(const Duration(hours: SupabaseStore.votingDurationHours));

        final battleMap = {
          'id': battleId,
          'user1_uid': opponentUid,
          'user2_uid': userUid,
          'status': 'matched',
          'created_at': now.toIso8601String(),
          'voting_ends_at': votingEndsAt.toIso8601String(),
          'user1_votes': 0,
          'user2_votes': 0,
        };

        await _client.from('battles').insert(battleMap);
        appLog("Match created: $battleId between $opponentUid and $userUid");
        return DanceBattle.fromMap(battleMap);
      }
      return null;
    } catch (e) {
      appLog("Error in checkForAvailableMatch: $e");
      return null;
    }
  }

  Future<DanceBattle?> getBattle(String battleId) async {
    try {
      final response = await _client.from('battles').select().eq('id', battleId).maybeSingle();

      if (response != null) {
        return DanceBattle.fromMap(response);
      }
      return null;
    } catch (e) {
      appLog("Error in getBattle: $e");
      return null;
    }
  }

  Future<void> updateBattleFirstDancer(String battleId, String firstDancerUid) async {
    try {
      await _client
          .from('battles')
          .update({'first_dancer_uid': firstDancerUid, 'status': 'ongoing'})
          .eq('id', battleId);
    } catch (e) {
      appLog("Error in updateBattleFirstDancer: $e");
    }
  }

  Future<void> updateBattleStatus(String battleId, String status) async {
    try {
      await _client.from('battles').update({'status': status}).eq('id', battleId);
    } catch (e) {
      appLog("Error in updateBattleStatus: $e");
    }
  }

  // --- WEBRTC SIGNALING APIS ---

  Future<void> sendSdpOffer(String battleId, String sdp) async {
    try {
      await _client.from('battles').update({'offer_sdp': sdp}).eq('id', battleId);
    } catch (e) {
      appLog("Error in sendSdpOffer: $e");
    }
  }

  Future<void> sendSdpAnswer(String battleId, String sdp) async {
    try {
      await _client.from('battles').update({'answer_sdp': sdp}).eq('id', battleId);
    } catch (e) {
      appLog("Error in sendSdpAnswer: $e");
    }
  }

  Future<void> clearBattleSignaling(String battleId) async {
    try {
      await _client
          .from('battles')
          .update({'offer_sdp': null, 'answer_sdp': null, 'ice_candidates_user1': null, 'ice_candidates_user2': null})
          .eq('id', battleId);
    } catch (e) {
      appLog("Error in clearBattleSignaling: $e");
    }
  }

  Future<void> addIceCandidate(String battleId, int userIndex, Map<String, dynamic> candidate) async {
    try {
      final battle = await getBattle(battleId);
      if (battle == null) {
        return;
      }

      if (userIndex == 1) {
        final currentCandidates = List<dynamic>.from(battle.iceCandidatesUser1 ?? []);
        currentCandidates.add(candidate);
        await _client.from('battles').update({'ice_candidates_user1': currentCandidates}).eq('id', battleId);
      } else {
        final currentCandidates = List<dynamic>.from(battle.iceCandidatesUser2 ?? []);
        currentCandidates.add(candidate);
        await _client.from('battles').update({'ice_candidates_user2': currentCandidates}).eq('id', battleId);
      }
    } catch (e) {
      appLog("Error in addIceCandidate: $e");
    }
  }

  // --- SAVING AND MERGING BATTLE VIDEOS ---

  Future<String> uploadBattleVideo(String localPath, String userUid, String battleId) async {
    try {
      final isVideo = _isVideoFile(localPath);
      if (isVideo) {
        final result = await _uploadVideoHLS(localPath, userUid, postId: battleId, bucket: 'battle');
        return result['videoUrl']!;
      } else {
        return await _uploadMediaFile(localPath, userUid, postId: battleId, bucket: 'battle');
      }
    } catch (e) {
      appLog("Error uploading battle video: $e");
      rethrow;
    }
  }

  Future<void> updateBattleVideoUrl(String battleId, int userIndex, String videoUrl) async {
    try {
      if (userIndex == 1) {
        await _client.from('battles').update({'user1_video_url': videoUrl}).eq('id', battleId);
      } else {
        await _client.from('battles').update({'user2_video_url': videoUrl}).eq('id', battleId);
      }
    } catch (e) {
      appLog("Error in updateBattleVideoUrl: $e");
    }
  }

  Future<void> updateBattleCombinedVideoUrl(String battleId, String videoUrl) async {
    try {
      await _client.from('battles').update({'combined_video_url': videoUrl, 'status': 'completed'}).eq('id', battleId);
    } catch (e) {
      appLog("Error in updateBattleCombinedVideoUrl: $e");
    }
  }

  // --- VOTING APIS ---

  Future<void> voteInBattle(String battleId, String voterUid, String votedForUid) async {
    try {
      // 1. Insert vote record
      await _client.from('battle_votes').insert({
        'battle_id': battleId,
        'voter_uid': voterUid,
        'voted_for_uid': votedForUid,
      });

      // 2. Increment corresponding vote counter in battles
      final battle = await getBattle(battleId);
      if (battle == null) {
        return;
      }

      if (votedForUid == battle.user1Uid) {
        await _client.from('battles').update({'user1_votes': battle.user1Votes + 1}).eq('id', battleId);
      } else if (votedForUid == battle.user2Uid) {
        await _client.from('battles').update({'user2_votes': battle.user2Votes + 1}).eq('id', battleId);
      }
    } catch (e) {
      appLog("Error in voteInBattle: $e");
      rethrow;
    }
  }

  Future<bool> hasVoted(String battleId, String voterUid) async {
    try {
      final response = await _client
          .from('battle_votes')
          .select()
          .eq('battle_id', battleId)
          .eq('voter_uid', voterUid)
          .maybeSingle();
      return response != null;
    } catch (e) {
      appLog("Error in hasVoted: $e");
      return false;
    }
  }

  Future<List<DanceBattle>> getBattles() async {
    try {
      final response = await _client
          .from('battles')
          .select()
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      final list = response as List<dynamic>;
      return list.map((b) => DanceBattle.fromMap(b as Map<String, dynamic>)).toList();
    } catch (e) {
      appLog("Error in getBattles: $e");
      return [];
    }
  }

  Future<List<DanceBattle>> getBattlesForUser(String userUid) async {
    try {
      final response = await _client
          .from('battles')
          .select()
          .or('user1_uid.eq.$userUid,user2_uid.eq.$userUid')
          .eq('status', 'completed')
          .order('created_at', ascending: false);

      final list = response as List<dynamic>;
      return list.map((b) => DanceBattle.fromMap(b as Map<String, dynamic>)).toList();
    } catch (e) {
      appLog("Error in getBattlesForUser: $e");
      return [];
    }
  }

  Future<bool> checkIsFollowing(String followerUid, String followingUid) async {
    if (followerUid == 'guest' || followingUid == 'guest') {
      return false;
    }
    try {
      final response = await _client
          .from('user_follows')
          .select()
          .eq('follower_uid', followerUid)
          .eq('following_uid', followingUid)
          .maybeSingle();
      return response != null;
    } catch (e) {
      appLog("Error in checkIsFollowing: $e");
      return false;
    }
  }

  Future<List<String>> getFollowedUserIds(String followerUid) async {
    if (followerUid == 'guest') {
      return [];
    }
    try {
      final response = await _client.from('user_follows').select('following_uid').eq('follower_uid', followerUid);
      return (response as List<dynamic>).map((row) => row['following_uid'] as String).toList();
    } catch (e) {
      appLog("Error in getFollowedUserIds: $e");
      return [];
    }
  }

  Future<void> forfeitBattle(String battleId, String forfeitingUserUid) async {
    try {
      final battle = await getBattle(battleId);
      if (battle == null || battle.status == 'completed') {
        return;
      }

      final winnerUid = battle.user1Uid == forfeitingUserUid ? battle.user2Uid : battle.user1Uid;

      await _client
          .from('battles')
          .update({'status': 'completed', 'forfeit_winner_uid': winnerUid, 'winner_uid': winnerUid})
          .eq('id', battleId);

      appLog("Battle $battleId forfeited by $forfeitingUserUid. Winner: $winnerUid");
    } catch (e) {
      appLog("Error in forfeitBattle: $e");
    }
  }

  Future<void> resolveBattleWinner(String battleId, String winnerUid) async {
    try {
      await _client.from('battles').update({'winner_uid': winnerUid}).eq('id', battleId);
      appLog("Resolved battle $battleId winner: $winnerUid");
    } catch (e) {
      appLog("Error in resolveBattleWinner: $e");
    }
  }

  Future<String?> getVotedForUid(String battleId, String voterUid) async {
    try {
      final response = await _client
          .from('battle_votes')
          .select('voted_for_uid')
          .eq('battle_id', battleId)
          .eq('voter_uid', voterUid)
          .maybeSingle();
      if (response != null) {
        return response['voted_for_uid'] as String?;
      }
      return null;
    } catch (e) {
      appLog("Error in getVotedForUid: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>> toggleBattleLike(String battleId, String userUid) async {
    try {
      final existing = await _client
          .from('battle_likes')
          .select()
          .eq('user_uid', userUid)
          .eq('battle_id', battleId)
          .maybeSingle();

      bool isLiked;
      int delta;
      if (existing != null) {
        await _client.from('battle_likes').delete().eq('user_uid', userUid).eq('battle_id', battleId);
        isLiked = false;
        delta = -1;
      } else {
        await _client.from('battle_likes').insert({'user_uid': userUid, 'battle_id': battleId});
        isLiked = true;
        delta = 1;
      }

      final battleResponse = await _client.from('battles').select('likes').eq('id', battleId).single();
      final newLikes = (battleResponse['likes'] as int? ?? 0) + delta;

      await _client.from('battles').update({'likes': newLikes}).eq('id', battleId);

      return {'isLikedByMe': isLiked, 'likes': newLikes};
    } catch (e) {
      appLog("Error in toggleBattleLike: $e");
      rethrow;
    }
  }

  Future<bool> checkBattleIsLiked(String battleId, String userUid) async {
    if (userUid == 'guest') {
      return false;
    }
    try {
      final response = await _client
          .from('battle_likes')
          .select()
          .eq('user_uid', userUid)
          .eq('battle_id', battleId)
          .maybeSingle();
      return response != null;
    } catch (e) {
      appLog("Error in checkBattleIsLiked: $e");
      return false;
    }
  }

  Future<List<Comment>> getBattleComments(String battleId) async {
    try {
      final response = await _client
          .from('battle_comments')
          .select()
          .eq('battle_id', battleId)
          .order('timestamp', ascending: false);

      final List<dynamic> list = response as List<dynamic>;
      return list
          .map(
            (c) => Comment(
              id: c['id'] as String,
              username: c['username'] as String,
              avatarUrl: c['avatar_url'] as String? ?? defaultAvatarUrl,
              commentText: c['comment_text'] as String,
              timestamp: DateTime.parse(c['timestamp'] as String),
            ),
          )
          .toList();
    } catch (e) {
      appLog("Error in getBattleComments: $e");
      rethrow;
    }
  }

  Future<void> addBattleComment(String battleId, Comment comment) async {
    try {
      await _client.from('battle_comments').insert({
        'id': comment.id,
        'battle_id': battleId,
        'username': comment.username,
        'avatar_url': comment.avatarUrl,
        'comment_text': comment.commentText,
        'timestamp': comment.timestamp.toIso8601String(),
      });

      final battleResponse = await _client.from('battles').select('comments_count').eq('id', battleId).single();
      final currentComments = (battleResponse['comments_count'] as int? ?? 0) + 1;
      await _client.from('battles').update({'comments_count': currentComments}).eq('id', battleId);
    } catch (e) {
      appLog("Error in addBattleComment: $e");
      rethrow;
    }
  }
}
