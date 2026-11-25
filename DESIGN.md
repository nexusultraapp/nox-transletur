# NOXIR Play — Design System (`DESIGN.md`)

> **Visual Reference:** Linear-inspired dark desktop software craft (adapted from `awesome-design-md/linear.app` philosophy for NOXIR Play's own identity).
> **Scope:** Windows Desktop App (`pc/NoxirPlay.PC` WPF) and companion surfaces.

---

## 1. Design Philosophy

NOXIR Play is a precision real-time PS5 Remote Play & AI subtitle translation utility. Its interface follows a **quietly luxurious, engineering-grade dark aesthetic**:

- **Surface Ladder over Heavy Shadows:** Visual hierarchy is communicated through a disciplined 4-step charcoal surface ladder and crisp 1px hairline borders — never through heavy drop shadows or noisy atmospheric glows.
- **Restrained Chromatic Accent:** A single calm **Indigo-Blue (`#5E6AD2`)** accent marks primary actions, keyboard focus rings, and brand highlights. Secondary controls remain neutral charcoal so primary actions stand out effortlessly.
- **Compact & Scannable Density:** Tight, balanced padding, consistent 8px/12px corner geometry, and clear ink contrast (`#F7F8F8` → `#D0D6E0` → `#8A8F98` → `#62666D`) keep complex settings effortless to scan.
- **Restrained Micro-Interactions:** Subtle border brightening, surface-step lifts, and crisp 0.985 press feedback without distracting animations.
- **Zero-Regression Structure:** Existing views, navigation flows, control names, and features are preserved intact.

---

## 2. Color Tokens

### Surface Ladder (Near-Black & Charcoal)
| Token | Hex | Role |
|---|---|---|
| `CanvasBrush` | `#08090A` | Primary application window & full-screen view canvas |
| `Surface1Brush` (`PanelBrush`) | `#0F1012` | Primary content cards, form containers, elevated panels |
| `Surface2Brush` | `#141518` | Secondary buttons, nested status tiles, hovered cards |
| `Surface3Brush` | `#191B1F` | Hover states, dropdown popups, active navigation pills |
| `Surface4Brush` | `#202228` | Pressed secondary buttons, active toggle surfaces |
| `SubPanelBrush` | `#0B0C0E` | Recessed inner containers, log viewers, code/preview frames |

### Hairline Borders
| Token | Hex | Role |
|---|---|---|
| `HairlineSubtleBrush` (`SubPanelBorderBrush`) | `#1B1D22` | Recessed inner boxes, subtle section dividers |
| `HairlineBrush` (`PanelBorderBrush`) | `#23252A` | Standard 1px card borders, inputs, secondary buttons |
| `HairlineStrongBrush` | `#34363E` | Hovered borders, emphasized dividers |

### Typography Ink
| Token | Hex | Role |
|---|---|---|
| `InkPrimaryBrush` (`TextPrimaryBrush`) | `#F7F8F8` | Page titles, card titles, primary labels |
| `InkSecondaryBrush` (`TextSecondaryBrush`) | `#D0D6E0` | Body copy, descriptions, list items |
| `InkMutedBrush` (`MutedBrush`) | `#8A8F98` | Helper text, subtitles, inactive labels |
| `InkTertiaryBrush` | `#62666D` | Placeholders, footnotes, disabled text |

### Accent & Semantic Colors
| Token | Hex | Role |
|---|---|---|
| `AccentBrush` | `#5E6AD2` | Primary CTA, focus ring, active checkbox/slider |
| `AccentHoverBrush` | `#6E7BF2` | Hovered primary CTA |
| `AccentPressedBrush` | `#525DC2` | Pressed primary CTA |
| `AccentSoftBrush` | `#A5AEF5` | Brand accent wordmark ("Play"), subtle badges, icons |
| `AccentSurfaceBrush` | `#151726` | Highlighted update/changelog surface |
| `AccentBorderBrush` | `#383E75` | Highlighted update/changelog border |
| `SemanticSuccessBrush` | `#27A644` | Active translation, CUDA/GPU ready, success indicators |
| `SemanticWarningBrush` | `#D29922` | Pending / checking status dots |

---

## 3. Typography

- **Primary UI Font:** `Segoe UI` (Windows native crisp rendering with `TextFormattingMode="Display"` and `ClearType`)
- **Monospace Font:** `Consolas, Courier New` (PIN codes, IP addresses, live logs)

| Role | Size | Weight | Color Token |
|---|---|---|---|
| Display / Welcome Headline | `38px` | SemiBold (600) | `InkPrimaryBrush` |
| Page Title | `24px` | SemiBold (600) | `InkPrimaryBrush` |
| Brand Wordmark | `18px` | Bold / SemiBold | `InkPrimaryBrush` + `AccentSoftBrush` |
| Card Title | `15px` | SemiBold (600) | `InkPrimaryBrush` |
| Body / Input | `13.5px–14px` | Regular (400) | `InkSecondaryBrush` |
| Button Label | `13px` | SemiBold (600) | `InkPrimaryBrush` / `#FFFFFF` |
| Field Label | `12px` | SemiBold (600) | `InkSecondaryBrush` |
| Caption / Help / Badge | `11px–12px` | Regular / SemiBold | `InkMutedBrush` |

---

## 4. Shape, Spacing & Elevation

### Border Radius Scale
- **Small badges / tags:** `6px`
- **Buttons, Inputs, ComboBoxes, CheckBoxes:** `8px` (`rounded.md`)
- **Content Cards & Modals:** `12px` (`rounded.lg`)
- **Status Pills:** `12px–14px`

### Spacing Rhythm (4px Base Unit)
- Window outer margin: `36px` horizontal, `28px` vertical
- Header bottom divider padding: `16px`
- Card padding: `18px–20px` (compact, organized density)
- Card vertical gap: `12px–14px`
- Button padding: `14px,8px` (secondary/nav) · `18px,10px` (primary) · `28px,14px` (hero CTA)

### Elevation Rules
- **Level 0 (Canvas):** `#08090A`, flat.
- **Level 1 (Card):** `#0F1012` + `1px #23252A` hairline border. No heavy drop shadow.
- **Level 2 (Lifted Control / Secondary Button):** `#141518` + `1px #23252A` border; hover lifts to `#191B1F` + `#34363E`.
- **Level 3 (Popup / Tooltip / Dropdown):** `#141518` + `1px #34363E` border + tight subtle shadow (`BlurRadius=16, Opacity=0.45`).

---

## 5. Do's & Don'ts

### Do
- Keep `#08090A` charcoal-black as the clean anchor canvas across all views.
- Rely on 1px `#23252A` / `#34363E` hairlines and surface steps for separation.
- Reserve `#5E6AD2` indigo-blue for primary CTAs, active controls, and focus rings.
- Keep button heights, input paddings, and card radii uniform across every screen.

### Don't
- Do not add large glowing background orbs or heavy neon drop shadows behind every card.
- Do not use saturated purple/violet as a full card background.
- Do not mix bubbly `16px–20px` button corners with sharp `4px` inputs.
- Do not alter existing view structure, button positions, or code-behind event bindings.
