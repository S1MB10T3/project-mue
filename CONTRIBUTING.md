# Contributing to MUE

Thanks for stopping by. This is a small project; issues and pull requests are
welcome.

## Setup

1. Xcode 16 or newer.
2. `brew install xcodegen`
3. `cp Config/Local.xcconfig.example Config/Local.xcconfig` and put your own
   bundle identifier and team ID in it (a free Apple ID works; see README).
4. `xcodegen generate` then open `Mue.xcodeproj`.

## Before opening a PR

- `cd MueCore && swift test` passes.
- The app builds for the simulator (CI does this too).
- New logic goes in `MueCore` with a test, unless it genuinely needs a device
  API.
- No new third-party dependencies without an issue discussing it first.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for how things fit together
and [docs/PLAN.md](docs/PLAN.md) for what is being worked on.
