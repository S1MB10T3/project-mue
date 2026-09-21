# MUE — project plan

MUE turns a picture into sound by painting it into the audio's spectrogram
(every image row is a sine wave, every column a slice of time, brightness is
loudness). Inspired by Benn Jordan's *"I Saved a PNG Image To A Bird"*.

This document is the working plan. It changes as we learn things; the
[decision log](#decision-log) at the bottom records why.

## Goals

1. A native iOS app that proves the concept end to end on a real iPhone:
   pick a photo → hear it → watch it come back in a spectrogram.
2. Then make it *feel* good: design, drawing, listening for pictures.
3. Keep it open source and easy to contribute to: no third-party
   dependencies, everything reproducible from a fresh clone.

## Non-goals (for now)

- Android, web, or desktop versions.
- Accounts, cloud, sharing servers. Files leave the app via the share sheet.
- Audio steganography that survives lossy compression. The signal is meant to
  be *seen*, not hidden.

## How we work

- The core logic lives in a Swift package (`MueCore`) with unit tests.
  Anyone can run `swift test` on a Mac; CI runs it on every push.
- The app project is generated from `project.yml` with XcodeGen, so the
  `.xcodeproj` is never committed and merge conflicts in project files don't
  exist.
- CI also compiles the app for the iOS Simulator on every push, so a broken
  build is caught before anyone opens Xcode.
- Device testing happens on the maintainer's iPhone 13 mini with a free
  Apple ID (sideload via Xcode; apps expire after 7 days and are reinstalled).
  There is no TestFlight until there is a paid developer account.
- Two kinds of Claude Code session. **Local** (on the Mac, in this repo)
  for anything that has to be run: UI, audio, debugging; it uses the
  `scripts/` loop and can screenshot the simulator and read the console.
  **Cloud** for engine work, docs and review, with CI as its compiler. Both
  work on the same branch; pull before starting, push when done.
- Work is tracked as GitHub issues, one per checklist item below, once
  phase 1 lands.

## Design reference

UI direction lives in Figma: [Project Mue](https://www.figma.com/design/GR3q87aN987svwoSg3ImBs/Project-Mue?node-id=1-2).
The first layout ("Sample Test", 2026-09-21) is two elements on a plain
background: a large rounded canvas for the picture with camera and
photo-library buttons at its foot, and a pill-shaped player bar below it with
a waveform and a play button. Settings and share have no home in it yet.

## Phases

### Phase 1 — Scaffolding and core ✅ (this branch)

Goal: the repository builds, tests pass, and the architecture exists in code.

- [x] Plan and architecture documents.
- [x] `MueCore` package: frequency mapping, amplitude matrix, additive
      synthesiser, WAV encoder, unit tests.
- [x] `project.yml`, xcconfig-based signing, app skeleton that compiles.
- [x] CI: `swift test` + simulator build on macOS runners.
- [ ] Maintainer opens the project in Xcode and runs the skeleton on the
      13 mini (confirms signing setup works with a free Apple ID).

Done when: CI is green and the skeleton launches on the device.

### Phase 2 — The core loop, to the Figma layout

Goal: pick or take a photo → hear it → watch it come back. Nail the feel
before adding anything around it.

- [x] Pick an image from the photo library (PhotosPicker) or the camera.
- [x] Downsample to columns × rows, encode, render audio off the main thread.
- [x] Play through `AVAudioEngine` with `.playback` session category (plays
      through the silent switch), playhead over the photo.
- [x] Live spectrogram painted over the photo, left to right, with the same
      geometry as the encoded matrix.
- [x] Player pill: real loudness envelope as bars, filling in as it plays.
- [ ] Tune the feel on the device: default duration / band count / frequency
      range, spectrogram dynamic range, how the canvas transitions.
- [ ] Settings sheet (deferred until the core feels right).
- [ ] Share as WAV via `ShareLink` (deferred).

Done when: a photo played on the 13 mini is recognisable in the in-app
spectrogram *and* in a third-party spectrogram app on another device.

### Phase 3 — Native-only features

- [ ] Draw directly on the canvas (PencilKit) and hear it.
- [ ] "Fit duration to image" so the picture isn't stretched.
- [ ] Accelerate (vDSP) synthesis path for 512+ bands.
- [ ] Haptic tick on playback start/stop; Dynamic Type; VoiceOver labels.
- [ ] Optional stereo: colour channels → left/right.

### Phase 4 — Listen (the other half of the trick)

- [ ] Microphone input with a live, scrolling spectrogram.
- [ ] Freeze / save a frame of what was heard as an image.
- [ ] Two phones: one plays, one receives the picture.

### Phase 5 — Design and release

- [ ] Visual design pass (the current UI is deliberately plain).
- [ ] App icon, launch experience, onboarding.
- [ ] Paid developer account → TestFlight → App Store (if wanted).
- [ ] Rename from MUE if a better name shows up.

## Risks and open questions

- **Free Apple ID limits:** 7-day app expiry, max 3 apps, no TestFlight.
  Fine for development; a paid account is needed for distribution.
- **Bundle identifier uniqueness:** `com.example.*` IDs are usually taken.
  Every developer sets their own in `Config/Local.xcconfig`.
- **Spectrogram resolution vs. band count:** at low frequencies, adjacent
  bands can fall inside one FFT bin of the *display*. The audio is still
  correct; the display FFT size is tuned in phase 2.
- **Swift 6 strict concurrency with AVAudioEngine:** audio taps run on a
  realtime thread; frames are handed to the UI via an `AsyncStream`. Details
  in [ARCHITECTURE.md](ARCHITECTURE.md).

## Decision log

| Date | Decision | Why |
| --- | --- | --- |
| 2026-09-15 | Built a web prototype first (commit `f9c8966`). | Fastest way to prove the concept on a phone with no toolchain. Kept in history as a reference; removed from the tree. |
| 2026-09-19 | Go native iOS (Swift, SwiftUI). | Better audio/camera/drawing APIs, installable app, maintainer has a Mac with Xcode. |
| 2026-09-19 | Minimum iOS 18. | Maintainer is on the latest iOS; 18 keeps modern SwiftUI/Observation APIs while still building on Xcode 16 for contributors. |
| 2026-09-19 | XcodeGen instead of a committed `.xcodeproj`. | Project files are unmergeable by hand and the initial code is authored outside Xcode. |
| 2026-09-19 | No third-party dependencies. | Small surface, no supply-chain risk, easy for contributors. Accelerate/AVFoundation cover everything needed. |
| 2026-09-19 | Additive synthesis (one sine per row) rather than inverse-FFT. | Exact spectrogram, no phase artefacts, already proven in the prototype. vDSP makes it fast enough later. |
| 2026-09-19 | Name stays "MUE" for now. | Project codename; can change before release. |
| 2026-09-21 | Local Claude Code sessions for run/debug work, cloud sessions for engine/docs. | The cloud container has no Xcode or simulator; the run loop must live on the Mac. `scripts/` + `CLAUDE.md` make that loop scriptable. |
