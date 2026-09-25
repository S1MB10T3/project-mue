# MUE — architecture

## Principles

1. **The interesting logic is pure.** Everything that turns pixels into
   samples lives in `MueCore`, a Swift package with no UI and no Apple
   framework dependencies beyond Foundation. It is value types and static
   functions, `Sendable` throughout, and covered by unit tests.
2. **The app is thin.** SwiftUI views, an observable model, and small
   services that wrap Apple frameworks (PhotosUI, AVFoundation, Core
   Graphics). If a piece of code could be tested without a device, it belongs
   in `MueCore`.
3. **Zero third-party dependencies.** Ever, unless there is a very good
   reason and it is discussed in an issue first.
4. **Swift 6 language mode, strict concurrency.** Cheaper to start strict
   than to migrate later.

## Repository layout

```
project-mue/
├── project.yml              XcodeGen spec → generates Mue.xcodeproj (gitignored)
├── Config/
│   ├── Shared.xcconfig      defaults for every developer
│   └── Local.xcconfig       YOUR bundle id + team id (gitignored, see example)
├── MueCore/                 Swift package: the engine
│   ├── Package.swift
│   ├── Sources/MueCore/
│   │   ├── EncodingSettings.swift    user-facing parameters
│   │   ├── FrequencyMapping.swift    row ↔ frequency (linear / log)
│   │   ├── Tuning.swift              optional scale quantisation of rows
│   │   ├── Waveform.swift            timbre as a few band-limited partials
│   │   ├── AmplitudeMatrix.swift     rows × columns of loudness, from RGBA
│   │   ├── AdditiveSynthesizer.swift matrix → samples, or → per-band stems
│   │   ├── RenderedAudio+Mix.swift   sum stems with gains; normalise together
│   │   ├── RenderedAudio+Envelope.swift
│   │   ├── SpectrogramAnalyzer.swift FFT (for the phase 4 listening view)
│   │   ├── SpectrogramColumnMapper.swift
│   │   └── WAVEncoder.swift          samples → .wav bytes
│   └── Tests/MueCoreTests/
├── Mue/                     the iOS app (SwiftUI)
│   ├── App/                 entry point, Sound, AppModel, SoundEditor
│   ├── Features/            Capture/, Edit/, Player/
│   ├── Services/            CameraSession, AudioPlayer, ImageLoader,
│   │                        PhotoDescriber, WAVExport
│   └── Resources/           asset catalog
├── docs/                    this file, PLAN.md
└── .github/workflows/ci.yml
```

## Data flow

```
 Capture screen                         Edit screen (one SoundEditor per Sound)
 ──────────────                         ────────────────────────────────────────
 CameraSession / PhotosPicker
      │ UIImage
      ▼
 ImageLoader.prepare ──▶ Sound ──push──▶ ImageLoader.rgba      tightly packed RGBA,
 (orientation, ≤1024px)                       │                columns × rows
                                              ▼
                                        AmplitudeMatrix.fromRGBA
                                              │
                                              ▼
                                        AdditiveSynthesizer.renderStems   4 stems, one per
                                              │  [RenderedAudio]          strip of rows; tuning
                                              │                           + waveform applied;
                                              │                           shared seed; normalised
                                              │                           together
                              ┌───────────────┼──────────────────┐
                              ▼               ▼                  ▼
                        RenderedAudio.mix   AudioPlayer       WAVExport (share sheet)
                        (gains) → envelope  4 player nodes → submix → reverb → delay → out
                                            volume = EQ gain     wet/dry = sliders

 PhotoDescriber (Vision, on device) ──▶ description text, in parallel with the render
```

Tuning and timbre change the oscillators, so they re-render (a few hundred
milliseconds, off the main actor, generation-guarded). EQ gains and effect
mixes are live properties on engine nodes and never re-render.

## MueCore

### `EncodingSettings`

Plain `Codable` struct with the user-facing knobs and their defaults:

| Field | Default | Meaning |
| --- | --- | --- |
| `duration` | 6 s | length of the sound |
| `bands` | 128 | image rows = number of oscillators |
| `minFrequency` / `maxFrequency` | 400 / 8000 Hz | bottom / top row |
| `scale` | `.linear` | `.linear` matches spectrogram apps; `.logarithmic` sounds musical |
| `columnsPerSecond` | 40 | time resolution |
| `gamma` | 1.6 | > 1 darkens midtones (less hiss) |
| `floor` | 0.05 | pixels darker than this are silent |
| `invert` | false | dark pixels loud (black-on-white drawings) |

`columns` is derived (`duration × columnsPerSecond`, min 2).

### `FrequencyMapping`

Row 0 is the **top** of the image and the **highest** frequency, like a
spectrogram. `frequency(forRow:)` accepts a fractional row so the spectrogram
view can ask for pixel edges; `row(forFrequency:)` is the inverse.

### `AmplitudeMatrix`

Row-major `[Float]` in 0…1 plus `rows`/`columns`. Built from RGBA bytes with
Rec. 709 luminance, alpha multiplied in (transparent = silent), then invert →
gamma → floor. No image APIs: the app does the resampling with Core Graphics
and hands over bytes, so the package stays platform-neutral and testable.

### `Tuning` and `Waveform`

`Tuning` snaps a row's frequency to the nearest note of a C-rooted scale in
12-TET (`free` leaves it alone). `Waveform` is a short list of `Partial`s
(harmonic number, relative amplitude): sine is one partial; saw, square and
triangle use four to six band-limited partials, enough for the character
without multiplying synthesis cost by the full series.

### `AdditiveSynthesizer`

For each non-silent row: frequency from the mapping, then tuning; a start
phase derived from the seed *and the row index*; for each partial a phasor
rotated once per sample (no `sin` in the inner loop), gain linearly
interpolated between the row's column values. Rows accumulate into one
buffer, a 10 ms fade in/out is applied, and the result is peak-normalised
to 0.9 unless `Options.normalize` is off.

`Options.rows` restricts a render to a row range. `renderStems` uses it to
render `n` contiguous bands with one shared seed and `normalizeTogether`,
so the stems sum exactly to a full render: that is what makes the EQ a set
of live gains rather than a re-render.

Cost is `rows × partials × samples`; 128 sine bands × 6 s × 44.1 kHz ≈ 34 M
iterations, well under 100 ms with optimisation; saw is 6× that. A vDSP path
is on the plan for more bands or partials.

Output is `RenderedAudio` (`sampleRate`, mono `[Float]`). The app converts it
into an `AVAudioPCMBuffer` for playback; the core never imports AVFoundation.

### `WAVEncoder`

16-bit PCM, little-endian, any channel count. Used for export only.

### Testing

`swift test` in `MueCore/`. Tests are behavioural rather than snapshot:
frequency endpoints, octave spacing, inverse mapping, pixel conversion rules,
Goertzel power at the expected frequency after synthesis, envelope decay,
peak normalisation, WAV header bytes.

## App

### Model

Two `@MainActor @Observable` classes, one per screen:

- `AppModel` owns the capture screen: camera access, the live feed, and how
  a picture gets chosen. Requests (capture, library pick) take a token so
  the newest one wins whichever finishes first. A chosen picture becomes a
  `Sound` (photo + prepared `CGImage`, identity by UUID) and setting
  `AppModel.sound` pushes the edit screen; popping clears it.
- `SoundEditor` owns one `Sound`'s edit state: the settings, the rendered
  stems, EQ gains, effect mixes, envelope, description, playback state. It
  is created by `EditView` and lives as long as the screen.

Long work (resampling, rendering, Vision) runs off the main actor;
everything crossing the boundary is a `Sendable` value type, which is what
makes strict concurrency painless here. Re-renders are generation-guarded
so a stale result never lands.

### Services

- `ImageLoader` — `PhotosPickerItem`/`UIImage` → RGBA bytes at a given size.
  Downscales in halving steps (large photos alias badly in one step).
- `CameraSession` — `AVCaptureSession` on its own serial queue; stills via
  per-capture delegates that always resume their caller, even if the session
  is stopped mid-capture. Stills are pinned to portrait.
- `AudioPlayer` — owns the `AVAudioEngine` graph: one `AVAudioPlayerNode`
  per stem → submix → `AVAudioUnitReverb` → `AVAudioUnitDelay` → main mixer.
  Configures `AVAudioSession` (`.playback` so the silent switch does not
  mute). Stems start on one shared host time so they stay sample-aligned.
  A tap on the first stem counts frames for the playhead and does nothing
  else on the realtime thread; it is explicitly `@Sendable` so it does not
  inherit main-actor isolation.
- `PhotoDescriber` — `VNClassifyImageRequest` on a background queue; a few
  confident labels become the description text.
- `WAVExport` — a `Transferable` that encodes the EQ'd mix when the share
  sheet asks for it. Effects are not baked in yet (see the plan).

### Features

- `Capture/` — `CaptureView` (the canvas with the live feed, shutter and
  library buttons) and `CameraPreviewView` (an `AVCaptureVideoPreviewLayer`
  host).
- `Edit/` — `EditView` composes `DescriptionView`, the waveform, `EQView`
  (four `VerticalSlider`s, low frequencies on the left) and
  `SynthControlsView` (tuning menu, waveform segments, reverb and delay
  sliders), with play and `ShareLink` in a bottom bar.
- `Player/` — `WaveformView`, the envelope bars with progress fill.
- `Listen` (phase 4) — microphone → scrolling spectrogram → save as image.

### Build configuration

- `project.yml` declares one app target depending on the local `MueCore`
  package. `xcodegen generate` produces `Mue.xcodeproj`, which is gitignored.
- `Config/Shared.xcconfig` sets defaults and optionally includes
  `Config/Local.xcconfig`, where each developer puts their own
  `MUE_BUNDLE_ID` and `MUE_TEAM_ID`. Signing style is automatic, so a free
  Apple ID (Personal Team) works.
- Info.plist is generated by XcodeGen from `project.yml` (`info.properties`),
  so privacy usage strings and orientation settings live in one place.

### CI

`.github/workflows/ci.yml` on macOS runners: `swift test` for the package,
then `xcodegen generate` and an unsigned `xcodebuild` for the iOS Simulator.
Nothing in CI needs secrets.

## Conventions

- One type per file, file named after the type.
- Public API in `MueCore` is documented with `///` comments.
- Units in names when ambiguous: `durationSeconds` is fine, `duration` is
  fine when the type documents the unit; never mix.
- Commit messages: imperative, explain *why* in the body when not obvious.
