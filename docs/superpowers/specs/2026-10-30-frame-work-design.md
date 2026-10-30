# Frame work reduction

The target is the current game on `origin/main` (`a498b40`). Keep gameplay,
physics, art and animation timing unchanged. The user requested autonomous
analysis, implementation, testing and a PR, so design choices proceed inline.

Three approaches were considered: cache generated geometry, reduce animation
frequency, or avoid work when state has not changed. Choose the last approach:
it removes redundant script work without a new asset cache or visual tradeoff.

- Ball icons invalidate cached drawing only when a visible property changes.
  Idle icons stop processing; a highlight wakes processing until its final frame.
- Feedback skips empty updates and removes expired entries in place. Clearing
  feedback invalidates the canvas even when animation is paused.
- Local match reads authoritative outcome and score directly for result checks.
  Full immutable board snapshots remain at the existing 20 Hz publication rate
  and on lifecycle transitions.

Tests count real CanvasItem draw signals and real board snapshot calls. They also
exercise property changes, highlight completion, effect expiry/clear/pause,
score and overflow outcomes, snapshot cadence and detached published state.
Run the existing verifier, focused multiplayer/HUD checks and Web export. Record
before/after work counts and a repeatable headless CPU benchmark, without
claiming that those timings measure browser FPS or GPU performance.
