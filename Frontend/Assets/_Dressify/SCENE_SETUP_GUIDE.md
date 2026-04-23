# Dressify — Scene Setup Guide

This document tells you exactly how to assemble each Unity scene from the C# scripts.

---

## Prerequisites

1. Open Unity Hub → Open Project → `d:\Project\Dressify\Frontend\`
2. Unity version: **2022.3 LTS** or later
3. Install **TextMeshPro** (Window → Package Manager → TextMeshPro Essential Resources)
4. *(Optional)* Import Firebase Auth + Google Sign-In `.unitypackage` files
5. Set Game view preset to **1080×2340** or **"iPhone 14 Pro Max"**

---

## Global Setup (Do Once)

### Persistent Manager Scene
Create a scene called `_Managers` and set it as the first scene in Build Settings.

**Hierarchy:**
```
_Managers (Scene)
└── [GameObject] "AppRoot"
    ├── AppManager       (script: Dressify.Core.AppManager)
    ├── NavigationManager (script: Dressify.Core.NavigationManager)
    ├── AuthService       (script: Dressify.Services.AuthService)
    ├── ApiService        (script: Dressify.Services.ApiService)
    └── SecureStorageService (script: Dressify.Services.SecureStorageService)

└── [GameObject] "UIRoot" (Canvas — Screen Space Overlay, sort order 100)
    └── Toast             (script: Dressify.Components.Toast)
        ├── Scrim: Image (full-screen transparent)
        └── ToastPanel: RectTransform (anchored bottom-center)
            ├── LeftBorder: Image (4dp wide)
            └── MessageLabel: TextMeshProUGUI
```

**Load `_Managers` additively, never unload it.**

---

## Scene 1: Splash (scene name: `Splash`)

**Hierarchy:**
```
Canvas (Screen Space Overlay)
├── Background: Image — fill screen, gradient sprite (primary→lavender)
└── LogoGroup (CanvasGroup)
    ├── LogoRect (RectTransform, center-anchored)
    │   ├── LogoImage: Image (Dressify logo sprite, 200×200dp)
    │   └── WordmarkLabel: TextMeshProUGUI "Dressify" 28sp bold white
    ├── TaglineLabel: TextMeshProUGUI "Your wardrobe. Reimagined." 18sp white 80% alpha
    └── SpinnerGo: Image (24dp circle spinner sprite, hidden by default)

[GameObject] "SplashController" → script: Dressify.Screens.SplashScreen
  Inspector: LogoGroup, LogoRect, TaglineLabel, SpinnerGo
```

---

## Scene 2: Onboarding (scene name: `Onboarding`)

```
Canvas
├── SlideContainer (RectTransform, width = 3240dp, anchored left)
│   ├── Slide0: RectTransform (1080dp wide)
│   │   ├── Illustration0: Image (camera+shirt icon)
│   │   ├── Title0: TextMeshProUGUI
│   │   └── Desc0: TextMeshProUGUI
│   ├── Slide1 / Slide2 (same structure)
├── DotsRow (HorizontalLayoutGroup, 3 dot Images)
├── SkipButton: Button (top-right)
├── NextButton: Button (bottom-right)
└── GetStartedButton: PrimaryButton (full-width, bottom, hidden initially)

[GameObject] "OnboardingController" → Dressify.Screens.OnboardingCarousel
```

---

## Scene 3: SignIn (scene name: `SignIn`)

```
Canvas
├── TopIllustration: Image (fill top 40%)
└── BottomCard: Image (white, 20dp radius, bottom 60%)
    ├── TitleLabel: TextMeshProUGUI "Welcome to Dressify" 24sp bold
    ├── SubtitleLabel: TextMeshProUGUI 15sp secondary color
    ├── ErrorBanner: GameObject (red, hidden)
    │   └── ErrorLabel: TextMeshProUGUI
    ├── SignInButton: PrimaryButton (full width, Google branding)
    └── TermsLabel: TextMeshProUGUI 12sp

[GameObject] "SignInController" → Dressify.Screens.SignInScreen
```

---

## Scene 4: ProfileSetup (scene name: `ProfileSetup`)

```
Canvas
├── StepLabel: TextMeshProUGUI "Step 1 of 2"
├── TitleLabel / SubtitleLabel
├── ScrollView → VerticalLayoutGroup
│   ├── NameField:   DressifyInputField component
│   ├── HeightRow:   DressifyInputField + UnitToggle + HeightUnitLabel
│   ├── WeightRow:   DressifyInputField + UnitToggle + WeightUnitLabel
│   └── BodyTypeRow: ChipGroup component (5 options)
├── ContinueButton: PrimaryButton
└── SkipLink: Button

[GameObject] "ProfileSetupController" → Dressify.Screens.ProfileSetupScreen
```

---

## Scene 5: AvatarSelection (scene name: `AvatarSelection`)

```
Canvas
├── TopBar: BackButton + TitleLabel "Choose Your Avatar"
├── SubtitleLabel
├── ScrollRect (horizontal)
│   └── CardContainer: HorizontalLayoutGroup
│       └── [5× AvatarCardPrefab] (140×240dp)
│           ├── AvatarImage: Image (avatar illustration sprite)
│           ├── NameLabel: TextMeshProUGUI
│           ├── Border: Image (outline, primary color, hidden by default)
│           ├── CheckBadge: Image (circle + checkmark, top-right, hidden by default)
│           └── Button: Button component (on the root)
└── UseAvatarButton: PrimaryButton (fixed bottom)

[GameObject] "AvatarSelectionController" → Dressify.Screens.AvatarSelectionScreen
```

---

## Scene 6: Home (scene name: `Home`)

```
Canvas
├── TopBar
│   ├── LogoSmall: Image
│   ├── GreetingLabel: TextMeshProUGUI
│   └── AvatarThumb: Image (40dp circle)
├── QuickActionsRow (HorizontalLayoutGroup, 4 children)
│   └── [4× QuickActionCard] (80×80dp): Image + IconImage + LabelText + Button
├── RecentSection
│   ├── SectionHeader: "Recent Outfits" + SeeAllButton
│   ├── RecentScroll: ScrollRect (horizontal)
│   │   └── RecentContainer: HorizontalLayoutGroup
│   │       └── [OutfitCardPrefab] 140×180dp
│   └── EmptyState: GameObject
│       ├── EmptyIllustration: Image
│       ├── EmptyLabel: TextMeshProUGUI
│       └── EmptyCTA: PrimaryButton
├── Skeleton: LoadingSkeleton component
└── BottomNavBar: BottomNavBar component

[GameObject] "HomeController" → Dressify.Screens.HomeScreen
```

---

## Scene 7: Upload (scene name: `Upload`)

```
Canvas
├── BackButton
├── UploadArea (RectTransform, dashed border via sprite, top 55%)
│   ├── UploadPromptGroup (idle state)
│   │   ├── UploadIcon: Image 48dp
│   │   ├── UploadPromptLabel: TextMeshProUGUI
│   │   └── UploadSubtextLabel: TextMeshProUGUI
│   ├── PreviewImage: RawImage (fills area, hidden initially)
│   └── ChangeImageBtn: Button (hidden initially)
├── DetectionBadge: Image + TextMeshProUGUI (pill, hidden initially)
├── ManualSelectGroup: TMP_Dropdown (hidden unless uncertain)
├── RemoveBgButton: PrimaryButton
├── ProgressGroup: GameObject
│   ├── ProgressBar: ProgressBar component
│   └── CancelButton: Button
├── SuccessActions: GameObject (hidden until success)
│   ├── TryOnButton: PrimaryButton
│   └── SaveToWardrobeButton: SecondaryButton
├── ErrorBanner: GameObject
│   ├── ErrorLabel: TextMeshProUGUI
│   └── RetryButton: Button
└── SourcePickerSheet: BottomSheet component
    ├── CameraButton: Button
    └── GalleryButton: Button

[GameObject] "UploadController" → Dressify.Screens.ClothingUploadScreen
```

---

## Scene 8: TryOnPreview (scene name: `TryOnPreview`)

```
Canvas
├── BackButton
├── PreviewCanvas (top 65%): Panel
│   ├── AvatarImage: Image (avatar illustration)
│   ├── ClothingOverlay: RectTransform
│   │   └── ClothingImage: RawImage
│   ├── OverlayControls (vertical IconButton stack, bottom-right)
│   │   ├── ZoomInBtn / ZoomOutBtn / ResetBtn / ToggleAvatarBtn: IconButton
│   └── LowConfidenceBanner: Image+TextMeshProUGUI (yellow, hidden by default)
├── Skeleton: LoadingSkeleton
└── BottomPanel (bottom 35%): ScrollRect
    ├── ClothingNameLabel / ClothingTypeLabel: TextMeshProUGUI
    ├── GetFeedbackBtn: SecondaryButton (sparkle icon)
    └── SaveOutfitBtn: PrimaryButton (bookmark icon)

└── AiFeedbackSheet: GameObject with AiFeedbackSheet + BottomSheet components
    ├── Scrim: Image (full-screen overlay)
    ├── SheetPanel: RectTransform
    │   ├── DragHandle: Image (40×4dp, gray)
    │   ├── SheetTitle: TextMeshProUGUI "Your Style Report"
    │   ├── RatingArc: RatingArc component
    │   ├── VerdictLabel: TextMeshProUGUI
    │   ├── SuggestionScroll: ScrollRect → SuggestionContainer: VerticalLayoutGroup
    │   │   └── [SuggestionCardPrefab]: Image card + CategoryLabel + SuggestionText
    │   ├── RegenerateButton: Button
    │   ├── SaveAndFeedbackButton: PrimaryButton
    │   └── CloseButton: Button

[GameObject] "TryOnController" → Dressify.Screens.TryOnPreviewScreen
[GameObject] "FeedbackSheetController" → Dressify.Screens.AiFeedbackSheet
```

---

## Scene 9: Wardrobe (scene name: `Wardrobe`)

```
Canvas
├── TabRow: HorizontalLayoutGroup
│   ├── ClothingTabBtn + ClothingTabLine: Image (underline indicator)
│   └── SavedTabBtn + SavedTabLine: Image
├── ClothingPanel: GameObject
│   ├── FilterChips: ChipGroup component
│   └── ClothingScroll → ClothingGrid: GridLayoutGroup (2 cols, 160dp cells)
│       └── [ClothingCardPrefab]
├── SavedPanel: GameObject
│   └── SavedScroll → SavedGrid: GridLayoutGroup (2 cols)
│       └── [OutfitCardPrefab]
├── EmptyClothing / EmptySaved: GameObjects
├── Skeleton: LoadingSkeleton
├── FAB: IconButton (56dp, primary, bottom-right, "+" icon)
└── ContextMenu: GameObject (popup)
    ├── CtxTryOn / CtxRename / CtxDelete: Buttons
    └── BottomNavBar: BottomNavBar component

[GameObject] "WardrobeController" → Dressify.Screens.WardrobeScreen
```

---

## Scene 10: Profile (scene name: `Profile`)

```
Canvas
├── ProfileHeader: VerticalLayoutGroup
│   ├── AvatarCircle: Image (80dp circle)
│   ├── UserNameLabel: TextMeshProUGUI 20sp bold
│   └── EditProfileBtn: Button
├── StatsCard: DressifyCard component
│   ├── HeightPill / WeightPill / BodyTypePill: TextMeshProUGUI
│   └── EditStatsBtn: Button
├── SettingsList: VerticalLayoutGroup
│   ├── UnitRow: Label + Toggle
│   ├── NotifRow: Label + Toggle
│   ├── ThemeRow: Label + TMP_Dropdown
│   ├── PrivacyPolicyBtn, TermsBtn: Buttons
│   ├── AppVersionLabel: TextMeshProUGUI
│   └── SignOutBtn: Button (red text)
├── ConfirmDialog: GameObject (modal) — hidden by default
│   ├── DialogCard (centered): Image
│   │   ├── TitleLabel / MessageLabel: TextMeshProUGUI
│   │   ├── ConfirmCancelBtn / ConfirmSignOutBtn: Buttons
└── BottomNavBar: BottomNavBar component

[GameObject] "ProfileController" → Dressify.Screens.ProfileScreen
```

---

## Build Settings Order

Add scenes in this order (**File → Build Settings → Add Open Scenes**):

| Index | Scene           |
|-------|-----------------|
| 0     | Splash          |
| 1     | Onboarding      |
| 2     | SignIn          |
| 3     | ProfileSetup    |
| 4     | AvatarSelection |
| 5     | Home            |
| 6     | Upload          |
| 7     | TryOnPreview    |
| 8     | Wardrobe        |
| 9     | Profile         |

---

## DressifyTheme ScriptableObject

1. `Assets > Create > Dressify > Design System`
2. Save as `Assets/_Dressify/ScriptableObjects/DressifyTheme.asset`
3. Move it to `Assets/Resources/DressifyTheme.asset` so `Resources.Load<>()` can find it.

---

## Backend URL

In the Unity Inspector, select the **ApiService** GameObject and set:
- **Base Url**: `http://localhost:8000` (dev) or your deployed URL

---

## Tips

- Use **Canvas Scaler** → Scale with Screen Size → Reference (1080×2340) → Match = 0.5
- Use **Safe Area** script for notch/punch-hole handling on Android/iOS
- Use **Sprite Atlas** for all UI sprites to reduce draw calls
