# MUE — image → sound

Turn a picture into sound. Every row of pixels becomes a sine wave at a fixed
frequency, every column a slice of time, and brightness the loudness. Look at
the audio in a spectrogram and the picture comes back.

Inspired by Benn Jordan's video *"I Saved a PNG Image To A Bird"*.

**Status:** native iOS app, early. Phase 1 (engine + project scaffolding) is
done; the app itself is next. See [docs/PLAN.md](docs/PLAN.md).

## Building

Requirements: a Mac with Xcode 16 or newer, and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
(`brew install xcodegen`). No other dependencies.

```sh
git clone https://github.com/s1mb10t3/project-mue.git
cd project-mue
cp Config/Local.xcconfig.example Config/Local.xcconfig   # then edit it, see below
xcodegen generate
open Mue.xcodeproj
```

`Mue.xcodeproj` is generated and not committed, so **after every `git pull`
that adds, removes or moves files, run `xcodegen generate` again** before
building in Xcode. (The `scripts/` wrappers do this for you.) The symptom of
forgetting is "Build input files cannot be found".

### Signing with a free Apple ID

You can run MUE on your own iPhone without a paid developer account.

1. In Xcode → Settings → Accounts, add your Apple ID. Xcode creates a
   "Personal Team".
2. Edit `Config/Local.xcconfig`:
   - `MUE_BUNDLE_ID` — something unique to you, e.g. `com.yourname.mue`.
     (`com.example.*` style IDs are usually already registered and will fail.)
   - `MUE_TEAM_ID` — your 10-character team ID. Easiest way to find it: select
     the `Mue` target → Signing & Capabilities → pick your Personal Team, then
     read the ID Xcode filled in, put it in the xcconfig, and re-run
     `xcodegen generate`.
3. Plug in the phone, choose it as the run destination, press Run. The first
   time, the phone will ask you to trust the developer certificate under
   Settings → General → VPN & Device Management.

Free-account limits: the app expires after 7 days (just run it again from
Xcode), and there is no TestFlight.

### Command-line workflow

The `scripts/` folder wraps the whole loop so you (or Claude Code running
locally) never need to click through Xcode:

```sh
scripts/bootstrap.sh                 # XcodeGen, Local.xcconfig, generate project
scripts/test.sh                      # MueCore unit tests
scripts/build.sh                     # compile for the simulator, errors/warnings only
scripts/sim-run.sh                   # build + install + launch in a simulator, console streaming
scripts/sim-add-photo.sh photo.jpg   # give the simulator's photo library something to pick
scripts/sim-screenshot.sh out.png    # capture the simulator screen
scripts/device-run.sh                # build + install + launch on the plugged-in iPhone
```

### Working with Claude Code

Run Claude Code in this repository on your Mac. `CLAUDE.md` tells it how to
build, test, run in the simulator, take screenshots and read the console,
so it can see what it changed. Cloud sessions can still do engine work and
docs (CI compiles for them), but anything that needs to be run belongs in a
local session.

## Project layout

- `MueCore/` — the engine as a Swift package: image → matrix → samples → WAV.
  Pure Swift, no UI, unit tested.
- `Mue/` — the SwiftUI app.
- `project.yml` — XcodeGen spec that generates `Mue.xcodeproj`.
- `docs/` — [plan](docs/PLAN.md) and [architecture](docs/ARCHITECTURE.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
