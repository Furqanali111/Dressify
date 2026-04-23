namespace Dressify.Core
{
    /// <summary>
    /// All user-facing strings in one place.
    /// Replace values with a proper l10n system in a future phase.
    /// </summary>
    public static class Strings
    {
        // ── App ──────────────────────────────────────────────────────────────────
        public const string AppName    = "Dressify";
        public const string Tagline    = "Your wardrobe. Reimagined.";

        // ── Onboarding ────────────────────────────────────────────────────────────
        public const string Onboard1Title = "Upload any clothing";
        public const string Onboard1Desc  = "Snap or pick any clothing item from your gallery.";
        public const string Onboard2Title = "See it on you instantly";
        public const string Onboard2Desc  = "Our 2D engine overlays your outfit on your avatar in seconds.";
        public const string Onboard3Title = "Get AI styling advice";
        public const string Onboard3Desc  = "Your personal AI stylist rates every outfit and gives tips.";
        public const string GetStarted    = "Get Started";
        public const string Skip          = "Skip";

        // ── Auth ─────────────────────────────────────────────────────────────────
        public const string WelcomeTitle    = "Welcome to Dressify";
        public const string WelcomeSubtitle = "Sign in to save your outfits and style profile";
        public const string SignInWithGoogle = "Sign in with Google";
        public const string SignInLoading    = "Signing in…";
        public const string SignInError      = "Sign-in failed. Please try again.";
        public const string TermsText        = "By continuing, you agree to our Terms & Privacy Policy";

        // ── Profile Setup ────────────────────────────────────────────────────────
        public const string ProfileTitle    = "Tell us about yourself";
        public const string ProfileSubtitle = "This helps us fit clothing more accurately";
        public const string LabelName       = "Name";
        public const string PlaceholderName = "Your name";
        public const string LabelHeight     = "Height";
        public const string LabelWeight     = "Weight";
        public const string LabelBodyType   = "Body Type";
        public const string Continue        = "Continue";
        public const string SkipForNow      = "Skip for now";
        public const string ErrorHeightRange = "Height must be between 100–250 cm or 3'3\"–8'2\"";
        public const string ErrorWeightRange = "Weight must be between 30–300 kg or 66–660 lbs";

        // ── Avatar Selection ─────────────────────────────────────────────────────
        public const string ChooseAvatar    = "Choose Your Avatar";
        public const string AvatarSubtitle  = "Pick the avatar closest to your body shape";
        public const string UseThisAvatar   = "Use This Avatar";

        // ── Home ─────────────────────────────────────────────────────────────────
        public const string Greeting         = "Hello, {0} 👋";
        public const string QuickNewOutfit   = "New Outfit";
        public const string QuickWardrobe    = "My Wardrobe";
        public const string QuickSavedLooks  = "Saved Looks";
        public const string QuickStyleTips   = "Style Tips";
        public const string RecentOutfits    = "Recent Outfits";
        public const string SeeAll           = "See All";
        public const string EmptyWardrobeMsg = "No outfits yet.\nUpload your first clothing item!";
        public const string EmptyWardrobeCTA = "Get Started";

        // ── Upload ───────────────────────────────────────────────────────────────
        public const string UploadPrompt     = "Tap to upload or drag here";
        public const string UploadSubtext    = "Supports JPG, PNG up to 10MB";
        public const string ChangeImage      = "Change Image";
        public const string TopDetected      = "Top detected ✓";
        public const string BottomDetected   = "Bottom detected ✓";
        public const string UncertainDetect  = "Uncertain — please confirm";
        public const string RemoveBackground = "Remove Background";
        public const string BackgroundRemoved = "Background removed";
        public const string TryOn            = "Try On";
        public const string SaveToWardrobe   = "Save to Wardrobe";
        public const string UploadError      = "Processing failed. Please try a clearer image.";
        public const string Retry            = "Retry";
        public const string Cancel           = "Cancel";
        public const string RemovingBg       = "Removing background…";

        // ── Try-On ───────────────────────────────────────────────────────────────
        public const string FittingYourLook  = "Fitting your look…";
        public const string AutoFitWarning   = "Auto-fit may need adjustment — drag to reposition";
        public const string GetAiFeedback    = "Get AI Feedback";
        public const string SaveOutfit       = "Save Outfit";
        public const string OutfitSaved      = "Saved ✓";

        // ── AI Feedback ──────────────────────────────────────────────────────────
        public const string StyleReport          = "Your Style Report";
        public const string RegenerateFeedback   = "Regenerate Feedback";
        public const string SaveOutfitPlusFeedback = "Save Outfit + Feedback";
        public const string Close                = "Close";
        public const string FeedbackError        = "Feedback unavailable. Try again.";

        // ── Wardrobe ─────────────────────────────────────────────────────────────
        public const string TabClothingItems  = "Clothing Items";
        public const string TabSavedOutfits   = "Saved Outfits";
        public const string FilterAll         = "All";
        public const string FilterTops        = "Tops";
        public const string FilterBottoms     = "Bottoms";
        public const string FilterDresses     = "Dresses";
        public const string FilterJackets     = "Jackets";
        public const string CtxTryOn          = "Try On";
        public const string CtxRename         = "Rename";
        public const string CtxDelete         = "Delete";
        public const string CtxView           = "View";
        public const string CtxShare          = "Share";

        // ── Profile ───────────────────────────────────────────────────────────────
        public const string EditProfile      = "Edit Profile";
        public const string SignOut          = "Sign Out";
        public const string SignOutConfirmTitle = "Sign out of Dressify?";
        public const string SignOutConfirmMsg   = "Your saved outfits will remain.";

        // ── Generic ──────────────────────────────────────────────────────────────
        public const string Loading    = "Loading…";
        public const string Error      = "Something went wrong.";
        public const string ComingSoon = "Coming soon";
    }
}
