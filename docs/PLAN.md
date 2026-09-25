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
The first layout ("Sample Test", 2026-09-21) is a large rounded canvas for
the picture with camera and photo-library buttons at its foot, and a
pill-shaped player bar below it.

The 2026-09-25 paper sketch splits that into two screens: **Capture** (the
canvas and its two buttons, full height) and **Edit** (description block
with thumbnail and text, the sound's waveform, four vertical EQ sliders,
and play / save at the bottom). Synth controls (tuning, timbre, effects)
sit with the EQ. The app follows the sketch; the Figma file will catch up.

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

### Phase 2 — The core loop ✅

Goal: pick or take a photo → hear it.

- [x] Live camera feed on the canvas; shutter and library buttons.
- [x] Downsample to columns × rows, encode, render audio off the main thread.
- [x] Play through `AVAudioEngine` with `.playback` session category (plays
      through the silent switch), progress shown by the waveform bars.
- [x] Player pill: real loudness envelope as bars, filling in as it plays.

### Phase 3 — Capture → Edit

Goal: the two-screen flow from the 2026-09-25 sketch. Capture is one
screen; everything you do to the sound is a second screen you push to.

- [x] Two screens: `CaptureView` → `EditView`. Model split into `AppModel`
      (capture) and `SoundEditor` (one sound's edit state and audio).
- [x] Description block: thumbnail plus on-device Vision labels of the photo.
- [x] Waveform: the EQ'd mix's envelope, filling in during playback.
- [x] EQ: four vertical sliders, one per horizontal strip of the picture.
      The sound is rendered as four stems and each slider is a live gain,
      so moving one is instant. Cut-only (0…1) for now.
- [x] Synth — tuning: quantise rows to chromatic / major / minor /
      pentatonic (C-rooted, A4 = 440). Re-renders.
- [x] Synth — timbre: sine / triangle / square / saw from a few band-limited
      partials. Re-renders.
- [x] Synth — effects: reverb and delay wet/dry, live, in the engine graph.
- [x] Save: share the EQ'd mix as a WAV via the share sheet.
- [ ] Try it on the 13 mini and tune the feel: default duration, band
      count, frequency range, whether cut-only EQ is enough, whether the
      partial counts sound right, what the effects defaults should be.
- [ ] Bake reverb and delay into the saved WAV (offline render through the
      same engine graph) so what you save is what you heard.
- [ ] Boost as well as cut on the EQ (gains above 1 with headroom).
- [ ] Draw / paint directly on the canvas (PencilKit) and hear it.
- [ ] "Fit duration to image" so the picture isn't stretched.
- [ ] Accelerate (vDSP) synthesis path for 512+ bands / more partials.
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
  correct. No longer relevant to the app's own canvas (no live spectrogram
  there), but it returns in phase 4's scrolling view.
- **Swift 6 strict concurrency with AVAudioEngine:** audio taps run on a
  realtime thread; the playback tap now only reports a position. Details
  in [ARCHITECTURE.md](ARCHITECTURE.md). Note that `AVAudioNodeTapBlock` is
  not `Sendable` in the AVFoundation overlay, so a tap closure written inside
  a `@MainActor` type silently inherits that isolation and traps on the render
  thread; the closure must be marked `@Sendable` explicitly.

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
| 2026-09-21 | The photo fills the canvas, cropped, instead of being letterboxed inside it. | Looks better; the canvas stops reading as a grey frame around a small picture. Trade-off: on a landscape photo only ~40% of the width is visible, so you see less of the picture than is in the sound. |
| 2026-09-21 | Playback progress is shown by the player pill's bars, not a playhead over the photo. | It belongs with the transport controls, and a playhead tracks the *uncropped* picture, so after the fill change it spent most of playback off-canvas. |
| 2026-09-21 | Removed the live spectrogram from the canvas; the photo stays untouched while it plays. | The bars carry progress, and after the fill change the paint front spent much of playback cropped off-canvas. Cost: the app no longer shows the picture coming back — that now has to be seen in a third-party spectrogram app, until phase 4 builds the real listening view. `SpectrogramAnalyzer` and `SpectrogramColumnMapper` stay in `MueCore`, tested, for that. |
| 2026-09-25 | Two screens: Capture → Edit, per the paper sketch. | Capture stays a viewfinder; everything that changes the sound gets room of its own. Model split accordingly (`AppModel` / `SoundEditor`). |
| 2026-09-25 | EQ bands are horizontal strips of the picture, implemented as pre-rendered stems with live per-node gains. | In MUE a frequency band *is* a strip of rows, so the EQ visibly carves the image. Stems make slider moves instant instead of a re-render. Stems share one seed so they sum exactly to the full render. |
| 2026-09-25 | Synth = tuning (scale quantisation) + timbre (band-limited partials) + effects (reverb, delay). | Tuning and timbre live in `MueCore` and re-render; effects live in the `AVAudioEngine` graph and are live. A playable keyboard is deferred. |
| 2026-09-25 | Description = on-device Vision classification labels. | Zero network, zero dependencies, and it fits the sketch's two lines. Can become editable text later. |
| 2026-09-25 | Save = WAV via the share sheet; effects not yet baked in. | Baking effects needs an offline render through the engine graph; queued as the next task so the first version ships simply. |
| 2026-09-21 | The canvas shows a live camera feed; `AVCaptureSession` replaces the modal `UIImagePickerController`. | The Figma annotation on the canvas frame asks for it: "Live camera feed and once a shot as been captured or image has been uploaded it stays here." A modal picker cannot express that — the feed *is* the canvas's resting state. |
| 2026-09-21 | Camera access is requested when the canvas appears, not behind a button. | Usually a bad idea, but here the live feed is the first thing the screen is supposed to show, so the request is in context at launch rather than cold. |
| 2026-09-21 | The camera button is a shutter while the feed is up, and a "back to camera" control once a picture is showing. | The design has room for one camera button, and the annotation does not say how to get from a captured shot back to the feed. Revisit if a separate control earns its place. |
