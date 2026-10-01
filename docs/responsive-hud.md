# Content-driven gameplay HUD

## Layout contract

Desktop HUD cards no longer reserve fixed 192/268-pixel bands or stretch statistics to fill screen height. Each card measures its content minimum plus the actual themed frame and inner margins. Minimum-size changes schedule one deferred relayout; identical board rectangles are not reprojected. Rebuild teardown clears references before controls emit retirement signals, preserving existing reentrant HUD behavior.

Near-square screens retain stacked statistics and controls, with centered widths capped at 960 logical pixels. Wide-screen statistics/actions form a grouped sidebar capped at 460 pixels; the optional ultrawide collection card fits its list. Compact cards return all unused vertical space to the existing cabinet projection. The cabinet preserves proportions, collision shape/mass, active run identity and the existing adaptive-floor behavior. Mobile direct-touch layout and multiplayer composition remain unchanged.

The cards preserve text size, wrapping, keyboard focus and button semantics rather than hiding content or stretching artwork. Where enlarged development text needs more room, content remains the size authority; existing scroll containers are a bounded-height fallback, not empty panel fillers. The normal player layout at the tested near-square dimensions gives the cabinet at least half the viewport height. The development launcher and enlarged text are intentionally exempt from that occupancy target, but never from content-fit and overlap checks.

## Verification

`tests/test_responsive_hud.gd` covers 320×568, 390×844, 768×1024, 800×600, 974×804, 960×960, 1024×768, 1280×720, 1440×900, 1948×1608, 2560×1080 and 3440×1440, in English and Simplified Chinese. It also exercises long scores/goals, enlarged owner text, repeated breakpoint crossings, bounded widths, surplus panel height, viewport containment, default text without hidden scrolling, cabinet proportions and run continuity. Native mode can write captures to the supplied output path.

```sh
godot --headless --path . --script tests/test_responsive_hud.gd
xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  --script tests/test_responsive_hud.gd -- /tmp/mushies-responsive-hud
```

The solo cabinet and local split-screen reuse the retained plushie artwork. Real browser touch, audio unlock, persistence, and rendering acceptance are separate from native layout assertions.
