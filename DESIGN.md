---
name: Kaptus for iOS
description: Native, quiet, unmistakably Kaptus.
colors:
  brand-yellow: "#FFC857"
  link-light: "color(srgb 0.063 0.337 0.353)"
  link-dark: "color(srgb 1.000 0.784 0.341)"
  icon-teal: "#176B70"
  action-ink: "#171814"
  cinema-black: "#000000"
  caption-white: "#FFFFFF"
  offset-fill: "rgb(255 255 255 / 6%)"
typography:
  display:
    fontFamily: "San Francisco"
    fontWeight: 700
  title:
    fontFamily: "San Francisco"
    fontWeight: 700
  title2:
    fontFamily: "San Francisco"
  headline:
    fontFamily: "San Francisco"
  body:
    fontFamily: "San Francisco"
  subheadline:
    fontFamily: "San Francisco"
  status:
    fontFamily: "San Francisco"
    fontWeight: 500
  footnote:
    fontFamily: "San Francisco"
  caption:
    fontFamily: "San Francisco"
  reading:
    fontFamily: "San Francisco"
    fontSize: "30pt"
    fontWeight: 600
rounded:
  action: "18pt"
spacing:
  space-4: "4pt"
  space-5: "5pt"
  space-6: "6pt"
  space-8: "8pt"
  space-10: "10pt"
  space-12: "12pt"
  space-14: "14pt"
  space-16: "16pt"
  space-18: "18pt"
  space-20: "20pt"
  space-24: "24pt"
  space-28: "28pt"
components:
  button-primary:
    backgroundColor: "{colors.brand-yellow}"
    textColor: "{colors.action-ink}"
    typography: "{typography.headline}"
    rounded: "{rounded.action}"
    padding: "12pt 16pt"
  button-secondary-light:
    textColor: "{colors.link-light}"
  button-secondary-dark:
    textColor: "{colors.link-dark}"
  player-caption:
    backgroundColor: "{colors.cinema-black}"
    textColor: "{colors.caption-white}"
    typography: "{typography.reading}"
  player-offset:
    backgroundColor: "{colors.offset-fill}"
    typography: "{typography.caption}"
    padding: "6pt 10pt"
  player-resync:
    textColor: "{colors.brand-yellow}"
    typography: "{typography.subheadline}"
---

# Design System: Kaptus for iOS

## Overview

**Creative North Star: "Native, quiet, unmistakably Kaptus"**

The yellow Wordbird is the established identity. Native SwiftUI provides the structure: a large-title Home, searchable title results, grouped lists and forms, focused sheets, and a full-screen cinema player. Brand expression lives in the approved artwork, the yellow primary action, and restrained tint.

The cinema player gives the caption the center of the screen. Its black surface and white text remain stable in both appearances; ordinary app surfaces follow the system. The app targets iPhone on iOS 17 and newer. Navigation bars, sheets, controls, and their materials inherit the host iOS appearance, so a newer OS can change platform chrome without changing this system.

**Key Characteristics:**

- Approved yellow Wordbird artwork, with an opaque square iOS icon export.
- San Francisco, SF Symbols, Dynamic Type, and native Apple navigation.
- Semantic light and dark app surfaces, with a fixed black cinema surface.
- Readable captions, accessible controls, and quiet, temporary player chrome.

This is a source-based record of the native adaptation, with no approved image comp. Sources are `Kaptus/UI/Brand.swift`, the four screen files in `Kaptus/UI/`, `Kaptus/Player/PlayerView.swift`, `Kaptus/Player/PlayerSession.swift`, `Kaptus/App/KaptusApp.swift`, the asset catalog, and `docs/brand/PROVENANCE.md`.

Final simulator evidence comes from [CI run 35718030052](https://github.com/desigrit/kaptus-ios/actions/runs/35718030052), commit `9bd303fb87f22fb19e7659f1cb58d9f40d00b101`, using Xcode 26.3 (17C529), Swift 6.2.4, and iPhone 17 Pro Simulator with iOS 26.2. All 35 tests passed (24 package, 8 native, 3 UI), along with the Release build and bundled-model verification. The committed generated Xcode project byte-matches the tested generated project. All six final native captures are published in `docs/screenshots/`, with their source and SHA-256 digests in [capture evidence](docs/screenshots/evidence.json).

The independent reviewer inspected all six captures and returned **ship**, scoped to the three listed fixes: the accessibility-size Files label, cancellation of pending control hiding on Re-sync, and actionable timeout recovery copy. All three were scored resolved; the Re-sync regression test also passed. This verdict does not assert physical iPhone testing or iPad certification. The target device family remains iPhone. See [verification](docs/VERIFICATION.md) for the full evidence scope.

The frontmatter records source-defined primitives. Dimensions are native points, not physical pixels. Most text sizes, system surfaces, and native control geometry are intentionally not assigned fabricated numeric tokens. `.impeccable/design.json` extends this file with behavior metadata and illustrative HTML specimens. Its tonal ramps are generated panel aids, not colors used by the app; the specimens cannot certify SwiftUI appearance or accessibility.

## Colors

Warm yellow carries the brand while platform semantics keep ordinary screens readable in both appearances.

### Primary

- **Wordbird yellow** (`brand-yellow`): the filled primary action, player tint, acquisition status, and Re-sync action. Its source is `Brand.yellow`.
- **Light link tint** (`link-light`): the darker teal tint for small interactive text on light system surfaces. **Dark link tint** (`link-dark`): the yellow tint in dark appearance. `Brand.link` resolves the `LinkTint` asset at runtime, and `KaptusApp` applies it at the root. The asset stores rounded sRGB channels; its dark value is intentionally recorded separately from the exact `Brand.yellow` expression.

### Secondary

- **Wordbird teal** (`icon-teal`): the approved icon backdrop, evidenced by `docs/brand/app-icon.svg`. This is an artwork color, not a second general-purpose interface accent.

### Neutral

- **Action ink** (`action-ink`): the dark text on the yellow primary action.
- **Cinema black** (`cinema-black`): the player canvas and the `LaunchBackground` asset.
- **Caption white** (`caption-white`): caption text and the player Play/Pause action.
- **Offset veil** (`offset-fill`): the faint translucent backing of the signed timing adjustment.

| Native source | Ownership and use |
| --- | --- |
| `.primary` | System-resolved primary labels, including result and History titles. |
| `.secondary` | System-resolved supporting copy, metadata, and decorative symbols. |
| `.tertiary` | System-resolved disclosure symbols. |
| `List`, `Form`, native bars and sheets | System surfaces, separators, materials, focus, and selection treatment. No application hex override. |
| `.gray` in `PlayerView` | The explicitly selected SwiftUI gray for cinema controls, metadata, timing offset, and Synced status. No invented hexadecimal equivalent. |
| `.destructive` button role | Native destructive presentation, not a custom red token. |

**The Appearance Ownership Rule.** Use semantic foregrounds and system surfaces in the app. Keep black, white, and the selected control colors in the cinema player; do not turn the player into a light surface.

## Typography

**Display and body family:** San Francisco through SwiftUI system fonts. There is no bundled brand font. SF Symbols follow the native text environment. Line height, tracking, and the resolved size of named text styles belong to the platform.

| Token | Source role and use |
| --- | --- |
| `display` | `.largeTitle.bold()` for the welcome and standard Home invitation. |
| `title` | `.title.bold()` for the preparation title. |
| `title2` | `.title2` for welcome supporting text; bold for episode titles and the accessibility Home heading. |
| `headline` | `.headline` for primary actions, row titles, and Play/Pause. |
| `body` | `.body` for main explanatory copy and native form content. |
| `subheadline` | `.subheadline` for secondary information, timing buttons, and Re-sync. |
| `status` | `.subheadline.weight(.medium)` for player acquisition and recovery status. |
| `footnote` | `.footnote` for provider details, notices, and comfort guidance. |
| `caption` | `.caption` for saved-state metadata; `.monospacedDigit()` for time and timing adjustment. |
| `reading` | The user-selectable semibold caption baseline. It defaults to the frontmatter size, adjusts from 24 to 44 pt in 2 pt steps, then scales with the `.title2` Dynamic Type metric. |

`PlayerView` uses `@ScaledMetric(relativeTo: .title2)`, while the Settings preview uses `UIFontMetrics(forTextStyle: .title2)`. The user setting is a baseline, not a maximum after accessibility scaling. Home switches from the large title to a bold title2 invitation and shorter supporting copy at accessibility sizes, and removes its decorative bird.

**The Readable Size Rule.** Use native text styles for interface text. Scale the user-selected caption size with the title2 Dynamic Type metric, and allow multiline text to grow vertically.

## Layout

Use safe-area-aware native stacks and scrollable content. There is no web breakpoint grid. Home uses an inset grouped `List`; search uses a native `List`; Settings and episode selection use `Form`. Welcome and preparation scroll with a content width cap (600 pt).

The extracted spacing scale names the point values found in code, not a shared constants API. Its recurring roles are: compact text groups (`space-4` through `space-10`), control and row groups (`space-12` through `space-20`), and scene or section spacing (`space-24`, `space-28`).

| Source pattern | Measurement |
| --- | --- |
| Welcome and preparation | 24 pt outer padding; welcome sections 28 pt apart; welcome top bird inset 32 pt. |
| Home introduction | 24 pt between main groups; 20 pt between text and bird; 10 pt between heading and supporting text; 12 pt between actions. |
| Result and History rows | 8 pt vertical content padding; 5 pt title/metadata gap; 32 pt icon column; horizontal gaps 16 pt in results and 14 pt in History. |
| Empty state | 12 pt internal spacing and 28 pt padding. |
| Caption container | Text width cap 780 pt; horizontal inset 24 pt in the regular layout or 56 pt in compact landscape; top inset 56 pt. |
| Player controls | Side insets 20 pt regular or 24 pt compact; bottom inset 12 pt; vertical group gap 14 pt regular or 4 pt compact. |
| Player top bar | Side inset 14 pt; 12 pt between controls; 6 pt between the top row and status. |

Player compact layout is selected only when width exceeds height and Dynamic Type is not an accessibility size. `ViewThatFits` changes the action row into stacked rows when horizontal space is insufficient. At accessibility sizes, landscape retains the spacious layout. Caption text sits in a vertical `ScrollView`; bottom space accounts for visible controls (194 pt regular, 98 pt compact) and reduces to 44 pt when controls are hidden. These layout changes retain the same observed session.

Custom actions honor a 44 pt minimum interaction target. The primary action's content has a 28 pt minimum height plus its vertical padding, making the resting minimum 52 pt before larger text. Secondary action content has a 44 pt minimum before native bordered styling. Player close/settings targets are 44 by 44 pt; timing targets are at least 52 by 44 pt. Native toolbars, sliders, steppers, and switches keep platform interaction behavior.

## Elevation & Depth

Application content is flat and grouped by system surfaces. There are no custom application shadow tokens. Native bars, forms, sheets, and bordered buttons retain the materials and depth supplied by the host iOS. The player adds a transparent-to-black linear gradient behind visible lower controls and a subtle translucent offset capsule. The approved Wordbird retains its own artwork gradients; they are not a surface treatment.

**The Inherited Depth Rule.** Let the host iOS provide navigation and sheet materials. The app adds no custom card shadows or simulated glass panels.

## Shapes

The custom primary action uses a continuous rounded rectangle (`rounded.action`). Timing adjustment uses SwiftUI `Capsule()`. List groups, fields, bordered controls, and sheets inherit native geometry instead of sharing the action radius.

`Wordbird` is a decorative, accessibility-hidden image with a 72 pt default. The current placements are 96 pt in Welcome, 68 pt in Home, and 56 pt in Settings. The in-app 512 by 512 PNG is the approved Android asset. The 1024 by 1024 RGB app icon is a deterministic render of `docs/brand/app-icon.svg`, with an opaque square teal background; iOS supplies the final icon mask. Both PNGs carry source provenance metadata. Preserve the artwork and its recorded placement correction. See `docs/brand/PROVENANCE.md` for the pinned upstream origin.

## Components

### Buttons

Primary actions are clear, full-width invitations. `PrimaryAction` uses the yellow/ink token pair, headline typography, the continuous action radius, and the frontmatter padding. Its plain button style adds no custom hover, pressed animation, or shadow.

Secondary actions use native `.bordered` styling and the current `Brand.link` tint. Their background, radius, and pressed/focus treatment remain system-owned. Both `PrimaryAction` and `SecondaryAction` replace `Label` with `Text` when `dynamicTypeSize.isAccessibilitySize`, allow vertical text growth, center multiline labels, and retain full-width content. Removing the decorative symbol preserves room for the action's name.

Player text actions use plain, native buttons. Play/Pause is white; Re-sync is yellow and disabled while acquiring or demonstrating. Timing changes are signed half-second actions with explicit accessible labels describing earlier or later captions. Icon-only close and settings controls expose descriptive accessibility labels.

### Cards / Containers

The reusable container is the native list or form group. History and search rows combine a film/TV SF Symbol, a title, metadata, and a native-looking disclosure symbol. They are whole-row buttons, with native swipe deletion in History. Empty and loading states use text, SF Symbols, and `ProgressView`; they do not introduce a custom card system.

### Inputs / Fields

Search uses `.searchable` with a title prompt, with autocorrection disabled. Queries shorter than two trimmed characters show guidance. Search waits 350 ms before sending a request and cancels obsolete tasks.

Settings uses native `SecureField`, `TextField`, `Stepper`, `Toggle`, and `Slider` controls. API-key and username entry disable capitalization and correction. Form sections and footers provide context. Invalid account pairing presents a native alert, and field styling remains native. No custom focus ring or error border is defined by the app.

### Navigation

Home uses `NavigationStack` with a large title and a native push to search. Detail and modal titles are inline. Settings is a sheet with Cancel/Done; Files uses the system importer; the player is a `fullScreenCover` with a labeled close action. Episode selection and reading settings offer medium/large sheet detents; preparation uses a large sheet. Preparation temporarily disables dismissal while downloading. The episode-to-preparation handoff waits 400 ms for the previous sheet to dismiss.

**The Platform Chrome Rule.** Use NavigationStack, List, Form, native search, and system presentation controls. Preserve Apple back navigation and Cancel/Done conventions.

### Cinema player

The caption is centered, semibold, white, and scrollable. A signed timing offset remains top leading when its magnitude reaches 0.05 seconds; its monospaced digits and accessible description expose the adjustment without relying on color. Settings and close controls follow controls visibility. The player forces dark appearance, and system overlays follow the controls state.

A successful match shows Synced for 4 seconds. Controls hide after 4 seconds of eligible playback, but not while acquiring, scrubbing, showing reading settings, or running VoiceOver. Re-sync cancels any pending hide task before showing acquisition controls, and the task rechecks eligibility when its delay ends. The explicit hide gesture also respects VoiceOver. These are visibility delays, not a custom animation duration.

Acquisition states have textual status, and failure messages provide an action. The default attempt lasts 35 seconds (`SyncTuning.attemptSeconds`); timeout guidance offers Re-sync during dialogue or closing the player to open another SRT from Home. Denied permission preserves timeline use and exposes Open iPhone Settings. Manual timeline positioning does not start recognition. Listening stops when a match is accepted or acquisition is interrupted.

Reading settings adjust caption baseline size, screen brightness, and current-orientation locking. Brightness defaults to 0.15, ranges from 0.01 to 1, and the Very dim action selects 0.03. These are screen-brightness values, not color or opacity tokens. The previous brightness is restored when the player loses foreground focus or closes. There are no custom haptics, sound effects, or background listening behaviors in this interface.

**The Quiet Cinema Rule.** After synchronization, the caption remains central while transient status and controls recede. Keep controls available during listening, interaction, settings, and VoiceOver use.

## Do's and Don'ts

### Do:

- **Do** preserve the approved Wordbird artwork and let iOS apply the app-icon mask.
- **Do** keep semantic app surfaces and test light and dark appearances.
- **Do** retain native Dynamic Type, vertical text growth, and text-only primary and secondary actions at accessibility sizes.
- **Do** provide at least a 44 pt interaction target and explicit accessible names for icon-only actions.
- **Do** keep the player black, captions white, and timing changes readable without relying on color.
- **Do** keep microphone recovery actionable and preserve access to manual timeline positioning.

### Don't:

- **Don't** replace system navigation, sheet materials, or grouped forms with a web-style shell.
- **Don't** assign hard-coded hex colors to semantic app surfaces or secondary text.
- **Don't** add the decorative Wordbird to the cinema player.
- **Don't** flatten Dynamic Type into fixed text sizes or force accessibility layouts into the compact landscape row.
- **Don't** bake rounded corners or the circular Android badge into the iOS app-icon export.
- **Don't** treat HTML specimens, synthesized tonal ramps, or earlier simulator captures as native release certification.
