# Frame Work Implementation Plan

**Goal:** Remove redundant rendering and snapshot work while preserving behavior.

**Architecture:** Retain Godot's cached CanvasItem commands while state is stable.
Use authoritative board state for match decisions and serialize only for consumers.

**Tech stack:** Godot 4.7.2, GDScript, existing Python/Node verification tools.

1. Add `tests/test_frame_work.gd`: count icon/effect draws over 60 frames;
   check real changes, highlight lifecycle, effect expiry, pause and clearing.
   Add `tests/test_match_frame_work.gd`: use a counting subclass of the real
   board to check publication cost, cadence, result rules and detached snapshots.
   Run both before changes and preserve the expected failures.
2. Update `scripts/ui/ball_icon.gd` with equal-value guards and highlight-driven
   processing. Skip empty feedback updates and replace allocating filters with
   reverse removal in `scripts/vfx/feedback.gd`. Replace per-tick snapshots in
   `scripts/multiplayer/local_match.gd` with session outcome and board score.
   Re-run the new tests and integrate them into `tools/verify.py`.
3. Add `tools/benchmark_frame_work.gd` for fixed-frame draw counts and repeated
   two-board CPU timing. Run the identical probe on the base and the change.
   Record method, numbers and limitations in `docs/performance.md`.
4. Run `npm run verify`, multiplayer/HUD checks, Web export and browser smoke
   checks. Review the final diff, commit explicit paths, push the branch and open
   a PR against `main` with measured evidence and any validation limits.

## Execution record

- [x] Added regression checks and observed the original 60 idle redraws and
  160 board serializations per 60 ticks fail the new work-count assertions.
- [x] Implemented the changes and passed all new checks, including real match
  physics, countdown, drops, individual overflow, final results and rematch.
- [x] Benchmarked the same 80-ball/board probe against `a498b40` and documented
  the measurements and limits in `docs/performance.md`.
- [x] Independent review found a reduced-motion invalidation edge case; added
  a failing regression, fixed it and received a clean follow-up review.
- [x] Full verifier (15 stages) and release Web export passed.
- [x] Chromium desktop solo/pause/split-screen and mobile touch smoke checks
  passed without JavaScript or console errors; screenshots were inspected.
