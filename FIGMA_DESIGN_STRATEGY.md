# XQ Secure Workspaces iOS — Comprehensive Figma Design Strategy

---

## 1. EXECUTIVE SUMMARY

XQ Secure Workspaces is a premium enterprise iOS security platform that must feel as effortless as Things 3 while enforcing Zero Trust governance invisibly. The core design challenge is this: security is the product's entire reason for existing, yet security must be the last thing the user consciously thinks about.

The design system resolves this paradox through three pillars:

**Ambient Security Signals.** Classification labels, policy indicators, and sync states are always present but never demanding. They sit at small scale in predictable positions so the eye learns to read them without conscious attention — the same way a lock icon in a browser becomes invisible when everything is fine.

**Risk-Proportionate Interruption.** The UI breaks into the user's flow only when an actual decision is required. The visual weight of that interruption is calibrated to the severity of the risk. A low-risk suggestion appears as a quiet inline chip. A policy violation appears as a high-contrast alert card with a spring-animated entry that demands attention without panicking.

**Native iOS Quality at Every Layer.** Every transition, every tap response, every empty state is executed with the precision of Apple's own apps. This is non-negotiable for enterprise trust: if the app feels like a port, it feels like a compromise.

The 18-screen system supports iPhone and iPad, light and dark mode, four classification levels, two role tiers (standard user and enterprise admin), and full WCAG AA accessibility compliance.

---

## 2. VISUAL DESIGN LANGUAGE

### 2.1 Color Palette

#### Brand & Primary

XQ's brand identity requires a color that communicates security, intelligence, and precision without the clichéd "security blue" of legacy enterprise software. The primary palette is built on an indigo-adjacent blue that reads as sophisticated and modern on OLED screens.

| Role | Light Mode Hex | Dark Mode Hex | Usage |
|---|---|---|---|
| Brand Primary | #3D5AFE | #6979F8 | Primary buttons, active tab, key accents |
| Brand Primary Dim | #E8EAFF | #1A1F3C | Primary button hover backgrounds, tinted backgrounds |
| Brand Secondary | #00C6AE | #00DDB9 | Secondary actions, success confirmation tints |

#### Neutrals (Adaptive Grays)

These are the foundational surface, text, and border colors. They shift significantly between light and dark mode to maintain correct contrast ratios.

| Token Name | Light | Dark |
|---|---|---|
| Background Primary | #F2F2F7 | #000000 |
| Background Secondary | #FFFFFF | #1C1C1E |
| Background Tertiary | #F2F2F7 | #2C2C2E |
| Background Grouped | #F2F2F7 | #1C1C1E |
| Background Elevated | #FFFFFF | #2C2C2E |
| Surface Card | #FFFFFF | #1C1C1E |
| Surface Sheet | #F9F9F9 | #2C2C2E |
| Separator | #C6C6C8 | #38383A |
| Separator Opaque | #C6C6C8 | #545458 |

#### Text

| Token Name | Light | Dark |
|---|---|---|
| Text Primary | #000000 | #FFFFFF |
| Text Secondary | #3C3C43 at 60% | #EBEBF5 at 60% |
| Text Tertiary | #3C3C43 at 30% | #EBEBF5 at 30% |
| Text Quaternary | #3C3C43 at 18% | #EBEBF5 at 18% |
| Text Link | #3D5AFE | #6979F8 |
| Text On Brand | #FFFFFF | #FFFFFF |
| Text Placeholder | #3C3C43 at 30% | #EBEBF5 at 30% |

#### Semantic Colors (Classification + Risk)

These are the most critical colors in the system. They must be immediately scannable, accessible at small sizes (the sensitivity badge is 20pt tall), and distinguishable in both light and dark mode. They follow a traffic-light-adjacent hierarchy but avoid direct red/yellow/green to prevent overlap with standard iOS system colors.

| Classification | Light Background | Light Text | Dark Background | Dark Text | Rationale |
|---|---|---|---|---|---|
| Public | #E8F5E9 | #1B5E20 | #0A2510 | #4CAF50 | Green family: low risk, open |
| Internal | #E3F2FD | #0D47A1 | #0A1929 | #64B5F6 | Blue family: in-org trust |
| Confidential | #FFF8E1 | #6D4C00 | #1F1500 | #FFB300 | Amber family: caution, restricted |
| Restricted | #FCE4EC | #7B0033 | #1A0009 | #F06292 | Rose family: high sensitivity |
| Custom (admin) | #EDE7F6 | #4A148C | #120A1E | #CE93D8 | Purple: enterprise-defined |

| Risk Level | Light | Dark | Usage |
|---|---|---|---|
| Risk Critical | #FF3B30 | #FF453A | Immediate action required, share blocked |
| Risk High | #FF9500 | #FF9F0A | Warning, policy concern |
| Risk Medium | #FFCC00 | #FFD60A | Attention, suggestion |
| Risk Low / Info | #3D5AFE | #6979F8 | Informational, AI recommendation |
| Success | #34C759 | #30D158 | Sync complete, action succeeded |

#### Glassmorphism Layer (Craft-inspired)

Used for modal sheets, contextual menus, and the AI suggestion cards. Applied as a material layer on top of content.

| Token | Light | Dark |
|---|---|---|
| Glass Fill | rgba(255,255,255,0.72) | rgba(28,28,30,0.80) |
| Glass Stroke | rgba(255,255,255,0.20) | rgba(255,255,255,0.10) |
| Glass Blur | UIBlurEffect .systemMaterial | UIBlurEffect .systemUltraThinMaterialDark |

### 2.2 Dark Mode Palette

Dark mode is a first-class experience, not an afterthought. Key principles:

- True black (#000000) is used only for the primary background on iPhone (OLED power savings). On iPad, use #1C1C1E to avoid eye strain on LCD.
- Surface elevation is expressed through lightness steps rather than shadows: elevated cards use #2C2C2E over the #1C1C1E base, and the highest elevation (sheets) uses #3A3A3C.
- Sensitivity badge colors invert their background/text pairing — the dark background tint becomes very dark (near-black tinted) and the text becomes the saturated color, maintaining legibility without the risk of washed-out pastels.
- The brand primary shifts from #3D5AFE to #6979F8 in dark mode — slightly lighter and slightly more saturated to compensate for reduced luminance perception on dark backgrounds.

### 2.3 Typography Scale (SF Pro)

All typography uses SF Pro (system font) to maintain native iOS feel and Dynamic Type compatibility. SF Pro Rounded is used sparingly for friendly, consumer-facing moments (onboarding, empty states).

| Token | Size | Weight | Line Height | Letter Spacing | Usage |
|---|---|---|---|---|---|
| Display Large | 34pt | Bold (700) | 41pt | +0.37pt | Splash screen, hero moments |
| Display | 28pt | Bold (700) | 34pt | +0.36pt | Onboarding headlines |
| Title 1 | 28pt | Regular (400) | 34pt | +0.36pt | Navigation title (large) |
| Title 2 | 22pt | Regular (400) | 28pt | +0.35pt | Section headers |
| Title 3 | 20pt | Regular (400) | 25pt | -0.45pt | Card titles, modal headers |
| Headline | 17pt | Semibold (600) | 22pt | -0.43pt | List section headers, screen titles |
| Body | 17pt | Regular (400) | 22pt | -0.43pt | Primary content, descriptions |
| Body Emphasized | 17pt | Semibold (600) | 22pt | -0.43pt | Key terms in body text |
| Callout | 16pt | Regular (400) | 21pt | -0.32pt | Secondary content blocks |
| Subheadline | 15pt | Regular (400) | 20pt | -0.23pt | Supporting labels, metadata |
| Footnote | 13pt | Regular (400) | 18pt | -0.08pt | Captions, timestamps |
| Caption 1 | 12pt | Regular (400) | 16pt | 0pt | Sensitivity badge text, indicators |
| Caption 2 | 11pt | Regular (400) | 13pt | +0.07pt | Ultra-small labels, version strings |
| Monospace Label | 13pt | Regular | 18pt | 0pt | File sizes, audit log IDs, tokens |

Dynamic Type: All text styles must map to Apple's textStyle API so that they scale with the user's preferred content size. Design at "Large" (default) size and test at xSmall and xxxLarge. Buttons and badge containers must grow to contain larger text — never clip or truncate sensitivity labels.

### 2.4 Spacing System (4pt Grid)

Every margin, padding, gap, and offset is a multiple of 4pt. This is non-negotiable for cross-screen consistency.

| Token | Value | Usage |
|---|---|---|
| space-1 | 4pt | Micro: icon-to-label gaps, badge internal padding |
| space-2 | 8pt | Tight: inline element spacing, small component padding |
| space-3 | 12pt | Compact: list item vertical padding (compact style) |
| space-4 | 16pt | Standard: default cell padding, card internal spacing |
| space-5 | 20pt | Comfortable: section header bottom margin |
| space-6 | 24pt | Generous: card-to-card gap, modal top padding |
| space-8 | 32pt | Section: between major content blocks |
| space-10 | 40pt | Layout: top of main content below nav bar |
| space-12 | 48pt | Hero: onboarding illustration spacing |
| space-16 | 64pt | Screen: bottom padding to clear tab bar |

### 2.5 Corner Radius Tokens

| Token | Value | Usage |
|---|---|---|
| radius-xs | 4pt | Sensitivity badges, small chips, progress bar caps |
| radius-sm | 8pt | Input fields, small cards, toast notifications |
| radius-md | 12pt | Standard cards, list containers, sheet handles |
| radius-lg | 16pt | Primary action cards, repository tiles |
| radius-xl | 20pt | Modal sheets, alert containers |
| radius-2xl | 28pt | Bottom sheets, large overlays |
| radius-full | 9999pt | Pills (recipient tags, online status), circular buttons |

### 2.6 Shadow / Elevation System

On iOS, shadows are used very conservatively — they primarily define floating elements. Dark mode surfaces use elevation-as-lightness instead.

| Token | Shadow (Light) | Usage |
|---|---|---|
| shadow-none | none | Flat cards on grouped backgrounds |
| shadow-xs | 0 1px 3px rgba(0,0,0,0.08) | Inline cards, subtle lift |
| shadow-sm | 0 2px 8px rgba(0,0,0,0.10), 0 1px 3px rgba(0,0,0,0.06) | Cards on primary backgrounds |
| shadow-md | 0 4px 16px rgba(0,0,0,0.12), 0 2px 6px rgba(0,0,0,0.08) | Active/hovered cards, bottom sheets handle area |
| shadow-lg | 0 8px 32px rgba(0,0,0,0.14), 0 4px 12px rgba(0,0,0,0.10) | Floating action buttons, contextual menus |
| shadow-xl | 0 16px 48px rgba(0,0,0,0.18) | Modal presentations, fullscreen overlays |

Dark mode: shadows become transparent. Elevation is communicated by fill color steps: base(#1C1C1E) → card(#2C2C2E) → elevated(#3A3A3C).

### 2.7 Border Styles

| Token | Value | Usage |
|---|---|---|
| border-none | none | Cards on background color (no visible border) |
| border-hairline | 0.5pt solid Separator | Table cell separators, standard iOS lines |
| border-thin | 1pt solid Separator | Input field borders (inactive) |
| border-focus | 2pt solid Brand Primary | Input field borders (focused) |
| border-badge | 1pt solid classification color at 40% opacity | Sensitivity badge outlines |
| border-card | 0.5pt solid rgba(0,0,0,0.08) | Cards in light mode for subtle definition |

### 2.8 Icon Style Guidelines

Use SF Symbols exclusively as the primary icon set. This guarantees:
- Dynamic Type scaling compatibility
- Automatic dark/light mode adaptation
- VoiceOver label alignment
- Consistent weight matching with typography

Supplement with a minimal set of custom icons only where SF Symbols has no equivalent (XQ shield logo mark, classification-specific icons).

| Context | SF Symbol Weight | SF Symbol Scale | Size |
|---|---|---|---|
| Tab bar (inactive) | Regular | Medium | 24x24pt |
| Tab bar (active) | Semibold | Medium | 24x24pt |
| Navigation bar actions | Regular | Medium | 22x22pt |
| List row trailing icons | Regular | Small | 16x16pt |
| Inline indicators | Light | Small | 14x14pt |
| Empty state illustration | Thin | Large | 72x72pt |
| Risk alert icons | Semibold | Large | 28x28pt |

Custom icon style: if creating any custom icons, use a 2pt stroke weight at 24x24pt canvas, rounded caps and joins, no fills. Match SF Symbol visual weight at Regular/Medium.

---

## 3. DESIGN TOKENS (COMPLETE LIST)

Format: `token-name: value-light / value-dark`

### Color Tokens

```
color/brand/primary:                   #3D5AFE / #6979F8
color/brand/primary-dim:               #E8EAFF / #1A1F3C
color/brand/secondary:                 #00C6AE / #00DDB9
color/brand/secondary-dim:             #E0F7FA / #003838

color/bg/primary:                      #F2F2F7 / #000000
color/bg/secondary:                    #FFFFFF / #1C1C1E
color/bg/tertiary:                     #F2F2F7 / #2C2C2E
color/bg/elevated:                     #FFFFFF / #2C2C2E
color/bg/card:                         #FFFFFF / #1C1C1E
color/bg/sheet:                        #F9F9F9 / #2C2C2E
color/bg/overlay:                      rgba(0,0,0,0.40) / rgba(0,0,0,0.60)

color/text/primary:                    #000000 / #FFFFFF
color/text/secondary:                  rgba(60,60,67,0.60) / rgba(235,235,245,0.60)
color/text/tertiary:                   rgba(60,60,67,0.30) / rgba(235,235,245,0.30)
color/text/quaternary:                 rgba(60,60,67,0.18) / rgba(235,235,245,0.18)
color/text/link:                       #3D5AFE / #6979F8
color/text/on-brand:                   #FFFFFF / #FFFFFF
color/text/placeholder:                rgba(60,60,67,0.30) / rgba(235,235,245,0.30)

color/separator/default:               rgba(60,60,67,0.29) / rgba(84,84,88,0.65)
color/separator/opaque:                #C6C6C8 / #38383A

color/classification/public/bg:        #E8F5E9 / #0A2510
color/classification/public/text:      #1B5E20 / #4CAF50
color/classification/public/border:    rgba(27,94,32,0.30) / rgba(76,175,80,0.30)

color/classification/internal/bg:     #E3F2FD / #0A1929
color/classification/internal/text:   #0D47A1 / #64B5F6
color/classification/internal/border: rgba(13,71,161,0.30) / rgba(100,181,246,0.30)

color/classification/confidential/bg:   #FFF8E1 / #1F1500
color/classification/confidential/text: #6D4C00 / #FFB300
color/classification/confidential/border: rgba(109,76,0,0.30) / rgba(255,179,0,0.30)

color/classification/restricted/bg:   #FCE4EC / #1A0009
color/classification/restricted/text: #7B0033 / #F06292
color/classification/restricted/border: rgba(123,0,51,0.30) / rgba(240,98,146,0.30)

color/classification/custom/bg:       #EDE7F6 / #120A1E
color/classification/custom/text:     #4A148C / #CE93D8
color/classification/custom/border:   rgba(74,20,140,0.30) / rgba(206,147,216,0.30)

color/risk/critical:                   #FF3B30 / #FF453A
color/risk/critical-dim:               #FFEEEE / #2A0800
color/risk/high:                       #FF9500 / #FF9F0A
color/risk/high-dim:                   #FFF4E0 / #261800
color/risk/medium:                     #FFCC00 / #FFD60A
color/risk/medium-dim:                 #FFFCE0 / #1F1900
color/risk/info:                       #3D5AFE / #6979F8
color/risk/info-dim:                   #E8EAFF / #1A1F3C
color/risk/success:                    #34C759 / #30D158
color/risk/success-dim:                #E8F7ED / #0A1F0F

color/glass/fill:                      rgba(255,255,255,0.72) / rgba(28,28,30,0.80)
color/glass/stroke:                    rgba(255,255,255,0.20) / rgba(255,255,255,0.10)
```

### Typography Tokens

```
font/family/primary:                   SF Pro Text / SF Pro Text
font/family/display:                   SF Pro Display / SF Pro Display
font/family/rounded:                   SF Pro Rounded / SF Pro Rounded
font/family/mono:                      SF Mono / SF Mono

font/size/display-large:               34pt / 34pt
font/size/display:                     28pt / 28pt
font/size/title-1:                     28pt / 28pt
font/size/title-2:                     22pt / 22pt
font/size/title-3:                     20pt / 20pt
font/size/headline:                    17pt / 17pt
font/size/body:                        17pt / 17pt
font/size/callout:                     16pt / 16pt
font/size/subheadline:                 15pt / 15pt
font/size/footnote:                    13pt / 13pt
font/size/caption-1:                   12pt / 12pt
font/size/caption-2:                   11pt / 11pt
font/size/mono-label:                  13pt / 13pt

font/weight/bold:                      700 / 700
font/weight/semibold:                  600 / 600
font/weight/medium:                    500 / 500
font/weight/regular:                   400 / 400
```

### Spacing Tokens

```
space/1:   4pt / 4pt
space/2:   8pt / 8pt
space/3:   12pt / 12pt
space/4:   16pt / 16pt
space/5:   20pt / 20pt
space/6:   24pt / 24pt
space/8:   32pt / 32pt
space/10:  40pt / 40pt
space/12:  48pt / 48pt
space/16:  64pt / 64pt
```

### Radius Tokens

```
radius/xs:    4pt / 4pt
radius/sm:    8pt / 8pt
radius/md:    12pt / 12pt
radius/lg:    16pt / 16pt
radius/xl:    20pt / 20pt
radius/2xl:   28pt / 28pt
radius/full:  9999pt / 9999pt
```

### Shadow Tokens

```
shadow/none:   none / none
shadow/xs:     0 1px 3px rgba(0,0,0,0.08) / none
shadow/sm:     0 2px 8px rgba(0,0,0,0.10), 0 1px 3px rgba(0,0,0,0.06) / none
shadow/md:     0 4px 16px rgba(0,0,0,0.12), 0 2px 6px rgba(0,0,0,0.08) / none
shadow/lg:     0 8px 32px rgba(0,0,0,0.14), 0 4px 12px rgba(0,0,0,0.10) / none
shadow/xl:     0 16px 48px rgba(0,0,0,0.18) / none
```

### Motion / Timing Tokens

```
motion/duration/instant:        100ms / 100ms
motion/duration/fast:           200ms / 200ms
motion/duration/normal:         300ms / 300ms
motion/duration/slow:           450ms / 450ms
motion/duration/deliberate:     600ms / 600ms

motion/easing/standard:         cubic-bezier(0.4, 0.0, 0.2, 1.0) (SwiftUI: .easeInOut)
motion/easing/decelerate:       cubic-bezier(0.0, 0.0, 0.2, 1.0) (SwiftUI: .easeOut)
motion/easing/accelerate:       cubic-bezier(0.4, 0.0, 1.0, 1.0) (SwiftUI: .easeIn)
motion/easing/spring-snappy:    SwiftUI: .spring(response: 0.35, dampingFraction: 0.72)
motion/easing/spring-bouncy:    SwiftUI: .spring(response: 0.45, dampingFraction: 0.65)
motion/easing/spring-soft:      SwiftUI: .spring(response: 0.55, dampingFraction: 0.85)

motion/offset/entry-y:          +20pt (elements enter from 20pt below final position)
motion/offset/entry-x-leading:  -16pt (elements entering from leading edge)
motion/scale/exit:              0.92 (exit animations scale down to 92%)
motion/scale/tap:               0.96 (spring tap feedback scale)
motion/opacity/entry-start:     0.0
motion/opacity/exit-end:        0.0
```

### Border Tokens

```
border/hairline:    0.5pt / 0.5pt
border/thin:        1pt / 1pt
border/medium:      2pt / 2pt
```

### Icon Size Tokens

```
icon/tab:           24x24pt
icon/nav:           22x22pt
icon/list:          20x20pt
icon/inline:        16x16pt
icon/micro:         14x14pt
icon/hero:          72x72pt
```

### Touch Target Tokens

```
touch/minimum:      44x44pt (WCAG + Apple HIG minimum)
touch/comfortable:  48x48pt (preferred for primary actions)
touch/compact:      36x36pt (allowed only for secondary inline icons with surrounding space)
```

---

## 4. COMPONENT LIBRARY

### Priority 1: Build First (Required for Every Screen)

#### 4.1 Navigation Bar Variants

**Standard Navigation Bar**
- Large title variant: title at bottom of nav area, 34pt Bold, Text Primary
- Inline/compact title variant: title centered, 17pt Semibold, Text Primary
- Background: Blur material (.systemMaterial) — not a flat color
- Right actions: up to 2 icon buttons, 22pt SF Symbols, hit target 44x44pt
- Left action: Back chevron OR contextual action, same sizing
- Separator: only visible when scrolled (0.5pt, Separator color)
- Scroll behavior: large title collapses to inline on scroll (standard iOS pattern)

**Admin Navigation Bar**
- Same as Standard but adds a purple/custom-colored dot indicator (8pt circle, color/brand/secondary) next to the title to signal admin context
- Right side adds "Admin" role badge: 12pt Caption 1, custom/bg background, radius-full

**Modal Navigation Bar**
- No large title. Always inline/compact.
- Left: "Cancel" as text button (17pt, color/brand/primary)
- Right: "Done" or primary action as filled text button (17pt Bold, color/brand/primary)

#### 4.2 Tab Bar

Bottom tab bar with 5 tabs: Home, Files, Email, Shares, Settings.

**Structure per tab item:**
- SF Symbol icon: 24x24pt, Regular weight when inactive, Semibold when active
- Label: 10pt, Caption 2 weight, Semibold when active
- Active state: icon and label both use color/brand/primary
- Inactive state: icon and label use color/text/secondary
- Active indicator: small filled capsule (28x4pt) centered above icon, brand primary, visible only when active
- Badge (for unread/alerts): standard iOS badge, max 2 digits, color/risk/critical background, white text

**Tab item layout (phone):**
- Icon centered horizontally
- Label 4pt below icon
- Total hit area: full tab width x 49pt (standard iOS tab bar height)

**iPad variant:**
- Tab bar appears as a sidebar column (width: 320pt) when in regular horizontal size class
- Tab items become full-width rows with icon + full label
- Selected item shows brand-primary left border (3pt) and brand-primary-dim background

#### 4.3 File List Item

The most-used component in the app. Must work at two densities: default and compact.

**Default variant (iPhone list):**
- Height: 72pt
- Leading: File type icon (32x32pt thumbnail or SF Symbol), 16pt from leading edge
- Title: 17pt Semibold, Text Primary, single line, truncates with ellipsis
- Subtitle: 13pt, Text Secondary, single line — shows "Last modified: [time]" or sync status
- Sensitivity badge: positioned trailing-top of the thumbnail or just below title, right-aligned
- Trailing area (right side): sync status icon (16pt) + chevron (13pt)
- Offline badge: cloud.slash SF Symbol, 16pt, color/text/tertiary, shown when file is offline-only
- Swipe actions: leading swipe reveals "Mark Offline" (blue), trailing swipe reveals "Share" (brand), "Delete" (red)

**Compact variant (iPad sidebar):**
- Height: 52pt
- Same elements, reduced spacing (12pt vertical padding instead of 16pt)

**States:**
- Default: white/elevated background
- Highlighted/Selected: brand-primary-dim fill (matches Apple's selection behavior)
- Uploading: spinner replaces trailing chevron, progress shown as thin bottom-edge bar
- Offline cached: offline badge visible, subtle background tint (bg/tertiary)
- Restricted (view-only): lock icon overlaid on thumbnail at bottom-right

#### 4.4 Sensitivity Badge

The smallest but most important governance element. Appears on file list items, in the file viewer header, on email list rows, and in the share workflow.

**Anatomy:**
- Background: classification/[level]/bg color
- Text: classification/[level]/text color, 11pt Caption 2 Semibold, all caps
- Border: 0.5pt, classification/[level]/border color
- Padding: 4pt vertical, 8pt horizontal
- Corner radius: radius-xs (4pt)
- Min width: 56pt (enough for "PUBLIC"), max unconstrained

**Four variants:**
1. Public — green scheme — text: "PUBLIC"
2. Internal — blue scheme — text: "INTERNAL"
3. Confidential — amber scheme — text: "CONFIDENTIAL"
4. Restricted — rose scheme — text: "RESTRICTED"

**Sizing rule:** Text adapts to Dynamic Type but badge minimum height is always 20pt for legibility. On smallest Dynamic Type sizes, text may appear smaller but badge does not shrink below this.

**Accessibility:** VoiceOver reads "Classification: [level]". High contrast mode adds a 2pt opaque border.

#### 4.5 Risk Alert Card

Used on Home screen, in Notifications, and as a floating banner over file viewer when high-risk content is detected.

**Anatomy:**
- Background: risk/[level]-dim color
- Left accent bar: 3pt wide, full height, risk/[level] color
- Icon: SF Symbol at 24pt, Semibold, risk/[level] color — "exclamationmark.triangle.fill" for high/critical, "info.circle.fill" for medium/info
- Title: 15pt Subheadline Semibold, Text Primary
- Description: 13pt Footnote, Text Secondary, up to 2 lines
- Action button: text only, 15pt Subheadline, color/brand/primary, right-aligned
- Dismiss button (optional): xmark SF Symbol, 14pt, Text Tertiary, top-right corner
- Corner radius: radius-md (12pt)
- Shadow: shadow-sm in light mode

**Variants:**
- Critical: full red left bar, exclamationmark.shield.fill icon, no dismiss (must be resolved)
- High: orange left bar, exclamationmark.triangle.fill icon, has dismiss
- Medium: yellow left bar, info.circle icon, subtle, dismissible
- Info/AI: brand-primary left bar, wand.and.stars icon, dismissible

**Entry animation:** Slides in from top (y offset -100pt → 0) with spring-snappy easing + opacity 0 → 1. Duration 350ms.

#### 4.6 Button Components

**Primary Button:**
- Background: color/brand/primary
- Text: 17pt Headline, white, never truncates (button expands horizontally for localization)
- Height: 50pt (comfortable touch target with visual breathing room)
- Corner radius: radius-md (12pt)
- Padding: 16pt horizontal minimum
- Pressed state: scale to 0.96, brightness -10%, spring animation 150ms
- Disabled state: opacity 0.40, not interactive
- Loading state: spinner replaces text, button width locks to current size

**Secondary Button:**
- Background: color/brand/primary-dim
- Text: 17pt Headline, color/brand/primary
- Same sizing as Primary
- Pressed state: background darkens 8%, scale 0.96

**Tertiary / Ghost Button:**
- Background: transparent
- Text: 17pt Headline, color/brand/primary
- Border: none (tap area only)
- Used for "Cancel", "Skip", inline text actions

**Destructive Button:**
- Background: color/risk/critical
- Text: 17pt Headline, white
- Same sizing, used for irreversible actions only
- Requires confirmation: double-tap or confirmation dialog before executing

**Icon Button (circular):**
- Background: color/bg/tertiary
- Icon: 22pt SF Symbol, Text Primary
- Size: 44x44pt, radius-full
- Used in navigation bars and tool bars
- Pressed: scale 0.90, spring-snappy 150ms

**Adaptive width rule (localization):** All buttons must use intrinsic sizing with minimum width and horizontal padding. Never set a fixed width. On RTL layouts, internal layout mirrors automatically.

#### 4.7 Text Inputs (Adaptive Width)

**Standard Text Field:**
- Height: 50pt
- Background: color/bg/secondary
- Border: 1pt, color/separator/opaque (inactive); 2pt, color/brand/primary (focused)
- Placeholder: color/text/placeholder, 17pt Body
- Text: 17pt Body, color/text/primary
- Label (above field): 13pt Footnote Semibold, color/text/secondary, 8pt above field
- Error state: border becomes 2pt color/risk/critical, error message appears below in 13pt Footnote color/risk/critical
- Corner radius: radius-sm (8pt)
- Padding: 16pt horizontal, 14pt vertical

**Search Field:**
- Height: 36pt (uses standard iOS search bar component)
- Magnifying glass icon leading, clear button trailing
- Background: color/bg/tertiary
- Corner radius: radius-md (12pt)

**Multi-line Text Area:**
- Min height: 100pt, expands vertically with content
- Same styling as Standard Text Field
- Character counter in bottom-right (13pt Footnote, Text Tertiary) when limit is set

**Adaptive behavior:** All inputs expand to fill available width. On iPad in SplitView detail pane, inputs constrain to max-width 640pt with centered alignment.

#### 4.8 Loading / Skeleton States

Every list, card grid, and content area must have a skeleton state shown during initial load. No spinning indicators in the middle of content areas.

**Skeleton anatomy:**
- Fill: gradient from color/bg/tertiary to color/bg/secondary, animated as a horizontal shimmer sweep
- Shimmer animation: gradient moves from leading to trailing over 1200ms, loops. Easing: linear.
- Shape: matches the actual component shape (same height, same radius, same layout positions)
- File list item skeleton: 72pt tall, left circle (32pt) + two right lines (60% and 40% width)
- Card skeleton: full card dimensions, no internal details

**Full-screen loading (splash/initialization):**
- XQ animated logo mark (not a spinner)
- Progress label in 15pt Subheadline, Text Secondary: localized string "Initializing secure environment..."
- Security check items appear sequentially: checkmark.seal.fill SF Symbol animates in, text fades in

#### 4.9 Empty States

Every screen that can be empty must have a designed empty state. Never show a bare blank screen.

**Anatomy:**
- Hero icon: 72x72pt SF Symbol, Thin weight, color/text/tertiary
- Title: 20pt Title 3, Text Primary, centered, max 2 lines
- Description: 15pt Subheadline, Text Secondary, centered, max 3 lines
- Primary CTA button (optional): Primary button, centered below description, 32pt gap
- Secondary text action (optional): below primary button

**Empty state variants per context:**
- Files (no connected repository): "cloud.slash" icon, "No repositories connected", "Connect SharePoint or a network drive to access your files securely", [Connect Repository] button
- Email (empty inbox): "tray" icon, "Secure Inbox is Empty", "No messages to display."
- Shares (no shares): "person.3" icon, "Nothing Shared Yet", "Share files securely to see them here.", [Share a File] button
- Search (no results): "magnifyingglass" icon, "No Results Found", "Try different keywords or filters."
- Offline (no cached files): "wifi.slash" icon, "No Offline Files", "Mark files to access them without a connection."

---

### Priority 2: Build Second

#### 4.10 AI Suggestion Card

A non-blocking, dismissible suggestion surface. This is the primary way the AI communicates with users without creating friction.

**Anatomy:**
- Background: glass/fill with glass/stroke border
- UIBlurEffect behind it
- Icon: wand.and.stars.inverse SF Symbol, 20pt, color/brand/primary
- Label: "AI Suggestion" in 11pt Caption 1, color/brand/primary, Semibold
- Title: 15pt Subheadline Semibold, Text Primary
- Body: 13pt Footnote, Text Secondary, max 2 lines
- Accept action: text button, 15pt Subheadline, color/brand/primary
- Dismiss: xmark 13pt, Text Tertiary
- Corner radius: radius-lg (16pt)
- Shadow: shadow-md

**Placement:** Inline between list items, or as a floating strip at bottom of screen above tab bar (similar to Siri suggestion strips).

#### 4.11 Policy Indicator Chip

A compact inline badge that communicates which policies are active on a file or email.

**Anatomy:**
- Background: color/bg/tertiary
- Icon: 12pt SF Symbol (lock for encryption, eye.slash for view-only, timer for expiration, globe for geofence)
- Text: 11pt Caption 1, Text Secondary
- Border: 0.5pt, Separator
- Padding: 4pt vertical, 8pt horizontal
- Radius: radius-full

**Chips stack horizontally with 4pt gaps.** On overflow (more than 3 chips), collapse to "+N more" chip.

#### 4.12 Share Recipient Pill

Used in the Compose Email and Secure Share screens to display selected recipients.

**Anatomy:**
- Background: color/brand/primary-dim
- Avatar: initials in 12pt Caption 1, white, on brand-primary circle, 24pt diameter, leading
- Name: 13pt Footnote Semibold, color/brand/primary
- XQ indicator (if recipient has XQ): small shield.fill SF Symbol, 10pt, color/risk/success (recipient is encrypted end-to-end)
- Remove: xmark 10pt, color/brand/primary, trailing — 24x24pt tap target
- Radius: radius-full
- Height: 32pt

**External recipient variant:**
- Background: color/risk/high-dim
- Text: color/risk/high
- Trailing icon: "person.crop.circle.badge.exclamationmark" to signal external
- Tooltip: tapping shows "External recipient — AI evaluated for risk"

#### 4.13 Document Thumbnail with Classification Overlay

Used in grid view of files and in the file viewer header.

**Anatomy:**
- Base: file type icon or image preview, 60x80pt (3:4 aspect, portrait)
- Corner radius: radius-sm (8pt)
- Sensitivity badge: bottom-left overlay, floats over the thumbnail with 2pt margin
- Offline indicator: bottom-right, cloud.fill with slash, 16pt, white icon on dark semi-transparent circle (20pt diameter)
- Shadow: shadow-sm

#### 4.14 Offline Status Indicator

A system-wide bar or compact pill that appears when the device is offline.

**Banner variant (full-width):** 
- 44pt tall strip at top of main content (below nav bar)
- Background: color/risk/high-dim
- Icon: wifi.slash, 16pt, color/risk/high
- Text: 13pt Footnote, color/risk/high — localized "Working Offline — changes will sync when connected"
- Animated entry: slides in from top, 300ms, easeOut

**Compact pill variant (persistent, non-blocking):**
- 28pt tall pill, bottom-right of tab bar area
- Only shows on File Browser and Home when offline
- "Offline" label + wifi.slash icon

#### 4.15 Progress Bars

**Linear progress bar:**
- Track: color/bg/tertiary, height 4pt, radius-full
- Fill: color/brand/primary, animated width change, spring-soft
- Indeterminate variant: animated gradient sweep for unknown duration tasks

**Circular progress indicator:**
- Used for per-file sync status in list rows
- 20pt diameter, 2pt stroke weight
- Matches color/brand/primary

---

## 5. ANIMATION SYSTEM SPEC

### 5.1 Entry Animations

Every element that appears on screen after page load or as a result of a user action must use this entry pattern:

**Standard Entry:**
- Opacity: 0 → 1
- Y offset: +20pt → 0pt
- Duration: 300ms
- Easing: .easeOut (decelerate curve)
- SwiftUI: `.transition(.opacity.combined(with: .move(edge: .bottom))).animation(.easeOut(duration: 0.3), value: isVisible)`

**Staggered List Entry (file list, notification list):**
- Each row gets a delay based on its index: delay = index * 40ms (max delay capped at 200ms)
- Same opacity + Y offset as above
- Creates a cascading waterfall effect with 40ms between items
- SwiftUI: `.animation(.easeOut(duration: 0.3).delay(Double(index) * 0.04), value: isVisible)`

**Alert / Risk Card Entry:**
- Entry direction: from top (Y = -full card height → 0)
- Opacity: 0 → 1
- Spring: `.spring(response: 0.45, dampingFraction: 0.72)` — slightly bouncy to attract attention
- Duration: approximately 400ms with spring settle

**Modal Sheet Entry:**
- Standard iOS sheet presentation (SwiftUI .sheet modifier)
- Custom: for glassmorphism sheets, scale from 0.92 → 1.0 + opacity 0 → 1
- Duration: 350ms, easeOut

**Tab Switch Entry:**
- Outgoing view: opacity 1 → 0, scale 1 → 0.95, duration 150ms, easeIn
- Incoming view: opacity 0 → 1, scale 1.02 → 1.0, duration 250ms, easeOut
- Overlap: incoming starts 50ms after outgoing begins

### 5.2 Exit Animations

**Standard Exit:**
- Opacity: 1 → 0
- Scale: 1.0 → 0.92
- Duration: 200ms
- Easing: .easeIn (accelerate curve — feels like object is leaving quickly)
- SwiftUI: `.transition(.opacity.combined(with: .scale(scale: 0.92))).animation(.easeIn(duration: 0.2), value: isVisible)`

**Swipe to Dismiss Exit:**
- Follows finger position (no easing during gesture)
- On release above threshold: accelerates upward with gravity curve
- On release below threshold: spring back to origin with `.spring(response: 0.4, dampingFraction: 0.8)`

**Alert Dismiss Exit:**
- Upward: Y = 0 → -full height
- Opacity: 1 → 0
- Duration: 250ms, easeIn

### 5.3 Tap / Spring Response

Every interactive element must have a tactile response on tap. This is a non-negotiable spec requirement.

**Buttons (Primary, Secondary, Destructive):**
- On press down: scale 1.0 → 0.96, duration 100ms, `.spring(response: 0.25, dampingFraction: 0.8)`
- On release: scale 0.96 → 1.0, duration 200ms, `.spring(response: 0.35, dampingFraction: 0.65)` (slight overshoot to 1.02 then settles to 1.0)
- Haptic: UIImpactFeedbackGenerator .light on press, .medium on release if action executes

**List Rows:**
- On press: background fills with highlighted color, scale 0.99 (very subtle), 80ms easeOut
- On release: background clears, scale returns to 1.0, 150ms easeOut

**Icon Buttons:**
- On press: scale 1.0 → 0.88, 100ms
- On release: scale 0.88 → 1.05 → 1.0, spring `.spring(response: 0.3, dampingFraction: 0.6)` — noticeable bounce
- Haptic: .light

**Tab bar items:**
- On select: icon scale 1.0 → 1.15 → 1.0, spring `.spring(response: 0.4, dampingFraction: 0.55)` — bouncy
- Active indicator pill: scale from center X, 200ms spring

**Sensitivity badge (tapped for info):**
- Scale: 1.0 → 1.05, spring quick settle
- Then immediately presents tooltip/popover

### 5.4 Navigation Transitions

**Push (drill into folder / file):**
- New screen slides in from trailing edge
- Current screen slides to leading edge at 30% of distance (parallax effect)
- Duration: 400ms, spring `.spring(response: 0.5, dampingFraction: 0.82)`
- This is the standard NavigationStack animation — do not override unless necessary

**Pop (back navigation):**
- Reverse of push with swipe-back gesture support (full-screen swipe from leading edge)

**Modal presentation:**
- Sheet rises from bottom
- Underlying content dims and scales to 0.92 (3D card effect matching iOS 15+ behavior)

**Tab switch:**
- Crossfade with slight scale (described in Entry section above)
- No slide: tabs are not hierarchically related

### 5.5 Risk Alert Animations

Risk alerts require special choreography to communicate urgency without being alarming.

**Critical risk (share blocked, policy violation):**
1. Alert card enters from top with spring-bouncy (one visible overshoot)
2. Screen overlay darkens to rgba(0,0,0,0.40)
3. Haptic: UINotificationFeedbackGenerator .error
4. Card pulses once: scale 1.0 → 1.02 → 1.0, 600ms, easeInOut — subtle breathing effect to maintain attention
5. Dismiss only via explicit user action (no timeout)

**High risk (warning):**
1. Alert card enters from top, spring-snappy (minimal overshoot)
2. No screen overlay
3. Haptic: UINotificationFeedbackGenerator .warning
4. Auto-dismiss after 8 seconds if user takes no action (progress bar shows countdown)

**Medium / Info:**
1. Inline card animates in with standard entry (fade + upward motion)
2. Haptic: UIImpactFeedbackGenerator .light
3. Auto-dismiss after 5 seconds

### 5.6 File Action Gestures

**Swipe leading (right swipe on file row):**
- Reveals "Offline" action button (cloud.fill icon, blue background)
- Reveals "Share" action button (square.and.arrow.up icon, brand-primary background)
- Swipe distance: action reveals at 80pt swipe, executes at full-open (200pt)
- Spring-back animation when gesture ends without execution

**Swipe trailing (left swipe on file row):**
- Reveals "Delete" or "Remove" action (trash icon, red background)
- Requires swipe to full open to execute — prevents accidental deletion
- Confirmation haptic: .warning on execution

**Long press:**
- After 500ms hold: context menu appears (UIContextMenuInteraction)
- Preview: 3D lift effect on the row — scale 1.0 → 1.04, shadow increases
- Menu items: Open, Share Securely, Mark Offline, Copy Link, Info

**Drag to reorder (within folder):**
- On long press in edit mode: row lifts with shadow-lg, slight scale 1.02
- Movement: follows finger, other rows spring out of the way
- Drop: spring settle to new position

### 5.7 SwiftUI Animation Parameter Reference

```swift
// Standard entry
.animation(.easeOut(duration: 0.3), value: trigger)

// Standard exit  
.animation(.easeIn(duration: 0.2), value: trigger)

// Button press down
.animation(.spring(response: 0.25, dampingFraction: 0.8), value: isPressed)

// Button release (bounce)
.animation(.spring(response: 0.35, dampingFraction: 0.65), value: isPressed)

// Icon button bounce
.animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)

// Alert entry (attention-grabbing)
.animation(.spring(response: 0.45, dampingFraction: 0.72), value: isVisible)

// Tab item bounce
.animation(.spring(response: 0.4, dampingFraction: 0.55), value: isSelected)

// Navigation push
.animation(.spring(response: 0.5, dampingFraction: 0.82), value: path)

// Stagger delay (per item)
.animation(.easeOut(duration: 0.3).delay(Double(index) * 0.04), value: isVisible)

// Skeleton shimmer
.animation(.linear(duration: 1.2).repeatForever(autoreverses: false), value: phase)
```

---

## 6. FIGMA PROJECT STRUCTURE

### 6.1 Recommended Page Structure

```
Page 1: Cover + Index
  - Project cover with XQ branding
  - Page index and quick-reference links
  
Page 2: Design Foundations
  - Color palette swatches (all tokens)
  - Typography scale specimens
  - Spacing grid reference
  - Radius examples
  - Shadow/elevation reference
  - Icon style guide

Page 3: Design Tokens
  - Token tables (light + dark values)
  - Color mode toggle demonstration

Page 4: Component Library — Priority 1
  - Navigation bars (all variants)
  - Tab bars (iPhone + iPad)
  - File list items (all states)
  - Sensitivity badges (all 5 levels)
  - Risk alert cards (all 4 levels)
  - Buttons (all types + states)
  - Text inputs (all states)
  - Loading/skeleton states
  - Empty states

Page 5: Component Library — Priority 2
  - AI suggestion cards
  - Policy indicator chips
  - Share recipient pills
  - Document thumbnails
  - Offline status indicators
  - Progress bars
  - Contextual menus
  - Tooltips/popovers

Page 6: Animation Reference
  - Annotated storyboards for each animation type
  - Timing diagrams
  - Figma Smart Animate demonstrations

Page 7: Screen 1 — Splash / Secure Init
  (iPhone + iPad frames, light + dark)

Page 8: Screen 2 — Welcome / Onboarding
  (3 onboarding slides × iPhone + iPad)

Page 9: Screen 3 — Repository Setup
  (iPhone + iPad, empty + filled states)

Page 10: Screen 4 — Permissions Setup
  (iPhone + iPad)

Page 11: Screen 5 — Home Dashboard
  (iPhone + iPad, empty + populated + risk alert states)

Page 12: Screen 6 — File Browser
  (iPhone list + iPad SplitView, empty + populated, search active)

Page 13: Screen 7 — Secure File Viewer
  (iPhone + iPad, PDF view + restricted view + editing disabled)

Page 14: Screen 8 — Document Editing
  (iPhone + iPad, Word + Excel variants)

Page 15: Screen 9 — Secure Share Workflow
  (Bottom sheet modal, step 1-4 states)

Page 16: Screen 10 — Local File Import
  (iPhone + iPad, import picker + AI suggestion state)

Page 17: Screen 11 — AI Document Scanner
  (iPhone only camera view + classified state)

Page 18: Screen 12 — Secure Email Inbox
  (iPhone + iPad, empty + populated + risk flag)

Page 19: Screen 13 — Compose Email
  (iPhone + iPad, draft + AI warning state)

Page 20: Screen 14 — Notifications
  (iPhone + iPad, empty + multi-alert)

Page 21: Screen 15 — Sharing Center
  (iPhone + iPad, empty + active shares)

Page 22: Screen 16 — Policy Management (Admin)
  (iPhone + iPad, classification config + sharing rules)

Page 23: Screen 17 — Audit & Activity (Admin)
  (iPhone + iPad, log list + filter panel)

Page 24: Screen 18 — Settings
  (iPhone + iPad, full settings list)

Page 25: Interaction Flow Map
  - Full user journey diagram

Page 26: Prototype Links
  - 5 clickable prototype flows documented here

Page 27: Handoff Notes
  - Developer annotations, spacing callouts, asset specs
```

### 6.2 Frame Naming Convention

```
[ScreenNumber]_[ScreenName]_[Device]_[Mode]_[State]

Examples:
05_Home_iPhone_Light_Default
05_Home_iPhone_Dark_RiskAlert
05_Home_iPad_Light_Default
07_FileViewer_iPhone_Dark_RestrictedFile
09_SecureShare_iPhone_Light_Step2_ExternalRecipient
16_PolicyMgmt_iPad_Light_AdminOnly
```

### 6.3 Component Naming Convention in Figma

```
[Category]/[ComponentName]/[Variant]

Examples:
Buttons/Primary/Default
Buttons/Primary/Loading
Buttons/Primary/Disabled
Sensitivity/Badge/Confidential
Sensitivity/Badge/Restricted
Navigation/Bar/LargeTitle
Navigation/Bar/Inline
Navigation/Bar/Modal
Files/ListItem/Default
Files/ListItem/Offline
Files/ListItem/Uploading
Risk/AlertCard/Critical
Risk/AlertCard/High
Email/RecipientPill/Internal
Email/RecipientPill/External
```

### 6.4 Auto-Layout Rules

All components must be built with Auto Layout enabled. Key rules:

- **Hugging containers:** buttons use hug-content width + fixed height
- **Fill containers:** inputs and cards use fill-parent width with max-width constraints
- **Nested Auto Layout:** all complex components (file list item, alert card) have multiple nested auto-layout frames
- **Resizing behavior:** when a component is placed in a frame, it should stretch horizontally to fill (fill-container) and hug vertically
- **Padding:** always use the spacing tokens — set padding numerically, not visually
- **Gap:** use the gap property for spacing between children, not spacer frames

### 6.5 Variant Structure

Create a single component with all variants consolidated:

**Buttons component variants:**
- Type: Primary, Secondary, Tertiary, Destructive, Icon
- State: Default, Hovered, Pressed, Disabled, Loading
- Size: Large (50pt), Medium (44pt), Small (36pt)

**File List Item variants:**
- Density: Default, Compact
- State: Default, Selected, Uploading, Offline, ViewOnly, Loading

**Sensitivity Badge variants:**
- Level: Public, Internal, Confidential, Restricted, Custom
- Size: Default, Large (file viewer header)

**Risk Alert Card variants:**
- Severity: Critical, High, Medium, Info
- Layout: Inline, Floating, FullBanner

---

## 7. SCREEN-BY-SCREEN DESIGN SPEC

### Screen 1: Splash / Secure Initialization

**Purpose:** First impression + runtime security validation. No user interaction required.

**Layout Structure:**
- Full bleed dark background: #000000 (always dark, regardless of device preference)
- Center: XQ shield/logo mark, 80x80pt, white — use the brand logomark, not a generic shield
- Below logo: "XQ Secure Workspaces" in 28pt Display Bold, white
- Below product name: 32pt gap, then a status area
- Status area: animated progress — each security check item appears sequentially (fade + upward 12pt, 200ms each, 150ms stagger):
  - checkmark.shield.fill + "Device integrity verified"
  - lock.shield.fill + "Secure enclave initialized"
  - key.fill + "Session restored"
  - brain.fill + "AI governance active"
- Each check item: icon (16pt, color/risk/success) + label (15pt, Text Secondary/white at 60%)
- Below checks: 40pt gap, then a thin progress bar (320pt wide, 2pt tall, radius-full) — brand-primary fill animating left to right

**States:**
- Loading: items appear one by one
- Complete: all items visible, progress bar full, 300ms pause, then transition to next screen
- Failure (integrity check failed): items stop, a red alert card entry animation, message "Device integrity check failed", button "Contact Support"

**Animation behaviors:**
- Logo entry: scale from 0.7 → 1.0 + opacity 0 → 1, spring-bouncy, 600ms
- Logo has a subtle continuous rotation of the shield's inner lock element (Core Animation layer rotation, 0.5 rotations per second, sinusoidal oscillation ±15 degrees — not a full spin)
- Status items stagger in as described above
- Progress bar grows with easeInOut

**iPhone vs iPad:** Identical layout, centered on both. No adaptation needed. iPad may show a slightly larger logo (100x100pt).

**Accessibility:** VoiceOver reads status items as they appear. Reduced motion: items appear instantly without animation. The screen auto-advances — no interaction required.

---

### Screen 2: Welcome / Onboarding

**Purpose:** Product introduction + deployment model selection.

**Layout Structure:**
- 3-page horizontal scroll carousel (paged, no bounce)
- Each page: full screen
- Page indicator: 3 dots, 8pt diameter, 8pt gap, centered above bottom buttons, brand-primary for active, text-tertiary for inactive
- Navigation: "Next" primary button (full width minus 32pt margins), "Skip" tertiary text at top-trailing

**Page 1 — "Your files. Protected."**
- Illustration area: top 50% of screen, SF Symbols composition or illustration — shield.fill + doc.fill + lock.fill arranged in a layered visual, brand-primary + secondary colors, animated subtle floating/breathing (scale oscillation ±2%, 3s period)
- Bottom 50%: title "Your Files. Automatically Protected." (28pt Display Bold), 24pt gap, body "XQ works invisibly in the background — classifying, encrypting, and governing your files without you lifting a finger." (17pt Body, Text Secondary, centered, 32pt horizontal margins)

**Page 2 — "Secure by default."**
- Illustration: animated sequence showing file → scan → badge appearing on file → lock icon. 3-step animation running on loop.
- Title: "Security happens automatically."
- Body: "No training. No manual policies. The moment you add a file, AI classifies and protects it."

**Page 3 — Choose path**
- No illustration
- Title: "How would you like to start?" (22pt Title 2)
- Two option cards (full width, 120pt tall each, radius-lg, border-thin):
  - Card 1: "Start Locally" — cloud.slash + house.fill icon (24pt, brand-primary), "Use XQ without an account. Your device, your files, fully encrypted locally." (13pt Footnote, Text Secondary), chevron trailing
  - Card 2: "Connect Enterprise Workspace" — building.2.fill icon (24pt, brand-secondary), "Connect to SharePoint, Outlook, or your enterprise systems." (13pt Footnote, Text Secondary), chevron trailing
- Below cards: "Already have an account? Sign in" (13pt Footnote, color/text/link)

**Animation behaviors:**
- Page transition: horizontal slide (standard paged scroll behavior)
- Page content entry: on each page reveal, title fades + moves up 16pt, then body follows with 80ms delay
- Illustration elements animate on entry and idle

**iPhone vs iPad:** On iPad, wrap the carousel in a centered container (max-width 540pt) with the background showing brand-primary-dim at very low opacity. The two-path cards on Page 3 appear side-by-side in a 2-column grid on iPad.

**Accessibility:** All illustration elements have VoiceOver descriptions. Carousel is swipeable. Reduced motion: no illustration animations, instant page transitions.

---

### Screen 3: AI-Assisted Repository Setup

**Purpose:** Configure enterprise repository connection with AI guidance.

**Layout Structure (modal full-screen sheet):**
- Navigation bar: "Set Up Repository" (inline title), "Cancel" left, no right action initially
- Content: vertically scrollable

**Section 1 — Choose repository type**
- 3-column icon grid (or 2-column on iPhone):
  - SharePoint (Microsoft icon)
  - Network Drive / SMB (network icon)
  - Local Vault only (no cloud)
- Each tile: 96x96pt, radius-lg, border-hairline, icon (32pt) + label below (13pt Footnote)
- Active selection: brand-primary-dim fill, brand-primary border (2pt)

**Section 2 — AI Assistant panel** (appears after repository type selection)
- Chat-style interface, not a traditional form
- AI messages appear as bubbles: background color/bg/tertiary, radius-lg, max-width 80% of screen
- User inputs appear as text field at bottom (sticky)
- First AI message: "I'll help you connect to SharePoint. What's your organization's SharePoint URL?" + input suggestion chips: "I don't know it", "Search for it", "Enter manually"
- AI suggests and validates: connection diagnostics shown inline as progress items

**Section 3 — Credential/connection form** (appears after URL confirmed)
- Standard form fields (using Text Input component)
- "Connect" primary button at bottom
- Real-time validation: field borders animate to success (green) or error (red) state

**States:**
- Empty: just repository selector visible
- Repository selected: AI panel slides in from bottom
- Connecting: spinner on Connect button, progress messages in AI chat
- Success: checkmark animation, brief celebration, then auto-advance to Permissions

**Animation behaviors:**
- AI chat bubbles: each bubble fades + slides in from leading (120ms delay between bubbles)
- AI typing indicator: three dots pulsing (standard typing indicator pattern)
- Repository tile selection: spring scale 0.96 → 1.0 on tap, border color transitions 150ms

**iPhone vs iPad:** On iPad, AI chat panel and form appear side-by-side in a 2-column layout.

**Accessibility:** All AI chat messages are VoiceOver accessible. Typing indicator announced as "AI is typing". Focus moves to new AI messages as they appear.

---

### Screen 4: Permissions Setup

**Purpose:** Request iOS permissions with clear rationale.

**Layout Structure:**
- Navigation bar: "Permissions" (large title), no back button (sequential onboarding)
- Scrollable permission list, one permission per section card

**Permission card anatomy:**
- Card: full width, radius-lg, border-thin, bg/secondary
- Leading: iOS permission icon (Face ID → faceid SF Symbol, Notifications → bell.badge, Files → folder, Camera → camera.fill, Network → network) at 36pt, in a 56x56pt rounded square (brand-primary-dim fill)
- Title: 17pt Headline Semibold, Text Primary
- Description: 15pt Subheadline, Text Secondary, wraps to multiple lines
- Bottom: Toggle or "Allow Access" text button (right-aligned, color/brand/primary)
- AI explanation (collapsible): chevron.down button, expands a 13pt Footnote explanation of the security/privacy rationale

**Permissions in order:**
1. Face ID — "Protect your workspace with biometric authentication."
2. Notifications — "Receive real-time security alerts and sync status."
3. Files Access — "Import documents from your Files app securely."
4. Camera Roll — "Import photos and documents directly."
5. Local Network — "Connect to network drives on your local network." (only shown if enterprise path selected)

**Bottom area:**
- "Continue" primary button (full width, 32pt margins)
- "Set up later in Settings" tertiary text below

**States:**
- Default: all permissions pending
- Granted: green checkmark badge appears on the permission icon tile
- Denied: warning indicator, "Allow in Settings" link replaces toggle

**Animation behaviors:**
- Permission cards stagger in on appear (40ms between each)
- On permission grant: checkmark badge pops in with spring-bouncy scale
- On "Continue" tap with all granted: confetti-light animation (3 classification badge colors falling, small particles — 800ms then clears)

**iPhone vs iPad:** iPad shows permissions in a 2-column grid. Each card is 300pt wide.

---

### Screen 5: Home Dashboard

**Purpose:** Primary productivity surface. Most-visited screen.

**Layout Structure:**
- Navigation bar: large title "Home", trailing: bell.badge icon (notification count badge), plus icon (import/new action)
- ScrollView content:
  1. Risk alert strip (conditional, shown only when risk exists) — full width, Risk Alert Card component
  2. Quick Actions row — 4 horizontal action chips
  3. Recent Files section — horizontal scroll of file thumbnails + list toggle
  4. AI Suggested section — horizontal scroll of AI Suggestion Cards
  5. Offline Files section — file list items (compact variant)
  6. Repository sync status (bottom of scroll)

**Quick Actions row:**
- 4 chips in a horizontal scroll (no scrollbar, paging not needed)
- Each chip: icon (24pt, SF Symbol) + label (13pt Footnote), bg/secondary, radius-full, 48pt tall
- Actions: "Import" (square.and.arrow.down), "Compose" (square.and.pencil), "Share" (square.and.arrow.up), "Scan" (camera.viewfinder)
- Horizontal padding: 16pt each side, 8pt between chips

**Recent Files section:**
- Section header: "Recent" in 22pt Title 2, left-aligned, with "See All" trailing link (15pt Subheadline, color/text/link)
- Horizontal scroll of file thumbnail cards: 120x160pt each, radius-md, shadow-sm
- Each card: thumbnail + file name (13pt truncated) + sensitivity badge at bottom-left + last-modified (11pt Caption 2, Text Tertiary)

**AI Suggested section:**
- Section header: "Suggested" + wand.and.stars icon (14pt, color/brand/primary)
- Horizontal scroll of AI Suggestion Cards (as described in component library)

**Offline Files section:**
- Section header: "Offline" + wifi.slash icon
- Vertical list of File List Items (compact variant, max 3 shown, "Show All" link)
- If no offline files: inline empty state (mini version, just icon + text, no button)

**States:**
- Empty (first run): greeting message "Welcome to XQ. Import a file to get started.", large illustration, Import + Connect buttons
- Loading: skeleton states for each section
- Offline: offline status banner at top, recent files still visible (from cache), cloud-connected sections dim out
- Risk present: risk alert card at very top, elevated with spring animation

**Animation behaviors:**
- On tab switch to Home: all sections stagger in (40ms between sections)
- Risk alert card: spring-bouncy entry from top if a new risk appears while on screen
- Quick action chip tap: spring scale feedback
- File thumbnail tap: expand animation (thumbnail grows to full screen with matched geometry, shared element transition)

**iPhone vs iPad:**
- iPad: 2-column layout for Recent Files and Offline sections. Quick Actions become a 2-row grid. Risk alert card spans both columns.

**Accessibility:** Section headers are announced. File thumbnails have accessible labels including classification. Risk alerts are announced immediately as they appear.

---

### Screen 6: Repository / File Browser

**Purpose:** Primary file navigation. Second most-used screen.

**Layout Structure (iPhone):**
- Navigation bar: current folder name (inline), back arrow, trailing: magnifying glass (search), ellipsis.circle (filter/sort menu), plus (upload/new folder)
- Repository switcher: horizontal scroll of repository source pills at top of content — "SharePoint", "Network Drive", "Local Vault" + add icon
- Content: file list (List View, default) or grid (Grid View, toggle via toolbar)
- Bottom toolbar: "Select" button, view toggle, sort label

**List view:**
- File List Item components, full width
- Section headers for folders ("Folders", "Documents", "Images") with count
- Standard iOS separator lines between items

**Grid view:**
- 3 columns on iPhone (each tile ~115pt wide), 4 columns on iPad
- Document Thumbnail components with classification overlay
- Long press: selection mode (same as List view)

**Search state:**
- Search bar expands full width (standard iOS UISearchBar behavior)
- Results appear with matched text highlighted (15pt Subheadline, brand-primary for match highlight)
- Scope buttons: "All", "Files", "Folders", "Shared"
- No results: empty state component

**Selection mode:**
- Checkbox appears on leading side of each item (circular, brand-primary fill when selected)
- Bottom bar replaces tab bar: "Share", "Download Offline", "Delete" actions
- "X items selected" count in navigation bar

**States:**
- Empty repository: empty state component ("No files in this folder")
- Loading: skeleton state (6-8 skeleton file items)
- Offline: offline banner, only offline-cached files shown, others grayed out with wifi.slash overlay
- Error (connection failed): error card with retry button

**Animation behaviors:**
- New files appearing (after sync): items insert with opacity 0 → 1, y +16pt → 0, 250ms easeOut
- File tap to open: matched geometry transition (the thumbnail expands to become the file viewer)
- Selection mode: checkboxes slide in from leading edge, 150ms easeOut, staggered 20ms per visible row
- View toggle (list to grid): cross-dissolve 300ms

**iPad SplitView:**
- Leading column (320pt): file list / sidebar
- Trailing column: file viewer or empty state ("Select a file to view it")
- Sidebar shows breadcrumb path at top
- File tap: populates detail pane (no navigation push — side-by-side persistent)
- Sidebar can collapse to compact on smaller iPad orientations

**Accessibility:** Files have accessible labels: "Quarterly Report Q3, PDF, Confidential, last modified 3 days ago, not offline." Swipe actions are accessible via VoiceOver actions menu.

---

### Screen 7: Secure File Viewer

**Purpose:** Protected in-app document rendering.

**Layout Structure:**
- Full-screen immersive view (navigation bar auto-hides on scroll)
- Tap to show/hide chrome (like Photos app behavior)
- Navigation bar (when visible): file name truncated to ~20 chars (15pt Subheadline), back arrow, trailing: "Share" (square.and.arrow.up), "Edit" (pencil), "More" (ellipsis.circle)
- Sensitivity label: persistent, overlaid in top-right of content canvas (not in nav bar) — uses Sensitivity Badge component, always visible regardless of chrome show/hide
- Watermark: diagonal text overlay across document content, dynamically generated from username + timestamp + classification level, opacity 0.07 for Public/Internal, 0.15 for Confidential, 0.25 for Restricted
- Policy indicators: bottom safe area bar (persistent) showing active restrictions: "View Only", "No Screenshot", "No Forwarding" as Policy Indicator Chips

**Document canvas:**
- PDF: standard PDF rendering within the secure viewer (no system Quick Look)
- DOCX: rendered view (read mode)
- XLSX: table rendering
- Images: pinch/zoom enabled, 60 FPS smooth

**AI Classification Panel (slide-up):**
- Triggered by tapping the sensitivity badge
- Bottom sheet, 50% screen height
- Shows: classification level (large badge), confidence score (80% is high), detected data types (PII detected, Financial data detected — shown as Policy Indicator Chips), "Why was this classified this way?" expandable section, "Override classification" button (visible if user has rights)

**Restricted file state (view-only enforced):**
- Editing controls hidden
- Share button grayed and disabled
- Watermark at maximum opacity
- Banner at top: Risk Alert Card Info variant — "View-Only Access: Enterprise policy prevents editing and sharing this document."

**States:**
- Default: document content displayed
- Restricted: view-only mode
- Loading document: skeleton gradient in document canvas area
- Screenshot attempt: blur overlay + "Screenshot not permitted" toast
- Screen recording active: persistent red banner at top "Screen recording detected — content protection active"

**Animation behaviors:**
- Entry: matched geometry transition from file thumbnail (the thumbnail expands to fill the screen)
- Chrome show/hide: opacity + translateY, 200ms easeOut
- AI panel: bottom sheet slide-up 350ms spring-snappy
- Sensitivity badge tap: scale 1.05 pulse, then panel appears
- Screenshot blur: instant (0ms delay, critical security behavior)

**iPad:** In SplitView, the file viewer occupies the trailing pane (no full-screen transition needed). Navigation bar remains visible at all times. AI panel appears as a sidebar panel rather than a bottom sheet.

**Accessibility:** Document content read by VoiceOver with proper semantic structure. Policy restrictions announced when viewer opens. Sensitivity announced as first element.

---

### Screen 8: Document Editing

**Purpose:** Lightweight in-secure-container editing.

**Layout Structure:**
- Navigation bar: file name, "Cancel" (left, opens discard confirmation), "Save" (right, primary style)
- Editing toolbar (below nav bar, sticky): formatting controls (Bold B, Italic I, Underline U, separator, list icon, indent, outdent) — 44pt tall, bg/secondary background, hairline bottom border
- Content: native text editor (UITextView or equivalent) with custom secure container wrapper
- Bottom: character count or word count in 11pt Caption 2, Text Tertiary
- AI re-scan indicator: appears when significant content changes detected — compact inline chip in editing toolbar area: "AI scanning..." → "Reclassified: Confidential" (appears if classification changes, with animation)

**Word document editing:**
- Font formatting options in toolbar
- Comment thread support (inline margin indicators)
- Track changes indicator if enterprise enabled

**Excel editing:**
- Grid/cell-based editor
- Cell editing bar below toolbar (shows formula or cell value)
- Column/row resize handles

**Post-save behavior:**
- Saving indicator in navigation bar right (replacing Save button): spinner then checkmark
- AI rescan confirmation: "Document rescanned — classification updated" toast at bottom, auto-dismiss 3s

**States:**
- Clean (no edits): Save button grayed out
- Dirty (edits made): Save button active (brand-primary)
- Saving: spinner in Save position
- Saved: checkmark, 1s, then returns to Viewer
- Error: error toast, Save button returns to active

**Animation behaviors:**
- Save tap: button scale spring feedback, spinner appears replacing text with crossfade
- Checkmark success: checkmark draws (strokeEnd animation) then fades out, 600ms total
- AI classification chip: slides in from trailing edge 250ms easeOut

**iPad:** Editing toolbar may expand to show more formatting options (sufficient horizontal space).

---

### Screen 9: Secure Share Workflow

**Purpose:** 4-step governed sharing. Presented as a bottom sheet.

**Layout Structure (bottom sheet, ~85% screen height):**
- Handle bar: centered, 36x4pt, bg/tertiary, radius-full
- Navigation (internal to sheet): "Back" text (left, appears on steps 2+), step title (center, inline), step indicator "1 of 4" (right, 13pt Footnote)
- Step content changes, all animated with horizontal push transitions between steps

**Step 1 — Choose Recipients:**
- Search field at top: "Add people or groups" placeholder
- Recipient suggestions list (contacts + recent + groups)
- Selected recipients shown as Share Recipient Pill components in a wrapping token field
- "Next" primary button at bottom

**Step 2 — Share Method:**
- 3 option tiles (vertically stacked, 80pt each, radius-lg, border-thin):
  - "Secure Link" — link SF Symbol — "Best for external recipients. Link-based, expirable."
  - "Secure Attachment" — paperclip SF Symbol — "Send as encrypted attachment via email."
  - "SharePoint Share" — microsoft icon — "Share via SharePoint permissions (internal)."
- AI recommendation badge on the recommended option: wand.and.stars 12pt + "AI Recommended" text in 11pt brand-primary — floats above the tile's top-right corner

**Step 3 — Security Settings:**
- AI Risk Summary card: Risk Alert Card component (Info or Warning depending on risk level) — always shown. If no risk: "AI reviewed: Low risk. No restrictions recommended."
- Settings toggles:
  - Expiration: date picker inline (or "None")
  - View Only: toggle (may be forced on by policy — grayed with lock icon + "Policy enforced")
  - Require authentication: toggle
  - Notify on access: toggle

**Step 4 — Confirm & Send:**
- Summary card: recipient pills, share method icon, settings summary in 13pt
- "Send Securely" destructive-green button (full width, brand-secondary color, white text)
- "Back to Edit" tertiary text link below

**States:**
- External recipient detected: recipient pill changes to external variant (amber), AI risk summary escalates to High risk
- Policy blocks share: "Send Securely" button becomes disabled, error risk card: "Policy prevents external sharing of Restricted files."
- Sending: button spinner, progress toast
- Success: checkmark animation, sheet dismisses, success toast on Home/Files screen

**Animation behaviors:**
- Sheet entry: slides up from bottom, spring-snappy 400ms
- Step transitions: horizontal push (right-to-left for Next, left-to-right for Back), 300ms easeOut
- AI risk card: if risk level changes (e.g., external recipient added), card cross-dissolves to new severity, 250ms

**iPad:** Sheet appears as a centered modal (600pt wide, detached from bottom edge), with internal columns for Steps 3+4.

---

### Screen 10: Local File Import

**Purpose:** Bring external files into the secure workspace.

**Layout Structure:**
- Presented as full-screen modal sheet
- Navigation bar: "Import File" (inline), "Cancel" (left), no right action
- 4 source tiles in a 2x2 grid (full width, 2 columns):
  - Files App (folder SF Symbol, bg/tertiary tile)
  - Camera Roll (photo SF Symbol)
  - Scan Document (camera.viewfinder SF Symbol)
  - Downloads (arrow.down.circle SF Symbol)
- Each tile: 160x120pt, radius-lg, border-thin, icon (40pt) + label (15pt Subheadline, centered)

**After selection (file picked or camera taken):**
- File preview card appears at center-top (file thumbnail, 100x130pt, shadow-md, radius-md)
- File metadata: filename (17pt Headline), size (13pt Footnote, Text Secondary), detected type
- AI analysis section (below preview):
  - "AI is scanning..." → animated shimmer in the analysis area while running
  - On complete: classification badge appears with animation (spring-bouncy scale)
  - Detected data types: chips row (PII, Financial, etc.)
  - Suggested destination: "Suggested Folder: /Projects/Q3" as a tappable row (change folder arrow)
  - Related files: horizontal scroll of 2-3 file thumbnails with "Related Files" header

**Confirm area:**
- Selected destination folder (tappable to change): 56pt row, folder icon, path text
- "Import Securely" primary button: imports and encrypts immediately
- "Import to Vault Only" secondary button: no repository upload, local secure vault only

**States:**
- Scanning: shimmer in AI section
- Low risk: success badge, brief import action available immediately
- High risk: risk alert card, "Are you sure? This document contains PII." — user must confirm

**Animation behaviors:**
- Source tile tap: spring scale feedback, then iOS file picker or camera appears
- File return: file preview card animates in from bottom (y +200pt → 0, opacity 0 → 1, spring-soft, 450ms)
- AI analysis reveal: shimmer runs, then items stagger in on completion (badge, chips, suggestion, related files each with 60ms stagger)
- Classification badge appearance: spring-bouncy pop from scale 0 → 1.1 → 1.0

---

### Screen 11: AI Document Scanner

**Purpose:** Physical document capture with AI classification.

**Layout Structure (full screen, camera viewfinder):**
- Camera viewfinder: edge-to-edge, portrait orientation
- Corner guides overlay: 4 corner markers (L-shaped, 40pt each side, 2pt stroke, white) indicating document scan area
- Top overlay bar (semi-transparent dark): back button (left), "Scan Document" title (center), flash toggle (right)
- Bottom overlay bar (semi-transparent dark, 160pt tall):
  - Center: capture button — 70pt diameter, white outer ring (3pt), white filled inner circle (52pt), spring animation on tap (scale 1.0 → 0.90 → 1.0)
  - Left: thumbnail of last captured page
  - Right: document count badge if multiple pages

**Post-capture processing view:**
- Camera view replaces with captured image
- Overlay animation: scanning lines move vertically (2 lines, 2pt, brand-primary, 60% opacity, moving from top to bottom in 1.2s, loop while scanning)
- AI overlay chips appear as detected: "PII Detected" in restricted/rose color appears with spring pop when PII is found during scan
- Classification badge appears when analysis complete

**Results panel (slides up from bottom, 50% screen height):**
- Captured image thumbnail (left), classification badge (right of thumbnail)
- Detected data list: rows of detected data types (label + confidence %)
- Destination folder suggestion
- Action buttons: "Add to Vault", "Share Securely", "Cancel"

**States:**
- Initial: camera view with guides
- Capturing: shutter animation (white full-screen flash, 100ms, fades out 200ms)
- Processing: scan line animation, detected items appear dynamically
- Complete: results panel slides up

**Animation behaviors:**
- Corner guide pulse: scale 0.95 → 1.0 → 0.95, 1.5s period, while waiting for capture (guides breathe to indicate readiness)
- Detection pop: each detected data type chip appears from scale 0 → 1.1 → 1.0, spring-bouncy
- Results panel: slides up 400ms spring-snappy

**iPad:** This screen is iPhone-only (camera scanner use case is phone-centric). On iPad, a simplified "Import from Camera" action uses the standard camera picker.

**Accessibility:** Camera permission explanation provided. Alternative text entry provided for accessibility needs. VoiceOver reads detection results as they appear.

---

### Screen 12: Secure Email Inbox

**Purpose:** Protected enterprise email experience.

**Layout Structure:**
- Navigation bar: "Inbox" large title (Email account name as subtitle, 13pt Footnote, Text Secondary), trailing: compose button (square.and.pencil), filter button (line.3.horizontal.decrease.circle)
- Inbox list: full-width email rows, using a modified file list item adapted for email

**Email row anatomy:**
- Height: 88pt (taller than file rows to accommodate email-specific info)
- Leading: sender avatar (36pt circle, initials if no photo), 16pt from leading
- Unread indicator: 8pt blue dot, leading edge of avatar area (brand-primary)
- Title row: sender name (17pt Semibold, Text Primary) + time (13pt Footnote, Text Secondary, trailing)
- Subject: 15pt Subheadline, Text Primary (truncated to 1 line)
- Preview: 13pt Footnote, Text Secondary (truncated to 1 line)
- Badges area (below preview): sensitivity badge (if non-Public), attachment badge (paperclip + count), risk badge if flagged
- Trailing: chevron.right (13pt, Text Tertiary)

**AI Risk Flag:**
- High-risk emails get a vertical left border: 3pt, risk/high or risk/critical color
- Risk flag chip: "AI: External Sender + Sensitive Content" in Risk Alert Card (inline, info variant) shown for the first risky email in list

**Account switcher (for multiple email accounts):**
- Appears as horizontal pill tabs below the search bar (iOS-style filter bar)

**States:**
- Empty inbox: empty state component
- Loading: skeleton email rows (5 rows, 88pt each)
- Offline: banner, no new email can be loaded (shows last cached)
- All read: standard clean inbox
- Risk flagged: risky rows have the left accent border

**Animation behaviors:**
- Swipe trailing: archive (left swipe) = check mark action, delete = trash action
- Swipe leading: flag as important (right swipe)
- New email arrival: row inserts at top with slide-in from top + opacity animation (spring-snappy)
- Read/unread toggle: blue dot fades out (opacity 0, 200ms) when tapped

**iPad:** SplitView — email list in sidebar (320pt), email content in detail pane. No separate email viewer screen needed on iPad.

---

### Screen 13: Compose Secure Email

**Purpose:** Governed email composition with real-time AI scanning.

**Layout Structure:**
- Full-screen modal with keyboard-aware layout
- Navigation bar: "New Message" (inline, bold), "Cancel" (left), "Send" (right — disabled until all required fields complete)
- Fixed header fields (non-scrolling):
  - To: field — recipient pill input (Share Recipient Pill components)
  - CC: field (collapsible, "Cc/Bcc" button to expand)
  - From: selector (if multiple accounts linked, dropdown)
  - Subject: text input (17pt)
- Separator (hairline)
- Message body: UITextView, grows with content, minimum 200pt
- Attachment bar (appears when attachment added): horizontal scroll of attachment chips below body
- Keyboard toolbar (above keyboard): formatting options + "Attach" + "Secure Options" button

**AI Risk Bar (persistent, above keyboard toolbar when risk detected):**
- 48pt tall strip, animates in from bottom when AI detects risk
- Color matches risk level: risk/high or risk/critical for background
- Text: "AI: External recipient with sensitive content — encryption recommended" + "Settings" link
- Dismiss: xmark button (dismisses current warning but AI continues scanning)

**Secure Options panel (sheet):**
- Triggers from "Secure Options" button in keyboard toolbar
- Shows: Expiration toggle + date, Restrict forwarding toggle, Require authentication for recipient toggle, Preview label of current classification

**Send button behavior:**
- Grayed out: required fields missing
- Active: typing complete
- Blocked (policy prevents send): Send button shows lock icon overlay, tap shows explanation risk card
- Loading (sending): spinner in button position

**States:**
- Draft: standard compose
- AI scanning (ongoing): subtle animated shimmer in subject/body area (very subtle, does not distract)
- Risk detected: AI risk bar slides in from bottom
- Send blocked: Send button locked
- Sending: spinner, keyboard dismisses

**Animation behaviors:**
- AI risk bar entry: slides up from bottom 300ms easeOut
- Recipient pill addition: pill bounces in with spring-bouncy (scale 0 → 1.1 → 1.0)
- External recipient pill change: internal → external variant with color crossfade 200ms + warning icon appears

**iPad:** Compose appears in a popover-style or side-panel (not full screen) when triggered from inbox sidebar.

---

### Screen 14: Notifications & Security Events

**Purpose:** Centralized awareness hub.

**Layout Structure:**
- Navigation bar: "Notifications" (large title), trailing: "Mark All Read" text button (disabled if all read), filter icon
- Sections: grouped by type with section headers
  - "Active Risks" section (if any unresolved risks)
  - "Today" section
  - "Earlier" section

**Notification row anatomy:**
- Height: varies by content (min 72pt)
- Leading: category icon in colored circle (28pt icon in 44pt circle): risk (exclamationmark.triangle, orange/red), policy (shield.lefthalf.filled, brand-primary), sync (arrow.2.circlepath, success), AI (wand.and.stars, brand-primary)
- Unread indicator: 10pt dot, brand-primary, leading (appears between icon and edge)
- Title: 15pt Subheadline Semibold, Text Primary
- Description: 13pt Footnote, Text Secondary, wraps to 2 lines max
- Time: 11pt Caption 2, Text Tertiary, trailing
- Action row (for actionable notifications): inline text buttons "View File", "Resolve", "Dismiss" in 13pt Footnote, brand-primary

**"Active Risks" section:**
- Shown at top only when unresolved critical/high risks exist
- Rows use left accent bar (matching Risk Alert Card severity colors)
- Swipe to resolve or dismiss

**States:**
- Empty: empty state ("No Notifications — your workspace is quiet.")
- All read: standard list with dimmed unread indicators
- New notification arriving: row inserts at appropriate section position with spring entry

**Animation behaviors:**
- On appear: rows stagger in (40ms between each, max 200ms total stagger)
- Resolve action: row collapses with scale 0.92 + opacity 0 exit animation, 250ms
- "Mark All Read": unread dots fade out across all rows simultaneously, 300ms stagger per row (10ms between rows)

**iPad:** Full-width layout, notification rows expand to readable width (max 680pt). Optional right panel showing event detail on selection.

---

### Screen 15: Sharing Center

**Purpose:** Manage active shares, links, and recipient access.

**Layout Structure:**
- Navigation bar: "Shares" (large title), trailing: filter + sort icon
- Segmented control below title (or scoped tabs): "Shared by Me" | "Shared with Me"
- File list adapted to show shared files

**Shared file row anatomy:**
- Height: 88pt
- Thumbnail: 40x54pt, leading
- File name: 17pt Semibold, Text Primary
- Recipients: avatar stack (3 overlapping 24pt circles) + "and 2 more" text
- Share method chip: "Secure Link" or "SharePoint" in Policy Indicator Chip style
- Expiration: if set — clock SF Symbol + "Expires in 2 days" in 13pt Footnote, color changes to risk/high when < 24hrs
- Trailing: chevron

**Shared file detail (tapped row — bottom sheet or navigation push):**
- File preview (thumbnail)
- All recipients as Recipient Pills
- Share settings summary (permissions, expiration, view-only status)
- Action buttons:
  - "Revoke All Access" (destructive)
  - "Extend Expiration"
  - "Change Permissions"
  - "View Activity Log"

**Expiration timer:**
- For near-expiry (< 24hrs): amber warning chip, pulsing subtle animation
- For expired: gray chip, "Expired" text, "Renew" button

**States:**
- Empty: empty state "Nothing Shared Yet"
- No active links: shows empty links section
- Expired shares section: collapsed by default, expandable

**Animation behaviors:**
- Revoke action: confirmation dialog (native UIAlertController equivalent), on confirm: row exits with scale + opacity exit, 300ms. Success haptic.
- Expiring soon row: the expiration chip pulses (opacity 0.6 → 1.0 → 0.6, 2s period) while near expiry

**iPad:** 3-column layout possible (files, recipients, permissions panel). Full master-detail split.

---

### Screen 16: Enterprise Policy Management (Admin Only)

**Purpose:** Configure governance policies. Admin-only screen.

**Layout Structure:**
- Navigation bar: "Policy Management" (inline, bold), admin role indicator badge, trailing: "Save Changes" button (disabled until edits made)
- Grouped sections in a scrollable form (iOS Settings-style grouped table):

**Section 1 — Classification Labels:**
- "Classification Scheme" header
- Each label as a row: colored dot (classification color) + label name + AI threshold slider summary + chevron (drill into label config)
- "Add Custom Label" row with plus icon

**Section 2 — Sharing Policies:**
- "Allow External Sharing" toggle
- "Default Expiration" disclosure row (sub-setting)
- "Require MFA for External" toggle
- "Geofencing" disclosure row (map-based config drill-in)
- "Block Restricted External" toggle (forced on, shows lock icon + "Cannot be changed")

**Section 3 — Runtime Protection:**
- "Enforce Screenshot Blocking" toggle (forced on for enterprise)
- "Disable Offline Mode" toggle
- "Restrict Copy/Paste" toggle
- "Watermark All Documents" toggle + intensity slider when on

**Section 4 — AI Governance:**
- "AI Confidence Threshold" slider (40% → 95%, with labels)
- "Allow User Overrides" toggle (with sub-setting for override logging)
- "Escalation Behavior" disclosure row (warn → block → require admin approval)

**States:**
- Viewing (no changes): Save disabled, everything readable
- Editing: changed rows highlight with brand-primary-dim tint, Save button activates
- Saving: spinner in Save button, slight form dimming
- Conflict (policy locked by enterprise): lock icon on row, grayed, tooltip on tap

**Animation behaviors:**
- Toggle change: standard UISwitch animation + dependent sub-rows slide in/out with 200ms easeOut
- Slider: real-time percentage label updates as drag moves
- Locked policy tap: brief shake animation (lateral oscillation, ±4pt, 3 cycles, 300ms total) + tooltip appears

**iPad:** Two-column layout — policy categories in sidebar (250pt), settings for selected category in detail pane.

---

### Screen 17: Audit & Activity (Admin Only)

**Purpose:** Enterprise audit visibility.

**Layout Structure:**
- Navigation bar: "Audit Log" (large title), trailing: export button (square.and.arrow.up) + filter button
- Search bar below navigation bar
- Filter bar (horizontally scrollable chips): "All Events", "File Access", "Sharing", "Policy Violations", "Device Events"
- Event list (date-grouped)

**Event row anatomy:**
- Height: 72pt
- Leading: category icon in colored circle (same icon/color scheme as Notifications) — 44pt
- Event description: 15pt Subheadline Semibold, Text Primary, 1 line
- Sub-detail: "User: john@company.com • File: Q3Report.pdf" — 13pt Footnote, Text Secondary, 1 line
- Time: 11pt Caption 2, Text Tertiary, trailing
- Risk indicator: small colored dot on the event icon circle frame for policy violations

**Filter panel (slides in from trailing):**
- Date range picker
- User filter (text search)
- Event type checkboxes
- File/folder search
- "Apply Filters" button

**Export:**
- Exports filtered log as CSV or PDF
- Secure share workflow appears (must go through governed export)

**States:**
- Loading: skeleton rows (8 rows)
- No results: empty state with filter icon ("No events match your filters")
- Search active: results highlighted

**Animation behaviors:**
- Filter chip toggle: spring scale feedback, then list refreshes with cross-dissolve 250ms
- Filter panel: slides in from trailing edge, existing content shifts (or dims behind panel)

**iPad:** Filter panel is a persistent sidebar (not a slide-in panel). Timeline data may show a simple chart above the log.

---

### Screen 18: Settings

**Purpose:** App configuration and account management.

**Layout Structure:**
- Navigation bar: "Settings" (large title), trailing: user avatar/initials (tappable → account sheet)
- Grouped table view (iOS Settings visual style):

**Account section:**
- User avatar (56pt), name (17pt Semibold), email (13pt Footnote), "Edit Profile" button
- SSO status: "Connected via Microsoft Entra" or "Local Account"
- Device registration status

**Security section:**
- "Face ID / Touch ID": toggle
- "Session Timeout": disclosure row (5 min, 15 min, 1 hour, Never)
- "App Lock": toggle (lock on background switch)
- "Change PIN": disclosure row (if PIN enabled)

**Offline Storage section:**
- "Offline Cache" size display (e.g., "234 MB used")
- "Clear Offline Cache": destructive action row
- "Default Offline Folders": disclosure row
- "Auto-Offline": toggle (mark all for offline automatically — disabled in enterprise if policy prevents)

**AI Governance section:**
- "AI Sensitivity Level": segmented control (Low / Medium / High) or slider
- "Privacy Mode": toggle (disables cloud AI, local-only mode)
- "Show AI Suggestions": toggle

**Repository Connections section:**
- List of connected repositories with status indicators (green dot = connected, red = error)
- "Add Repository": row with plus icon
- Swipe to remove a repository

**Notifications section:**
- "Risk Alerts": toggle
- "Sync Status": toggle
- "AI Recommendations": toggle
- "Notification Frequency": disclosure row

**About section:**
- Version and build number (13pt Footnote, monospace)
- "Terms of Service", "Privacy Policy" links
- "Contact Support" row
- "Export Diagnostics": admin-only row
- "Force Update Check" row

**States:**
- Enterprise-managed settings: policy-locked rows show lock icon, grayed, "Managed by your organization" caption
- Consumer free tier: some rows show "Upgrade to Enterprise" indicator

**Animation behaviors:**
- Each settings section staggered in on first appear
- Toggle changes: standard UISwitch with immediate visual feedback

**iPad:** iPad uses a master-detail split — settings categories in sidebar, section content in detail pane.

---

## 8. INTERACTION FLOW MAP

```
LAUNCH
  └── Splash/Init (Screen 1)
        ├── [First Launch] → Welcome/Onboarding (Screen 2)
        │     ├── [Local First] → Permissions Setup (Screen 4) → Home (Screen 5)
        │     └── [Enterprise] → Repository Setup (Screen 3) → Permissions (Screen 4) → Home (Screen 5)
        └── [Returning] → Home (Screen 5)

TAB BAR (persistent from Screen 5 onward)
  ├── Home (Screen 5)
  │     ├── File thumbnail tap → File Viewer (Screen 7)
  │     ├── Quick Action: Import → Local File Import (Screen 10)
  │     ├── Quick Action: Compose → Compose Email (Screen 13)
  │     ├── Quick Action: Share → Secure Share Workflow (Screen 9, modal)
  │     ├── Quick Action: Scan → AI Document Scanner (Screen 11, modal)
  │     ├── Notification bell → Notifications (Screen 14)
  │     └── Risk card "View" → File Viewer (Screen 7) or relevant screen
  │
  ├── Files (Screen 6)
  │     ├── File tap → File Viewer (Screen 7)
  │     │     ├── Edit button → Document Editing (Screen 8)
  │     │     ├── Share button → Secure Share Workflow (Screen 9, modal)
  │     │     └── Sensitivity badge tap → AI Classification Panel (inline sheet)
  │     ├── Folder tap → Files (Screen 6, drill in, push navigation)
  │     ├── Plus button → Local File Import (Screen 10, modal)
  │     └── File swipe trailing → Secure Share Workflow (Screen 9, modal)
  │
  ├── Email (Screen 12)
  │     ├── Email row tap → Email Detail View (inline, or Screen 12 detail pane on iPad)
  │     │     └── Attachment tap → File Viewer (Screen 7, modal)
  │     └── Compose button → Compose Email (Screen 13, modal)
  │           └── Attachment add → Local File Import (Screen 10, modal)
  │
  ├── Shares (Screen 15)
  │     ├── Share row tap → Share Detail (bottom sheet)
  │     │     ├── Revoke → Confirmation → Shares (Screen 15, row removed)
  │     │     └── View Activity → Audit (Screen 17, admin) or limited view
  │     └── [empty state] Share button → Files (Screen 6)
  │
  └── Settings (Screen 18)
        ├── Repository Connection → Repository Setup (Screen 3, edit mode)
        └── [Admin] Policy Management link → Policy Management (Screen 16)
            [Admin] Audit Log link → Audit (Screen 17)

ADMIN EXCLUSIVE FLOWS
  Settings → Policy Management (Screen 16)
  Settings → Audit & Activity (Screen 17)
  [These tabs are hidden/inaccessible to non-admin users]
```

### Connection types:
- Tab switch: crossfade transition
- Navigation push: horizontal slide (NavigationStack)
- Modal sheet: bottom sheet rise
- Full screen modal: sheet rise + 3D card effect on presenting view

---

## 9. PROTOTYPE STRATEGY

### 9.1 Five Priority Flows for Interactive Prototype

**Flow 1: Onboarding to Home (Screens 1 → 2 → 4 → 5)**
- Demonstrates zero-friction first run
- Shows the AI-guided setup narrative
- Ends at the Home Dashboard with a populated state
- Key interactions: onboarding swipe, path selection, permission grant, Home dashboard exploring

**Flow 2: File Discovery and Secure Viewing (Screens 5 → 6 → 7 → 9)**
- Most critical daily workflow
- Demonstrates: browsing files, sensitivity badges, secure viewer, share workflow
- Key interactions: tap file, view with classification panel, tap Share, complete 4-step share workflow, see AI risk evaluation
- Shows both Public (unrestricted) and Confidential (restricted) file states

**Flow 3: Local Import with AI Classification (Screens 10 → 11 → File Viewer)**
- Demonstrates AI governance in action
- Import a photo from camera roll → AI detects PII → classification badge appears → file stored in vault
- Shows the "AI works invisibly" principle
- Key interaction: camera capture → AI scan animation → classification result

**Flow 4: Secure Email Compose with Risk Detection (Screens 12 → 13)**
- Enterprise security narrative
- Start in inbox → compose email → add external recipient → AI risk bar appears → secure options applied → send
- Shows: risk-proportionate interruption, external recipient warning, encryption enforcement

**Flow 5: Admin Policy Configuration (Screens 16 → 17)**
- Enterprise admin narrative
- Shows policy management, classification configuration, and audit log review
- Demonstrates role-based UX difference (admin sees what standard users never see)
- Key: toggle policies, see impact indicators, navigate to audit log, apply filters

### 9.2 Prototype Fidelity Level

All 5 flows should be built at **high fidelity** with:
- Smart Animate for all transitions (Figma Smart Animate preserves layer names for smooth motion)
- Realistic content (actual filenames, email subjects, classification labels — not Lorem Ipsum)
- Both light and dark mode variants (use Figma variables + modes to switch)
- Correct delays on multi-step animations (using Figma's animation delay settings)

### 9.3 Sharing Plan

- Share via Figma presentation mode (link sharing to specific start frames)
- Create separate prototype flows for each of the 5 flows
- Provide one "full app exploration" prototype starting from Home for open-ended demos
- Embed in a shared Figma project with view-only access for stakeholders
- Include a comments layer with implementation notes visible to developers

---

## 10. DARK MODE STRATEGY

### 10.1 What Changes

**Backgrounds:** All backgrounds invert to the dark palette. The layering system (primary → card → elevated) is maintained through lightness steps rather than the flat-to-shadow approach used in light mode.

**Text:** Text colors shift using the adaptive tokens. Text Primary in dark mode is pure white (#FFFFFF). Secondary text drops to 60% opacity white. This is native iOS behavior and should be handled via semantic color tokens — not hardcoded hex pairs.

**Sensitivity Badges:** The badge background becomes a very dark tint of the classification color (near-black with hue). The badge text becomes the full-saturation classification color. This maintains legibility without the pastel-on-white appearance that would be invisible on dark backgrounds.

**Shadows:** Shadows become transparent in dark mode. Elevation is expressed purely through background lightness steps (see color token table).

**Glass surfaces:** The glassmorphism blur effect shifts to `.systemUltraThinMaterialDark` which produces a dark-tinted glass. Stroke shifts to 10% white opacity.

**Icons (SF Symbols):** SF Symbols adapt automatically using secondary/tertiary label colors. Custom XQ icons need explicit dark mode variants.

**Progress bars, toggles, sliders:** Use system semantic colors where possible — these adapt automatically.

### 10.2 What Stays the Same

**Brand Primary:** The XQ brand color shifts slightly (from #3D5AFE to #6979F8) but maintains the same hue identity. The logo remains the same.

**Sensitivity badge classification level:** The color family (green for Public, blue for Internal, amber for Confidential, rose for Restricted) remains consistent — only the implementation (background/text pairing) inverts.

**Tab bar active state:** Brand primary continues to denote the active tab.

**Risk colors:** Critical red, high orange, medium amber — these maintain their semantic meaning. Only their background tints (dim variants) change to near-black tints.

**Watermark overlays:** Opacity values remain the same. The watermark text color shifts to a light value visible on dark document backgrounds.

### 10.3 Sensitivity Label Contrast in Dark Mode

Contrast requirements (WCAG AA: 4.5:1 for text under 18pt):

| Classification | Dark BG Hex | Dark Text Hex | Contrast Ratio | Compliant |
|---|---|---|---|---|
| Public | #0A2510 | #4CAF50 | 7.2:1 | Yes |
| Internal | #0A1929 | #64B5F6 | 6.8:1 | Yes |
| Confidential | #1F1500 | #FFB300 | 9.1:1 | Yes |
| Restricted | #1A0009 | #F06292 | 5.2:1 | Yes |
| Custom | #120A1E | #CE93D8 | 5.8:1 | Yes |

All classification badges meet WCAG AA contrast requirements in both light and dark mode.

### 10.4 Figma Dark Mode Implementation

Use Figma Variables (the token system) with two modes: "Light" and "Dark". All components reference variables, not hardcoded hex values. Toggling the mode on any frame instantly produces the correct dark mode output. Build all 18 screens with both modes represented — either as duplicate frames side-by-side or using the Figma dark mode frame toggle.

---

## 11. ENTERPRISE VS CONSUMER UX VARIANTS

### 11.1 Standard User UX

The standard user interface is intentionally minimal. Security governance is entirely ambient:

**What they see:**
- Home, Files, Email, Shares, Settings tabs (5 tabs)
- Sensitivity badges on files (small, consistent placement, non-interactive except for "why" explanation)
- AI Suggestion Cards (dismissible, non-demanding)
- Risk alerts only when a decision is needed (rare, proportionate)
- Policy Indicator Chips (read-only, no controls)
- No policy configuration of any kind
- No audit log (no link, no tab, not discoverable)
- Settings: limited to personal preferences (Face ID, notifications, offline storage, AI sensitivity preference, account)

**What they do NOT see:**
- Policy Management screen
- Audit & Activity screen
- AI threshold configuration
- Classification schema management
- User access management
- AI tuning controls
- Governance analytics

### 11.2 Enterprise Admin UX

Admin users see everything standard users see, plus:

**Additional UI elements:**
- Admin indicator: small purple dot + "Admin" badge in the navigation bar when on admin-relevant screens
- Settings screen: additional "Enterprise Administration" section containing links to Policy Management (Screen 16) and Audit & Activity (Screen 17)
- File browser: additional "Activity" button per file row (shows file-level audit trail)
- Sharing Center: additional "Full Audit Log" button per share
- Notification center: additional "Policy Violation" category visible and filterable
- File Viewer: "Override Classification" button visible in AI Classification Panel
- Policy enforcement overrides: toggles and controls that are grayed/locked for standard users

**Visual differentiation of admin context:**
- When navigating to admin-only screens, the navigation bar gains a subtle purple tint on the title (color/classification/custom/text) — this is the "you're in admin mode" visual signal
- No jarring "admin mode" splash or modal — just the consistent but distinct color signal

### 11.3 Role-Based Component States

For each component that varies by role:

| Component | Standard User | Enterprise Admin |
|---|---|---|
| Sensitivity Badge | Visible, read-only, tappable for explanation | Visible, tappable for explanation + Override button |
| Policy Indicator Chip | Visible, tappable for tooltip | Visible, tappable for edit/manage link |
| Risk Alert Card | Shows warning, one action ("Got it" or "Secure This") | Shows warning + "View Policy" + "Override" actions |
| Settings screen | Personal settings only | Personal settings + Enterprise Administration section |
| File Viewer toolbar | Share, Edit, More | Share, Edit, More, Activity |
| Sharing Center rows | View details only | View details + Revoke + Audit Log |

### 11.4 Figma Implementation

Create two sets of prototype flows: one starting from a "Standard User" persona, one from an "Admin" persona. Use Figma's boolean properties on components to toggle admin elements on/off rather than maintaining duplicate component sets.

---

## 12. iPad ADAPTATION RULES

### 12.1 SplitView Layout for Files Screen (Screen 6)

When horizontal size class is regular (iPad in landscape, or iPad in portrait with sufficient width):

**Master column (320pt fixed width):**
- Repository switcher pills (scrollable)
- Search bar
- Folder hierarchy (full depth browseable)
- File list with all indicators

**Detail column (fills remaining space):**
- File viewer (Screen 7) when a file is selected
- "Select a file to view it" empty state (hero empty state design) when nothing selected
- The detail column is always visible — no navigation push occurs
- Sensitivity badge, toolbar, and AI classification panel appear within the detail column
- AI Classification Panel appears as a trailing-edge sidebar (300pt) rather than a bottom sheet

**Column divider:**
- 0.5pt hairline, Separator color
- Not draggable (fixed width)

**Navigation:**
- The master column can drill into subfolders (with its own back button within the column)
- No nav push to detail — tap always populates detail column
- URL/path shown as breadcrumb in master column header (below search bar)

### 12.2 iPad SplitView for Email (Screen 12)

**Master (email list, 380pt):**
- Full email list with all indicators
- Compose button in navigation bar

**Detail (email content):**
- Email body rendered in detail column
- Attachments listed below body
- Reply/Forward in detail toolbar

### 12.3 iPad-Specific Spacing and Touch Targets

On iPad, the additional screen real estate allows for more generous spacing:

| Element | iPhone | iPad |
|---|---|---|
| Side margins | 16pt | 32pt |
| Card internal padding | 16pt | 24pt |
| List item height (default) | 72pt | 80pt |
| List item height (compact) | 52pt | 60pt |
| Button height | 50pt | 52pt |
| Quick action chip height | 48pt | 52pt |
| Section spacing | 32pt | 48pt |
| Max content width | full screen | 960pt (centered with margins) |

**Touch targets on iPad:** Apple HIG recommends 44x44pt minimum even on iPad, but since iPad usage often involves a Pencil or mouse (Stage Manager), interactive elements should be precise and not overly padded. Maintain 44pt minimum, but do not artificially inflate targets.

### 12.4 Multi-Column Layouts

Screens that change to multi-column on iPad:

| Screen | iPhone Layout | iPad Layout |
|---|---|---|
| Home | Single column scroll | 2-column (quick actions top, recent files 2-col grid, AI suggestions right panel) |
| Files | Single list + detail push | SplitView master-detail (persistent) |
| Email | Single list + push | SplitView master-detail (persistent) |
| Onboarding Path Choice | Full width cards stacked | 2 cards side-by-side |
| Permissions | Stacked cards list | 2-column card grid |
| Share Workflow | Full-width bottom sheet | Centered modal (600pt wide, detached) |
| Settings | Single grouped table | Master-detail (categories → settings) |
| Policy Mgmt (admin) | Single scrollable form | Master-detail (policy sections → detail) |
| Audit Log (admin) | Single list | List + filter sidebar (persistent) |

### 12.5 Stage Manager Compatibility

For iPad Pro users in Stage Manager (multi-window):

- The app must function in variable window sizes (from compact phone-size to near-full-screen)
- All layouts must use adaptive size classes — not hardcoded iPad-only rules
- The SplitView collapses back to single-column behavior in compact horizontal size class
- Minimum supported window width: 320pt (phone width)
- Test and spec the app at: 320pt (compact), 375pt, 428pt (standard phone), 768pt (iPad portrait), 1024pt (iPad landscape)

---

## APPENDIX A: Figma Setup Checklist

Before building screens, complete in order:

1. Set up Figma Variables for all color tokens (2 modes: Light / Dark)
2. Set up Figma Variables for all spacing, radius, and motion tokens
3. Build typography text styles (all 13 text styles)
4. Build the 9 Priority 1 components (fully variant-structured)
5. Build the 6 Priority 2 components
6. Create iPhone (390x844pt) and iPad (1024x1366pt) base frames
7. Build Screen 5 (Home) as a reference screen to validate the full system
8. Review contrast ratios for all classification/semantic colors
9. Test all components with Figma's accessibility checker
10. Build the 5 prototype flows
11. Build remaining 17 screens

## APPENDIX B: Asset Specifications for Developer Handoff

All icons: export as SVG (vector, resolution-independent)
All illustrations: SVG where possible, PNG @1x/2x/3x where raster required
Logo mark: SVG, plus PDF for print contexts
Classification badge icons: SVG, one file per classification level
All images in handoff: named according to the design token convention
Color values: provided as hex (light) and hex (dark) pairs in the handoff
Animation values: documented in SwiftUI parameter format (see Section 5.7)
Touch targets: annotated with minimum tap area callouts
Spacing: annotated using the spacing token names (not raw pixel values)

## APPENDIX C: Accessibility Audit Checklist

Before handoff completion:
- [ ] All text on colored backgrounds meets 4.5:1 contrast (normal text) or 3:1 (large text, 18pt+ regular or 14pt+ bold)
- [ ] All interactive elements have 44x44pt minimum touch targets
- [ ] All form inputs have visible labels (not just placeholder text)
- [ ] All icons have text equivalents for VoiceOver
- [ ] Focus order is logical (top-to-bottom, left-to-right for LTR)
- [ ] All classification badges are readable at xSmall Dynamic Type
- [ ] All buttons expand correctly at xxxLarge Dynamic Type (no clipping)
- [ ] Reduced motion variants documented for all animations
- [ ] All color-coded information (sensitivity, risk) also includes a text or icon indicator (not color alone)
- [ ] Error states have both color change and icon/text change (not just color)
