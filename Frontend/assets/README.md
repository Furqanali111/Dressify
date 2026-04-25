# Dressify Assets

Drop brand assets into the right folder. The Flutter `pubspec.yaml` already
declares all four directories — anything you put here is available to the app
after a `flutter pub get` + hot restart.

## Folder map

| Folder | What goes here | Format |
|---|---|---|
| `logo/` | Wordmark, app icon (foreground + background), splash logo | SVG preferred; PNG @1x/@2x/@3x for raster |
| `icons/` | Custom UI icons (only if Material Symbols can't cover it) | SVG |
| `avatars/` | The 3–5 predefined avatar silhouettes | SVG (preferred — scales for any density) |
| `images/` | Onboarding illustrations, empty-state art, marketing images | SVG / PNG |

## Naming conventions

- All lowercase, words separated by `_`
- Suffix raster variants with `@2x` / `@3x`:
  - `images/empty_wardrobe.png`
  - `images/empty_wardrobe@2x.png`
  - `images/empty_wardrobe@3x.png`
- Avatars: `avatar_<name>.svg` — e.g. `avatar_slim.svg`, `avatar_athletic.svg`,
  `avatar_average.svg`, `avatar_curvy.svg`, `avatar_plus.svg`

## How to use in code

```dart
// SVG
import 'package:flutter_svg/flutter_svg.dart';
SvgPicture.asset('assets/logo/dressify_wordmark.svg')

// Raster
Image.asset('assets/images/onboarding_1.png')
```

## After adding/removing files

```powershell
flutter pub get      # only needed if you changed pubspec.yaml
# Hot restart inside the running app (press R in terminal, or Shift+R in IDE)
```

> **Note:** if Flutter complains about an empty asset folder, add a `.gitkeep`
> file inside it. The placeholders here exist for that reason.
