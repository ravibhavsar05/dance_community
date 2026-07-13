import 'package:get/get.dart';

class BattleArenaStrings {
  // Durations
  static const int spinDurationSeconds = 5;
  static const int prepCountdownSeconds = 5;
  static const int danceTurnDurationSeconds = 30;

  // Strings
  static const String battleStage = "BATTLE STAGE";
  static const String liveDanceOff = "DANCE OFF LIVE";
  static const String prepMode = "PREPARATION MODE";
  static const String spinningBottle = "SPINNING THE BOTTLE";
  static const String youDanceFirst = "YOU DANCE FIRST!";
  static const String you = "YOU";
  static const String getReadyTurn1 = "GET READY: TURN 1";
  static const String getReadyTurn2 = "GET READY: TURN 2";
  static const String yourTurn = "YOUR TURN (PERFORMING)";
  static const String connectingToOpponentCamera = "Connecting to opponent's live camera...";
  static const String recordingComplete = "RECORDING COMPLETE!";
  static const String ffmpegProcessing = "FFmpeg is processing and combining both dance recordings side-by-side...";
  static const String waitingForHostTranscode = "Waiting for host to transcode and upload the combined battle...";
  static const String battleComplete = "BATTLE COMPLETE!";
  static const String battleCompleteDescription =
      "Both performances have been stitched and uploaded to your profiles. Followers can now vote on this battle for the next 48 hours!";
  static const String exitArena = "EXIT ARENA";
  static const String exitArenaTitle = "Exit Arena?";
  static const String exitArenaContent =
      "Exiting the room now will forfeit the match and count as a loss. Are you sure you want to exit?";
  static const String cancel = "CANCEL";
  static const String forfeitAndExit = "FORFEIT & EXIT";

  // Dynamic strings
  static String opponentTurn(String name) => "${name.toUpperCase()}'S TURN";
  static String opponentDanceFirst(String name) => "${name.toUpperCase()} DANCES FIRST!";
}

class BattleMatchingStrings {
  // Durations
  static const int searchDurationSeconds = 30;

  // Strings
  static const String searchingForDancers = "SEARCHING FOR DANCERS";
  static const String opponentMatched = "OPPONENT MATCHED!";
  static const String noMatchFound = "NO MATCH FOUND";
  static const String cancelled = "CANCELLED";
  static const String battleArena = "BATTLE ARENA";
  static const String matchmakingSubtitle = "Real-time 1v1 Dance Matchmaking";
  static const String secondsLeft = "SECONDS LEFT";
  static const String ready = "READY";
  static const String vs = "VS";
  static const String matching = "Matching...";
  static const String retryMatchmaking = "RETRY MATCHMAKING";
  static const String cancelSearch = "CANCEL SEARCH";
  static const String matchmakingError = "Matchmaking Error";
  static const String failedToJoinQueue = "Failed to join matchmaking queue: ";
  static const String dancer = "dancer";
}

class LoginStrings {
  static const String verifyYourEmail = "Verify Your Email";
  static const String verifyEmailMessagePrefix = "Registration successful! A verification link has been sent to ";
  static const String verifyEmailMessageSuffix = ". Please verify your email before signing in.";
  static const String ok = "OK";
  static const String authFailed = "Authentication failed. Please check your credentials.";
  static const String appTitle = "DANCE PULSE";
  static const String appSubtitle = "Join the beat of the global dance stage";
  static const String fullName = "Full Name";
  static const String enterNameError = "Please enter your name";
  static const String emailAddress = "Email Address";
  static const String enterEmailError = "Please enter a valid email";
  static const String password = "Password";
  static const String passwordLengthError = "Password must be at least 6 characters";
  static const String createAccount = "Create Account";
  static const String signIn = "Sign In";
  static const String signUp = "Sign Up";
  static const String or = "OR";
  static const String alreadyHaveAccount = "Already have an account? ";
  static const String newToApp = "New to Dance Pulse? ";
}

class DiscoveryStrings {
  static const String discover = "DISCOVER";
  static const String searchPlaceholder = "Search dancers, styles, challenges...";
  static const String matchingDancers = "Matching Dancers";
  static const String followed = "Followed";
  static const String follow = "Follow";
  static const String you = "You";
  static const String searchResults = "Search Results";
  static const String trendingClips = "Trending Clips";
  static const String noClipsFound = "No dance clips found. Be the first to upload!";

  static String popularClips(String style) => "Popular $style Clips";
}

class HomeFeedStrings {
  static const String noClipsFound = "No dance clips found. Be the first to upload!";
  static const String loadingComments = "Loading comments...";
  static const String noCommentsYet = "No comments yet. Start the conversation!";
  static const String addComment = "Add comment...";
  static const String videoFailedToLoad = "Video failed to load";
  static const String linkCopied = "Link copied! Share with your crew.";

  static String commentsCountText(int count) => "$count comments";
}

class MessagesStrings {
  static const String inbox = "INBOX";
  static const String signInPrompt = "Please sign in to view messages";
  static const String noMessagesYet = "No messages yet";
  static const String startConversation = "Tap to start conversation";
  static const String conversationNotFound = "Conversation not found";
  static const String online = "Online";
  static const String typeMessage = "Type message...";

  static String isTyping(String name) => "$name is typing";
}

class NavigationStrings {
  static const String chooseAction = "CHOOSE AN ACTION";
  static const String createPost = "Create Post";
  static const String createPostDesc = "Share your dance clips with followers";
  static const String permissionsRequired = "Permissions Required";
  static const String permissionsRequiredDesc =
      "Camera and microphone permissions are required to enter the Battle Arena.";
  static const String uploadingPost = "Uploading Post...";
  static const String uploadFailed = "Upload Failed (Tap to Retry)";
  static const String uploadSuccessful = "Upload Successful";
  static const String waitingInQueue = "Waiting in queue...";
  static const String slideToBattle = "SLIDE TO BATTLE";

  static String morePostsInQueue(int count) => "+ $count more post(s) in queue";
}

class ProfileStrings {
  static const String editProfileDetails = "Edit Profile Details";
  static const String displayName = "Display Name";
  static const String danceBio = "Dance Bio";
  static const String cancel = "Cancel";
  static const String saveChanges = "Save Changes";
  static const String profileNotFound = "Dancer profile not found.";
  static const String profilePictureUpdated = "Profile picture updated successfully! 🎉";
  static const String profilePictureUpdateFailed = "Failed to update profile picture. ❌";
  static const String followToViewMetrics = "Follow to view metrics";
  static const String editPortfolioBio = "Edit Portfolio Bio";
  static const String unfollowDancer = "UNFOLLOW DANCER";
  static const String followDancer = "FOLLOW DANCER";
  static const String privateProfile = "PRIVATE PROFILE";
  static const String privateProfileDesc =
      "Clips and performed 1v1 battles of this dancer are hidden. Follow them to see their full profile feed!";
  static const String noClips = "No dance clips uploaded yet.";
  static const String noLikedClips = "No liked clips yet.";
  static const String noBattles = "No battles fought yet.";
  static const String logoutConfirmTitle = "Logout?";
  static const String logoutConfirmContent = "Are you sure you want to log out of your account?";
  static const String logoutConfirmButton = "LOGOUT";
}

class BattleVoteCardStrings {
  static const String votingCompleted = "VOTING COMPLETED";
  static const String showdownHeader = "1V1 BATTLE SHOWDOWN";
  static const String videoUnavailable = "Combined video unavailable";
  static const String vs = "VS";
  static const String winnerForfeit = "WINNER (FORFEIT)";
  static const String loserForfeit = "LOSER (LEFT EARLY)";
  static const String dragTokenPrompt = "DRAG TOKEN ONTO A DANCER TO VOTE";
  static const String voteHere = "VOTE HERE";
  static const String followToVote = "FOLLOW EITHER DANCER TO CAST A VOTE!";
  static const String participantsCannotVote = "PARTICIPANTS CANNOT VOTE IN THEIR OWN BATTLES";
  static const String voteSuccess = "Vote casted successfully! 🔥 Dancers thank you.";

  static String votingEndsIn(int h, int m, int s) => "Voting Ends in: ${h}h ${m}m ${s}s";
  static String votesPercentage(int votes, String percent) => "$votes votes ($percent%)";
  static String tiePercent(String percent) => "TIE ($percent%)";
  static String winnerPercent(String percent) => "WINNER ($percent%)";
  static String loserPercent(String percent) => "LOSER ($percent%)";
}

class CreatePostStrings {
  static const String selectVideo = "Select Performance Video";
  static const String selectImage = "Select Post Image";
  static const String chooseFromGallery = "Tap to choose from device gallery";
  static const String selectRatioVideo = "Not Cropped (Tap to Crop)";
  static const String selectRatioImage = "Tap to Crop Image";
  static const String photoFilter = "Apply Photo Filter";
  static const String videoFilter = "Apply Video Filter";
  static const String adjustImageBrightness = "Adjust Image Brightness";
  static const String adjustVideoBrightness = "Adjust Video Brightness";
  static const String trimVideoTitle = "Trim Video (Start & End)";
  static const String captionTitle = "Caption";
  static const String captionHint = "Drop your caption here... add style tags like #Shuffle #HipHop!";
  static const String selectMusic = "Select Beat / Music";
  static const String selectCategory = "Dance Category / Style";
  static const String shareWithCommunity = "Share with Community";
  static const String cropConfirm = "Crop & Confirm";
  static const String selectAspectPrompt = "Select aspect ratio and align your preview frame:";
  static const String writeCaptionError = "Please write a caption for your dance clip!";
  static const String selectMediaError = "Please select a media file (video or image) first!";
  static const String postAddedToQueue = "Post added to upload queue! 📤";
  static const String createPostHeader = "CREATE POST";
  static const String mediaPipelineActive = "Media Pipeline Active";
  static const String videoPost = "Video Post";
  static const String imagePost = "Image Post";
  static const String cancel = "Cancel";

  static String cropTitle(String type) => "Crop ${type.capitalizeFirst}";
  static String croppedRatio(String ratio) => "Cropped: $ratio";
  static String ratioTitle(String ratio) => "Ratio: $ratio";
}
