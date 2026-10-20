# poop social

A social network for bathroom discourse. Find thrones, rate whether the trip was
*satisfying*, swap original one-liners with your crew — and share exactly zero
photos of anything that happens in there.

> Display name: **poop social** · Module/target: `PoopSocial` · Bundle id: `com.poopsocial.app`

---

## Run it

1. Open `PoopSocial.xcodeproj` in **Xcode 15.2 or newer** (the project is in the
   classic `objectVersion = 56` form so both Xcode 15 and 16 accept it).
2. Pick any iPhone simulator (iOS **17.0** minimum) or a device.
3. ⌘R.

No package resolution, no CocoaPods, no build scripts, no network. First launch
seeds a small San Francisco world (9 people, 9 bathrooms, ~20 reviews, a dozen
drops, 6 reels, reactions and bookmarks) so every surface has something in it
immediately.

The project uses a **generated Info.plist** (`GENERATE_INFOPLIST_FILE = YES`), so
there is no `Info.plist` to maintain. The one key that matters,
`NSLocationWhenInUseUsageDescription`, is set via `INFOPLIST_KEY_*` in
`project.pbxproj`.

### Regenerating the project file

`project.pbxproj` is generated, not hand-edited. Two steps, in order — the second
adds the test targets on top of the app target:

```
python3 gen_pbxproj.py .        # rewrites the project + a shared scheme
python3 add_uitest_target.py .  # adds PoopSocialTests and PoopSocialUITests
```

Both are idempotent. Regenerate whenever you add or remove a `.swift` file in
`PoopSocial/`, `PoopSocialTests/` or `PoopSocialUITests/`.

`gen_pbxproj.py` also writes a **shared scheme**
(`PoopSocial.xcodeproj/xcshareddata/xcschemes/PoopSocial.xcscheme`). That is not
decoration: with no scheme on disk, `xcodebuild -scheme PoopSocial` synthesises
one in memory each run, and its build action is not guaranteed to include the app
target. Checking one in makes the build deterministic and lets Xcode 15 open the
project with a working scheme immediately.

### Tests

29 tests across five suites, all passing on iOS 17.2:

| Suite | Kind | Covers |
| --- | --- | --- |
| `ContentModeratorTests` | unit (19) | the whole no-images / no-flagged-language choke point |
| `PoopSocialUITests` | UI (5) | launch, five tabs, composer, hygiene sheet, full navigation |
| `PoopSocialInteractionUITests` | UI (7) | publishing a drop, refusing empty + flagged input, no image affordance, bathroom detail, crew sheet, rapid tab switching |
| `VisualWalkUITests` | UI (1) | walks all five tabs in order, asserting each one renders content |
| `LaunchProbeUITests` | UI (1) | onboarding is visible on a first run |

`-startTab home|reels|find|crew|me` opens the app directly onto a tab. It exists
for screenshot tooling, but it's also the fastest way to poke at one surface
without tapping through the app first.

```
xcodebuild -project PoopSocial.xcodeproj -scheme PoopSocial \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.2' \
  -parallel-testing-enabled NO test
```

The unit suite never boots a simulator, so it runs in about a second.

> **Three gotchas, all hit during development:**
>
> 1. **Boot the device and launch `Simulator.app` before running UI tests.** A
>    headless boot leaves the accessibility subsystem down and the runner fails
>    with "Timed out waiting for AX loaded notification".
> 2. **Pass `-parallel-testing-enabled NO`.** By default XCTest fans suites out
>    across *cloned* simulator devices. On an Intel Mac the 3rd clone often
>    fails to boot (`launchd_sim may have crashed or quit responding`), which
>    reports `TEST EXECUTE FAILED` even though every test case passed.
> 3. **`PoopSocialTests` is standalone, not hosted.** It compiles the two
>    dependency-free sources it needs (`ContentModerator.swift`) straight into
>    the bundle rather than `@testable import PoopSocial`. A hosted test was
>    tried first and could not be made to resolve the app's module — the app's
>    emitted `.swiftmodule` never surfaced into the products directory the test
>    bundle searches, so the build failed with "no such module 'PoopSocial'".
>    Keeping the pure-logic tests free of a host app removes that entire class of
>    problem. If you add such a source, list it in `UNIT_SHARED_SOURCES` in
>    `add_uitest_target.py`.

### Visual audit

The UI was checked without a human looking at it, by decoding screenshots and
measuring them. Two real defects came out of that, both now fixed:

| Defect | Measured evidence | Fix |
| --- | --- | --- |
| Glass cards rendered **neutral grey**, not navy | `#303038` was the single most common colour on Home, covering ~70% of the lower screen; R≈G≈B | `GlassSurface` uses a navy-tinted `Theme.glass` (`#1B2438` @ 82%) instead of `.ultraThinMaterial`. Dominant surface colour moved to `#202838` — now genuinely blue — while the accent pixel counts stayed identical, so the frosted look survives. |
| Unselected tab items failed **WCAG AA** | `#656667` on `#0a0e1a` = **3.35:1** (needs 4.5:1 for small text) | Item colours pinned to `Theme.inkDim` / `Theme.mint` across all three tab-bar layouts. Unselected now **8.0:1**, selected **12.4:1**. |
| Reels caption ran **under the reaction rail** | Caption text's rightmost pixel sat at x=665, rail's left edge at x=670 — a **5 px (2.5 pt)** gap, i.e. touching | The caption/author column reserves `ReelCard.railClearance` (78 pt) on the trailing edge so copy wraps before the rail. Re-measured: text now ends at x=552, a **118 px (59 pt)** clearance. |

The Reels finding is worth a note on method. Two independent vision reviews
flagged it; two of *my own* pixel detectors initially contradicted each other
(a per-row "rightmost bright pixel" heuristic false-positived on rail icons,
while a run-splitter false-negatived by merging text and rail into one run).
Neither heuristic was trusted. An ASCII density map of the region was rendered
instead, which made the overlap directly visible, and the gap was then measured
with a rail locator keyed on *persistent vertical band count* rather than
proximity. Measure, look, then measure again — the disagreement between two
automated checks is itself the signal that a third, more direct look is needed.

One hypothesis that the measurements *disproved*, worth recording so nobody
re-derives it: Crew and Me appeared to share pixel-identical map tiles with Find,
which looked like MapKit bleeding across `TabView`. A full pixel diff showed 45%
of pixels differing and a constant 27% overlap band — that overlap is the shared
avatar/crew strip, which legitimately uses the same mint gradients. The
accessibility tree confirms Crew and Me have **no** map. A speculative
`.clipped()` fix was applied and then reverted; the bug did not exist.



---

## What's in it

| Tab | What it does |
| --- | --- |
| **Home** | Timeline (`For You` / `Following`), crew strip, daily hygiene PSA, trending thrones rail, threaded replies. |
| **Reels** | Full-screen vertical paging feed. Every "clip" is an animated text + emoji one-liner with a bespoke gradient backdrop. |
| **Find** | Map of bathrooms with search, amenity filters, ranked carousel, detail screen with scores, crew-visit row and reviews. |
| **Crew** | Two connection tiers — **acquaintance** and **friend/bestie** — plus pending requests and a Discover list. |
| **Me** | Profile, stats, hygiene streak/XP/level, badges, saved posts, your drops. |

Plus a global composer (drop / reel / review), a hygiene playbook sheet, and a
4-page onboarding cover.

---

## Architecture

**Local-first.** SwiftData for persistence, SwiftUI + Observation (`@Observable`)
for state, zero third-party dependencies. Reads are live: views use `@Query` and
get updates for free. Everything that *writes* goes through one type.

```
PoopSocial/
├── App/
│   ├── PoopSocialApp.swift     @main — ModelContainer, bar appearance, seed
│   ├── AppModel.swift          ephemeral UI state (tab, toast, sheets, onboarding)
│   ├── RootView.swift          TabView + toast + global sheets
│   └── Routes.swift            Identifiable wrappers for .sheet(item:)
├── Models/
│   ├── Models.swift            @Model types + enums + graph helpers
│   └── ContentModerator.swift  the no-images enforcement choke point
├── Data/
│   ├── Store.swift             THE single write surface (backend seam)
│   ├── SeedData.swift          first-launch world
│   ├── JokeBank.swift          ~60 original one-liners
│   └── HygieneTips.swift       12 tips + deterministic tip-of-the-day
├── Design/
│   ├── Theme.swift             palette, gradients, glass, neon, popIn
│   ├── Motion.swift            PressableStyle, BubbleBackdrop, EmojiBurst, …
│   ├── Components.swift        AvatarView, Chip, GlowButton, EmojiPad, …
│   ├── Format.swift            relative time / compact counts / wait strings
│   ├── Haptics.swift           centralized haptics
│   └── UIActivityBridge.swift  share sheet wrapper
└── Features/
    ├── Onboarding/ Home/ Reels/ Find/ Crew/ Me/

PoopSocialTests/       unit tests (standalone — compiles the pure sources it needs)
PoopSocialUITests/     UI tests (drive the app through the accessibility layer)
```

### The `Store` seam

`Data/Store.swift` is the only place mutations happen. Views call
`store.createPost(...)`, `store.toggleReaction(...)`, `store.submitReview(...)`,
and so on; the store owns the `ModelContext`, sanitizes content, and saves.

Because every write already funnels through that one type, swapping in a remote
backend is a local change:

1. Give `Moderating` a server-backed implementation (or add one alongside
   `LocalModerator`) and point `Safety.moderator` at it — validation call sites
   never change.
2. Convert `Store`'s methods to `async` and have them hit the network, keeping
   the same signatures. Optimistic local writes plus a later reconcile is the
   natural shape.
3. Point views at server-fetched results instead of `@Query` (or keep
   `@Query` as a local cache that the store keeps in sync).

Nothing in `Features/` needs to know which world it's in.

---

## The no-images policy

This is a hard product rule, not a moderation prompt. It's enforced
structurally, in `Models/ContentModerator.swift`:

1. **No camera, no photo picker, no attachment affordance exists anywhere in the
   UI.** There is no `PhotosPicker`, no `UIImagePickerController`, no capture
   session, and no file import in the project.
2. **`MediaKind` has no image case** — `.emoji`, `.textLine`, `.quoteCard`.
   An image attachment is literally unrepresentable, so there is no code path
   that could construct one.
3. **Every outbound piece of user content passes `Moderating`** — a single
   protocol with a single implementation (`LocalModerator`), referenced through
   `Safety.moderator`. `validate` / `sanitize` are called on posts, replies,
   reviews, jokes, bios and emoji.

You'll notice the policy is *shown*, not hidden: a "0 photos · 100% vibes" badge
in Reels, a no-photo notice under the composer, a line in onboarding, and a
content-policy card on your own profile.

All comedy in `JokeBank.swift` is **original writing** for this app — trailer
voice, internet slang and group-chat banter, none of it lifted from films or TV.

---

## Notes for the curious

- **Reels paging** uses `ScrollView` + `.scrollTargetLayout()` +
  `.scrollTargetBehavior(.paging)` + `.containerRelativeFrame(.vertical)` +
  `.scrollPosition(id:)` rather than a rotated `TabView`.
- **Replies** are stored as a plain `Post.parentID: UUID?` instead of a
  self-referential SwiftData relationship — simpler, faster to query, and it
  sidesteps self-inverse edge cases.
- **Sheets that present a model** use small `Identifiable` route structs
  (`PersonRoute`, `BathroomRoute`, `PostRoute`) so `.sheet(item:)` has an
  unambiguous identity.
- **Hygiene streak/XP** lives in `UserDefaults`
  (`poopSocial.tipsCollected`, `poopSocial.streak`, `poopSocial.lastOpen`);
  onboarding and seed flags are `poopSocial.onboarded` and
  `poopSocial.seeded.v1`.
- **App icon** is a 1024×1024 PNG in `AppIcon.appiconset`, generated by
  `/tmp/opencode/make_icon.py` (navy gradient + mint mark). `actool` compiles it
  into `Assets.car`; `Contents.json` references it by `filename`.

---

## Status

**Built, run and tested on real hardware.** Everything below was executed on an
Intel iMac running macOS with Xcode 15.2 (iOS 17.2 SDK + installed 17.2
simulator runtime) on 2026-10-20.

| Check | Result |
| --- | --- |
| `xcodebuild` clean build, iOS 17.2 simulator | **BUILD SUCCEEDED**, 0 warnings |
| `xcodebuild build-for-testing` | **TEST BUILD SUCCEEDED** |
| Full test suite on iPhone SE (3rd gen), iOS 17.2 | **29 passed, 0 failed** — `** TEST SUCCEEDED **` |
| Project regenerated from scratch (no `.xcodeproj`) | reproduces byte-identically: `project.pbxproj` md5 `b8874d5f3f45024c43a39fb05a5d6c83` |
| Regeneration is idempotent + incremental | re-running both scripts leaves the project unchanged; a newly added test file *is* picked up |
| App bundle | display name `poop social`, bundle id `com.poopsocial.app`, `MinimumOSVersion 17.0` |
| App icon | 1024×1024 PNG compiled into `Assets.car` via `actool` |
| Web sibling app | running on `localhost:8899`, 51/51 tests passing |

Earlier work on the same host also confirmed `swiftc -typecheck` and both
`-Onone`/`-O` compiles across all app sources with **0 errors, 0 warnings**.

Real bugs the toolchain caught, all fixed:

1. `Design/Motion.swift` — `PressableStyle.makeBody` called the `@MainActor`
   `Haptics.tick()` from a nonisolated context. `ButtonStyle.makeBody` is a
   *nonisolated* protocol requirement (marking the whole type `@MainActor`
   produced a "cannot satisfy nonisolated protocol requirement" warning), so the
   haptic is now dispatched explicitly: `Task { @MainActor in Haptics.tick() }`.
2. `Design/UIActivityBridge.swift` — `UIWindowScene.connectedScenes` does not
   exist; it is `UIApplication.shared.connectedScenes`.
3. 40 SwiftUI view types were not isolated, so button actions and `onChange`
   closures could not call the `@MainActor` model layer. They are now explicitly
   `@MainActor`. (`tools_add_mainactor.py` is the one-shot script that applied this.)
4. `gen_pbxproj.py` omitted intermediate directories that contained only
   subdirectories, so 15 files resolved to the wrong paths.
5. `add_uitest_target.py` replaced the app target's three build phases instead of
   appending, producing a `.app` that contained nothing but `Info.plist` while
   `xcodebuild` still reported success.
6. `gen_pbxproj.py` swept every loose non-Swift file into `asset_catalogs`, so
   `actool` tried to parse the app-icon PNG as a catalogue.
7. No shared scheme existed, so builds depended on an in-memory autocreated
   scheme. One is now generated.
8. `add_uitest_target.py` skipped any target that already existed, so a new test
   file dropped into an existing test directory was **silently left out of the
   build** — it looked present in the folder but never compiled or ran. The guard
   is now per-file: it adds whatever is missing.

### Known gaps

- **Nobody has looked at the UI by eye.** Everything visual has been verified by
  decoding screenshots and measuring pixels and accessibility trees — which is
  how the grey-glass and tab-bar-contrast defects above were found, so the method
  does work. But colour *aesthetics* (does it look good?) cannot be measured.
  Opening the project in Xcode remains the last unchecked item.
- `Store` is local-only; the backend seam is designed but unexercised.


