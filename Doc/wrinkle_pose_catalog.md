# Wrinkle Pose Catalog

8 canonical poses used to pre-bake wrinkle maps at garment upload time.
At runtime, `PoseClassifier` (S4.2.2) maps live landmarks to the nearest pose label.

---

## Pose Definitions

| Pose Label | Shoulder Angle | Elbow Angle | Torso Lean | Primary Wrinkle Zone |
|------------|---------------|-------------|------------|----------------------|
| `arms_down` | ~0° from body | ~10° | neutral | Chest horizontal fold, gentle sides |
| `arms_45` | ~45° abducted | ~20° | neutral | Axilla diagonal, sleeve seam |
| `arms_90` | ~90° abducted | ~15° | neutral | Strong underarm, horizontal chest tension |
| `lean_left_15` | ~0° | ~10° | 15° left | Right side compression, left side tension |
| `lean_right_15` | ~0° | ~10° | 15° right | Left side compression, right side tension |
| `seated` | ~0° | ~10° | neutral | Waist/hip compression (strong horizontal) |
| `one_arm_raised` | L=~120°, R=~0° | L=~15° | neutral | Left shoulder/axilla strong, diagonal pull |
| `crossed_arms` | ~30° forward | ~120° crossed | neutral | Strong horizontal chest, bilateral bunching |

---

## Angle Measurement Convention

- **Shoulder angle**: degrees of abduction from resting (arms at sides = 0°)
- **Elbow angle**: degrees of flexion from straight (0° = fully extended)
- **Torso lean**: degrees from vertical, positive = lean left

---

## Runtime Pose Classification (S4.2.2)

Landmark inputs used by `PoseClassifier`:
- `left_shoulder`, `right_shoulder` (x, y normalized)
- `left_elbow`, `right_elbow`
- `left_wrist`, `right_wrist`
- `left_hip`, `right_hip`

Classification steps:
1. Compute shoulder midpoint; torso lean = atan2(Δy_shoulders, Δx_shoulders) in degrees
2. Compute left/right shoulder abduction from shoulder→hip vector vs shoulder→wrist vector
3. Compute elbow flexion from elbow angle (shoulder–elbow–wrist)
4. Map to nearest pose via weighted distance in (shoulder_abduction_l, shoulder_abduction_r, torso_lean) space:

```
arms_down       → (0°, 0°, 0°)
arms_45         → (45°, 45°, 0°)
arms_90         → (90°, 90°, 0°)
lean_left_15    → (0°, 0°, -15°)
lean_right_15   → (0°, 0°, +15°)
seated          → (0°, 0°, 0°)  [detected via hip-knee angle < 120°]
one_arm_raised  → (120°, 0°, 0°)
crossed_arms    → (30°, 30°, 0°)  [detected via wrist crossing midline]
```

---

## Wrinkle Map Format

- **Size**: 128 × 192 pixels (portrait)
- **Mode**: Greyscale (`L`) PNG
- **Encoding**: Brighter = stronger fold/shadow; 0 = no wrinkle, 255 = deep fold
- **Storage**: `wrinkle/{user_id}/{item_id}/{pose}.png` in the clothing bucket
- **Compositing**: `BlendMode.multiply` at 35% opacity over warped garment (S4.2.3)
- **Per garment**: 8 maps × ~8 KB ≈ 64 KB extra storage
