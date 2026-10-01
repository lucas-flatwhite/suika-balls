# Physics Merge Puzzle Template — Local Multiplayer

This versioned source is owned by the Webdev Addon. Use the installed Game workflow for initialization, preview, release and publishing. Matching gameplay source: template-provenance.json. Existing projects are never overwritten by a new starter.

For online multiplayer, read [the shared service guide](docs/game-multiplayer.md).

## Shared game-development workflow

Applies to Max effort, not `fast_prototype`; Fast uses its dedicated section instead. Keep edits scoped and
preserve explicit constraints.

### Preserve the selected template
Extend the initialized project and keep its working simulation, controls, saves and delivery. Integrate supplied
games into that project. The first Preview must show the requested game, not a renamed demo; replace the Generic
maze gameplay unless a maze was requested.

### First-checkpoint completion contract
Deliver the requested goal, actions and outcome loop with understandable controls and feedback, recovery or replay
where it fits, coherent readable visuals, the necessary start, pause and results screens, and any requested
deliverable. Match run length and content to the brief; there is no minimum playtime, campaign, extra mode or screen
quota. Prioritize gameplay, broken resources, responsiveness and visible defects, and stop when the requested
experience works. Add art, audio or polish only for a concrete benefit. Leaderboards, new Tweak controls and extra
languages are optional; required Share OG and explicit media, concept or feature requests are not.
Default to desktop. Add or test touch controls, portrait layouts or mobile-browser support only when the user asks.
Sharing a Web link is not a mobile request. Keep inherited controls working without expanding mobile coverage.

Choose the [delivery scope](game-delivery.md#delivery-scope-and-stopping-boundary) from the request. Ordinary managed
delivery is check → save-release.mjs → applicable check --pack → push the exact SHA and confirm the checkpoint.
Documentation-only edits need no engine boot. Do not add audit reports, speculative test suites, a separate
self-review phase or duplicate validation workers.

### Ownership boundaries
Keep flow, authoritative simulation and scoring, input, entities, tuning, presentation and persistence in their
existing owners; cosmetics never decide collisions or rewards. Offline authority stays in Godot and online authority
on the dedicated server. WASD is reserved for player movement or camera panning, never abilities or menu actions;
leave it unbound when nothing moves, and update remapping, tutorials and hints when replacing conflicting shortcuts.

### Gameplay feedback and optional polish
Make actions, damage, rewards and outcomes readable with the simplest fitting cues. Reuse existing feedback and
add effects only where they improve readability or the requested feel; no particle set, reward flights, screen shake
or animated counters are required. Keep overlays input-transparent and cosmetics independent of simulation, and
preserve reduced-motion settings.

### Tutorial content boundary
Explain the necessary goals, controls and rules briefly in the game's language; a short start-screen hint is enough
for simple games. A staged tutorial needs a working Skip that releases input and pause locks and remembers the dismissal. Keep implementation
values and Tweak controls out of player instructions.

### Optional local leaderboard
Add local standings only when requested or integral to scoring and replay, and keep a useful existing one; changes
keep bounded records, once-only terminal submissions and deterministic ties. Online
rankings need an explicit request and the installed leaderboards guide; never provision a backend for an offline
game by default.

### Native verification
Reuse existing checks for changed gameplay, input, audio, saves, localization or tuning. For visual questions,
capture with the real renderer (`get_viewport().get_texture().get_image()` and `Image.save_png()`); headless Dummy
rendering proves nothing visual. Do not drive the Preview with browser automation, screenshots or self-tests unless
the user asks for browser debugging; use logs and report Web input, audio and layout as pending user acceptance.

### Concept work by request
Concepts are conditional, not a routine production step. Follow the Blueprint's recorded mockup choice and do not
offer a second concept workflow when the direction is already clear. For an explicit request, produce distinct,
coherent interpretations of the brief and keep the selected identity through revisions. The Game Concept Design flow
needs exactly three separate mockups generated under the recorded image consent, presented through the existing card
and explicitly approved; never label mockups as screenshots. Outside that flow, honor the requested count and
approval method. Mockup consent is not consent for production assets.
## Shared art and audio production

### Asset reuse and targeted production
Reuse suitable supplied, template and already available assets within their recorded permissions and the user's
source restrictions; template reuse needs no extra approval. Replace only assets that conflict with the requested
theme, lack necessary states or look visibly wrong. A new game or reskin does not require replacing every image,
animation, icon, track or effect unless the user asks for original art or a full replacement. Retain unused
reference files and supplied license notices, describe reused assets honestly, and update visible titles and themed
copy. Rename internal IDs only when needed, together with their consumers, saves and tests.

### Coherent scene and title art
Fulfill the requested visual scope with readable actors, hazards, UI and a coherent scene. Simple intentional
visuals are acceptable within the recorded source choice. Title and loading screens may reuse permitted game art
with live text; no separate key art is needed. A download is not integration: inspect the affected scene.

### 3D texture budgets
Budget the project's stored textures, including bytes embedded in GLB/glTF, not catalog masters or import limits.
Longest edge: 256–512 for small or distant props, 1024 by default, 2048 for close main actors or shared atlases,
4096 only for a justified visible difference. Never upscale, and keep UVs, channel packing and material bindings
intact. Remove replaced embedded bytes, keep ancestry and sync the changed files. If suitable tools are missing,
report it rather than replacing working assets. Claim only measured savings.

### Continuous animation and alignment
Use the approved animation method. AI continuous motion goes from approved static references to a guided
fixed-camera, in-place video to fixed-FPS extracted loops; independent poses need an approved stepped style. Keep a
shared canvas, scale, pivot and contact anchor across states and facings instead of per-state placement patches, and
keep raw masters outside the game. Check representative movement, reversal and ground contact with the native
renderer.

### Mandatory background removal for composited assets
Composited sprites, icons, portraits, cursors and loader art need clean real alpha that survives resize, import and
export; check changed edges on contrasting backgrounds at display scale. Opaque plates and terrain are exempt. Keep
words, numbers and HUD labels live, and never slice concept collages into runtime assets. Generate cursors on a
hot-pink or neon-green background and remove it before use.

### Seamless parallax backgrounds
Repeating layers must tile left and right without mirroring; check the joins between adjacent copies at the intended
scale after any crop, import or scale change. Side-scrollers keep a low scenic foreground above world actors and
below the HUD without hiding combat.

### Audio production as needed
BGM is optional unless requested or essential to the brief. Reuse a fitting permitted template, supplied or catalog
track when the source restrictions allow; silence with safe empty routes is valid, and a new Max game is not a
reason to generate custom BGM. Honor explicit silence, supplied-only, AI-only and custom-music requests, and add only
useful event SFX. Generate audio only for an explicit request or a concrete
unmet need within recorded permissions: one usable result per needed track or cue, retried only for an actionable
correction. If requested custom music cannot be produced, report the unmet requirement. Audition changed audio and
ship compressed runtime audio, not raw WAV masters.

### Audio integration
Reuse the existing Music/SFX routing, gesture unlock and bounded voices, and keep empty routes safe across pause,
retry and scenes. New games that use audio keep the absolute base gains BGM 3× (+9.5424 dB) and SFX/UI 2×
(+6.0206 dB) over the inherited originals: place MusicBase/SfxBase before senders so each route crosses once,
replace old targets instead of stacking boosts, and keep the ≤0 dB guards, saved settings and explicit mixes.
Silent games need no gain plumbing, and existing delivered mixes stay unchanged. Spatial audio keeps real source
positions; music and global HUD sounds are separate. When music is used, keep the shared browser BGM adapter and
its native fallback.

### Asset generation mode gate
Recorded permissions decide what may be generated, regardless of mode or available tools. Hybrid, AI or explicit
permission covers its scoped generated visuals and SFX; mockup consent does not. For authorized images choose the
latest GPT Image model offered by the live schema unless the user named one. Tools record generation metadata
automatically; keep tool, provider, model and internal path details out of user-facing copy.

### Asset-production choice wording
Fast prototype follows its bounded workflow. New managed games call `webdev.init_project` once direction is clear,
with the complete brief; the canonical card settles unresolved choices, not parallel chat questions or a separate
Blueprint. Session-agent catalog search, access, downloads and delegation wait for successful initialization plus a
settled Blueprint, required plan and requested concept approval; in-flight or failed init is not success. Only
initialization's bounded metadata assessment may precede the card, never production downloads, generation or
integration. Standalone search or retrieval needs no project but does not justify speculative new-build sourcing.
Use the conversation language and call the catalog 游戏素材库 in Chinese. Recommend Hybrid mode for 2D, 3D and
unknown games. Card options for 2D/unknown: Manus game assets catalog, Hybrid mode, AI generation; Hybrid means
catalog plus AI art/audio, not scratch visuals. Known 3D: Game asset library and procedural generation, Hybrid mode,
AI generation. Only initialization's evidence-backed insufficient core-visual fit changes the first 3D label to
Procedural generation (Faster, lightweight, minimal token consumption); Unknown/sufficient fit or missing decoration
does not. Preserve historical accepted permissions; never infer them from option names or recommendations.
Only missing card support or a structured `planning_unavailable` receipt moves unresolved setup to one native
single-choice question; canonical state wins. For 2D/unknown: Manus game assets catalog, Hybrid (Recommended), AI
generated. Known 3D: Curated asset catalog and procedural (lowest token cost; catalog first, permitted gaps),
Hybrid (Recommended), AI generated (highest token cost). Keep these labels and this order, and record the answers.
No-questions sessions use
the recommended option within existing permission, which is not new consent. Additions to an existing game ask only
an unresolved production choice; delegation inherits constraints.
Accepted `choices.visualAssetSource: procedural` needs no repeated visual search/gap proof; audio follows its own
source restrictions and optional-production workflow. Catalog and Hybrid sourcing, including required-gap handling,
follows the game-asset-catalog Skill. Procedural permission never implies music composition.
## Shared Web runtime and delivery contract

### Browser-safe lifecycle
Bound and reuse voices, projectiles, particles, timers and subscriptions across pause, retry and scenes; change
pause or stream state on transitions, not every frame. Browser BGM uses the independent Web Audio renderer in
`scripts/manus/browser_bgm_player.gd`, never frame- or timer-fed PCM or finished-callback loops. It decodes once into
a bounded LRU AudioBuffer cache: call `prepare()` during loading or a transition before gameplay, then `play()`
reuses the buffer. Imported duplicates share an explicit original-path `buffer_key`, and changed PCM needs a new key.
Decode imported resources from the PCK, keep SFX in Godot and keep `thread_support=false`.
Route track, loop, position, pitch, mute, pause, duck, crossfade and Music/Master controls through the adapter.
External BGM does not inherit buses: mirror linear gain, limiter makeup and AudioEffectAmplify only. Keep native
Godot and the guarded Web fallback (`PLAYBACK_TYPE_STREAM` for long BGM) without overlapping backends; pending
autoplay waits for valid input, and stale starts are guarded. Stop voices and release removed cues with
`release_cached_stream()`, evict only unreferenced tracks, keep OS/bfcache suspend and restore, and release the context
on real teardown. Native tests cannot prove browser continuity through
main-thread stalls, so report that as pending user acceptance.

### Fast, recoverable startup
Keep the title and controls interactive with only the required fonts, UI, settings and small art. Defer scenes,
generation, media and decoding until needed, in bounded per-frame work; instantiate scenes on the main thread. Start
blocks duplicate transitions and reports recoverable content errors. Lazy PCK content reduces work, not transfer
bytes. Loading progress uses real bytes or phases and an indeterminate state for unknown totals; slow or stalled
notices are nonfatal, offer Retry, and clear on late success. When changing this mechanism, check cold load,
repeated Start, stall, unknown total, late success and Retry.

### Animated backgrounds without startup blocking
Show a small static placeholder immediately and keep it as the fallback. Load animations asynchronously after the
title is interactive, never as a Start or preload dependency, and swap on an actual ready frame while guarding exited
scenes and stale completions.

### Large explorable maps: presentation culling and live state
Offscreen simulation, pathfinding, orders, combat, economy, timers, replication, saves and the minimap stay live.
Cull only cosmetics against the current camera bounds, with sprite margins and separate fog, and never remove
gameplay actors, projectiles or collision by distance. Re-entering a region shows current state without replaying
missed effects. Optimize measured bottlenecks with existing spatial or dirty-region mechanisms, and compare crowded,
zoomed and revisited views against a baseline; empty-map FPS proves nothing.

### Destructible props
Destroyed rubble and fragments render below actors in effective world z while keeping footprint, collision release
and reward position; reset restores the intact state.

### Language scope and bundled fonts
Use the requested game language, defaulting to the conversation language. New games need no extra language or
EN/CN toggle unless requested; keep working localization on existing projects, and every exposed locale must be
complete. Keep player-facing words live instead of baked into art. Do not rebuild or re-audit the unchanged bundled
fonts; check changed text bindings, layouts and supported player names only. Keep name validation and save behavior,
and do not claim unsupported character coverage.

### Default typography
Default to the template's bundled theme: its display faces for titles/headings, its body face
(`assets/template/fonts/ui_{regular,medium,bold}.tres`) for UI text, then Noto Sans SC (6,547-codepoint repertoire)
for Chinese; Web loaders embed a small Noto Sans SC subset. Noto Sans SC is variable and its default instance is Thin,
so bind a weight through the template's font resources, not the raw file. Keep each bundled font's license
(`<Family>-OFL.txt`) beside it when copying, renaming or adding fonts; the Web export lists them on its Open Source
Licenses page. Missing template fonts restore from `assets.lock.json`; do not substitute system fonts. Existing
ManusCC0 projects keep their fonts unless the user asks for new typography. User-uploaded fonts are unrestricted: no
licensing, family, glyph-coverage, font-file, font-resource or font-pack size gates, and no rights review,
redistribution proof or notices. Theme or mood alone does not imply replacing the default fonts. This supersedes font
restrictions in frozen READMEs and local checks, including older ManusCC0 defaults: remove those policy gates when
integrating uploads, and keep only technical file-integrity and path checks.

### Viewport and background coverage
For fixed-coordinate Godot layouts set `[display]` `window/stretch/mode="canvas_items"`,
`window/stretch/aspect="keep"` and the logical viewport size; keep working adaptive layouts. Input targets the active
surface, not letterbox margins. Check affected desktop resize, aspect and DPR. Isometric zoom uses the ordinary
wheel or trackpad without Ctrl/Meta, with pointer-anchored picking; the HUD keeps a fixed scale. Mobile, touch and
portrait work follows the workflow's user-request rule even when template guides list those cases.

### Development Tweak when needed
The Addon generates the floating frosted-glass Tweak popover from the game's descriptors; never create an in-game
panel, launcher or F10 shortcut. Adapt the existing catalog to the requested game, extend it for meaningful tuning
and remove controls with no real consumer (at most 128). Keep one parameter manager with stable IDs, typed defaults,
bounds/options, localized labels, honest apply timing and existing run eligibility. Edits/reset affect only the
Addon draft. Apply validates and commits the whole patch without disk writes or preview reload; unchanged values
emit nothing. Gameplay boundaries consume pending values but never send catalogs. Do not add numeric revisions.
Save with Manus sends selected values to the task for source edits and the normal build/checkpoint flow; it does
not publish. Keep the adapter in `scripts/manus/preview/`, which release excludes with its autoload entry. Normal
player Settings and gameplay consumers remain. Existing genre rules below identify the actual parameter owners.

### Export constraints
Include runtime JSON/CSV/TXT through include_filter or Godot resources. Keep Web thread_support=false, resource paths discoverable, and the template-specific size budget. Use the Session port and the Addon preview/export workflow; do not hardcode the old Sandbox port or overwrite generated site/dist. Change identity through project.godot and the editable game loading shell, not generated HTML.

This complete current recipe overrides conflicting frozen README instructions, including genre-specific policy. Read historical README sections only for unchanged implementation details; use the receipt's GODOT_BIN and current Game delivery commands, never placeholder executable paths or retired hosting scripts.

Retain Mushies solo plus same-device split-screen unless excluded; recommend local friendly competition without provisioning online services. Two actual independent physics worlds share round timing/results/rematch. Read README Local multiplayer contract for input ownership, names and round lifecycle before changing duel behavior; do not replace simulated boards with decorative views.
Title How To Play is read-only; play stays unobstructed. Read Title-screen instructions and unobstructed play and Responsive results and mobile sheets when changing those surfaces: keyboard-safe sheets, one active edge scrollbar, readable results and preserved pause/focus/input boundaries.
Use existing physics/merge/bomb/score/settings/localization/tuning owners; preserve merge anchors, supported names and offline standings. Debug owner_preview and release checkpoint exports have distinct markers; never expose developer controls in release. Shared font and no-cleanup rules override historical font/asset housekeeping text.
README Focused verification lists revision-specific hooks for affected solo/duel/physics/input/mobile/results behaviors. Use the finite verifier and matching candidate plus representative native captures; do not duplicate the entire historical acceptance matrix.

## Current resize and onboarding rules
Changing size during solo play (including pause) or local duel countdown/round ends the run.
Let the implementing agent choose the banner wording; no historical exact phrase is required.
Freeze gameplay/input before layout rebuild, keep the banner through further resizes until a new
round/title, and exclude resize losses from standings. Initial/title/lobby layout and visibility
notifications without size changes are exempt. Keep title-only read-only How To Play: no in-game
tutorial popups, reserved footer, replay/completion dependency or pause-menu help shortcut unless requested.
Do not remove rescue-bomb gameplay when removing teaching copy.

## Source owners
| Path | Responsibility |
|---|---|
| `scenes/main.tscn`, `scripts/plushie_main.gd` | Entry, routing, input, viewport and pause lifecycle |
| `scripts/plushie_hud.gd` | Responsive title, read-only How To Play, HUD, menus, settings and results |
| `scripts/ui/mobile_sheet.gd`, `mobile_scroll_edge.gd` | Keyboard-safe mobile sheets and the active sheet's single edge scrollbar |
| `scripts/core/session.gd`, `data/stages/registry.gd` | Solo goal/timer progression and starting presets |
| `scripts/plushie_body.gd`, `scripts/bomb_plushie.gd` | Collision silhouettes, merge presentation and contact bombs |
| `scripts/game/board_simulation.gd` | Actual physics simulation reused by local duel boards |
| `scripts/multiplayer/local_match.gd` | Two independent physics worlds, shared round timer, results and rematch |
| `scripts/multiplayer/multiplayer_screen.gd`, `board_view.gd` | Same-device match configuration, two cabinet views and input routing |
| `scripts/multiplayer/protocol.gd` | Shared local round constants and name normalization; no transport |
| `scripts/core/settings.gd`, `storage_migration.gd`, `username_input.gd` | Saved preferences/profile and reusable name input |
| `scripts/score/` | Score integrity and bounded offline local standings |
| `scripts/core/localization.gd`, `localization/` | English/Chinese lookup and locale persistence |
| `scripts/game_audio.gd`, `sound_bank.gd`, `default_bus_layout.tres` | Semantic cues, single BGM, bounded voices and buses |
| `scripts/vfx/`, `config/tweaks/catalog.gd`, `scripts/tuning/` | Cosmetic feedback, typed tuning defaults and debug controls |
| `addons/mushies_export/` | Debug `owner_preview` and release `checkpoint` export markers |
| `ui/mobile/`, `ui/web/`, `tools/build_web_shell.py` | Device lifecycle and localized managed Godot loading shell |
| `assets/template/`, `assets.lock.json` | Retained media, fonts/licenses, provenance and permanent restoration |

## Tweak controls
`config/tweaks/catalog.gd` and `scripts/tuning/tweak_service.gd` own bounds, requested/active values, application
boundaries and sticky practice status. `scripts/manus/preview/tuning_adapter.gd` exposes that manager to the Addon.
Keep normal Settings, leaderboard persistence, multiplayer authority and route-stack pause ownership intact.
