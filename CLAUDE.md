# MUE — notes for Claude Code

MUE is a native iOS app (Swift 6, SwiftUI, iOS 18+) that turns a picture
into sound by painting it into the audio's spectrogram. Read
`docs/ARCHITECTURE.md` for how it fits together and `docs/PLAN.md` for what
is being worked on and why.

## Layout

- `MueCore/` — Swift package with all the signal logic. Pure, `Sendable`,
  unit tested, no UI or AVFoundation. New logic goes here with a test.
- `Mue/` — the SwiftUI app. `App/` (entry, `AppModel`), `Features/` (views),
  `Services/` (wrappers around Apple frameworks), `Resources/`.
- `project.yml` — XcodeGen spec. **Never edit `Mue.xcodeproj`**; it is
  generated and gitignored. Change `project.yml` and regenerate. After a
  pull that adds, removes or moves files, run `xcodegen generate` before
  building in Xcode, or the build fails with "input files cannot be found".
- `Config/` — xcconfig. `Local.xcconfig` holds the developer's bundle id
  and team id and is gitignored; never commit it or its values.

## Commands (run from the repo root, macOS only)

| What | Command |
| --- | --- |
| First-time setup | `scripts/bootstrap.sh` |
| Unit tests | `scripts/test.sh` (add `--filter Name` to narrow) |
| Compile the app (errors/warnings only) | `scripts/build.sh` |
| Run in the simulator with console output | `scripts/sim-run.sh` (`MUE_SIM="iPhone 17"` to pick one) |
| Screenshot the running simulator | `scripts/sim-screenshot.sh build/shot.png` then look at the file |
| Put a test photo in the simulator's library | `scripts/sim-add-photo.sh path.jpg` |
| Run on the plugged-in iPhone with console output | `scripts/device-run.sh` |

`sim-run.sh` and `device-run.sh` block while streaming the app's console;
run them in the background and read their output, or stop them with Ctrl-C.

## How to verify a change

1. `scripts/test.sh` — must pass. Add or update tests for anything in `MueCore`.
2. `scripts/build.sh` — must print `BUILD SUCCEEDED` with no warnings.
3. For UI or audio changes: `scripts/sim-run.sh`, add a photo with
   `sim-add-photo.sh` if the library is empty, exercise the feature, take a
   screenshot and look at it, and read the console for runtime warnings
   (purple runtime issues, AVAudioSession errors, "Publishing changes from
   background threads", etc.).
4. Audio playback only really proves itself on a device: the simulator has
   no silent switch and different latency. Ask the maintainer to try it on
   the phone, or use `scripts/device-run.sh` if one is connected.

CI (`.github/workflows/ci.yml`) runs the tests and a simulator build on
every push; keep it green.

## Conventions

- Swift 6 language mode with strict concurrency; fix isolation errors
  properly (Sendable value types across boundaries, `@MainActor` for UI
  state) rather than with `@unchecked Sendable`, unless the type is
  genuinely immutable or single-threaded and the comment says why.
- No third-party dependencies.
- One type per file, file named after the type. Public API in `MueCore`
  gets `///` docs.
- Design reference is the Figma file linked from `docs/PLAN.md`. The UI
  is deliberately minimal right now: canvas, camera/library buttons,
  player pill. Don't add settings or share UI unless asked.
- Commit messages: imperative subject, a body explaining *why*.
- Keep `docs/PLAN.md` checkboxes and the decision log current when the
  plan changes.
