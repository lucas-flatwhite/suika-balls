# Local multiplayer

From the desktop landscape title, open Local multiplayer, edit Player 1’s saved name, and start Local Splitscreen. The left player moves with A/D and drops with Space. The right player moves with J/L and drops with K. Each cabinet uses a separate physics world and the same seeded drop supply.

A three-second countdown precedes a 180-second round. Reaching the overflow line freezes only that board; the other player continues. The round finishes when both boards overflow or the timer expires. Final score selects the winner, including a draw for equal scores. Goals do not extend the duel clock. Results offer one shared rematch or return to title.

Audio/leave menus and focus changes keep the local round running. They suspend keyboard commands until the menu closes; making the window portrait also blocks commands and shows a landscape prompt. Shared-keyboard entry is unavailable on mobile and portrait windows. Mobile single-player is preserved.

The template contains no online matchmaking, room service, dedicated server, ranked service, external leaderboard, or score-sharing transport. Solo standings remain local; duel results stay separate. `scripts/multiplayer/local_match.gd` owns the two simulations, `scripts/game/board_simulation.gd` adapts the solo physics, and `scripts/multiplayer/multiplayer_screen.gd` presents both cabinets. `protocol.gd` contains only local constants and name normalization.

Run `test_local_match.gd`, `test_local_splitscreen.gd`, `test_local_template.gd`, and `test_username.gd` through the shipped verification command. They exercise real physics, shared-keyboard input, local results, entry gating, saved profiles, and the absence of online transport. Native/browser acceptance remains a separate check.
