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
│   │   ├── AmplitudeMatrix.swift     rows × columns of loudness, from RGBA
│   │   ├── AdditiveSynthesizer.swift matrix → samples
│   │   └── WAVEncoder.swift          samples → .wav bytes
│   └── Tests/MueCoreTests/
├── Mue/                     the iOS app (SwiftUI)
│   ├── App/                 entry point, AppModel
│   ├── Features/            one folder per screen / feature
│   ├── Services/            wrappers around Apple frameworks
│   └── Resources/           asset catalog
├── docs/                    this file, PLAN.md
└── .github/workflows/ci.yml
```

## Data flow

```
 PhotosPicker / Camera / PencilKit
            │  UIImage
            ▼
   ImageLoader (Services)          CGContext draw → tightly packed RGBA,
            │  [UInt8] RGBA           columns × rows, top row first
            ▼
   AmplitudeMatrix.fromRGBA        luminance · alpha → invert? → gamma → floor
            │  rows × columns Float in 0…1
            ▼
   AdditiveSynthesizer.render      one sine per row, frequency from
            │  RenderedAudio         FrequencyMapping, gain interpolated
            │                        between columns, random start phase,
            │                        10 ms master fade, peak-normalised
            ├────────────────────► WAVEncoder → ShareLink (.wav)
            ▼
   AudioPlayer (Services)          AVAudioEngine: PlayerNode → MainMixer
            │  tap on player node     AVAudioSession category .playback
            ▼
   SpectrogramAnalyzer (MueCore, phase 2)   FFT per tap buffer → dB per bin
            │  AsyncStream<Frame>           → max over bins per image row
            ▼
   SpectrogramView (Features)      Canvas painting columns × rows, same
                                   geometry as the preview
```

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

### `AdditiveSynthesizer`

For each non-silent row: frequency from the mapping, a random start phase
(seedable for tests), a phasor rotated once per sample (no `sin` in the inner
loop), gain linearly interpolated between the row's column values across the
duration. Rows accumulate into one buffer, a 10 ms fade in/out is applied, and
the result is peak-normalised to 0.9.

Cost is `rows × samples`; 128 bands × 6 s × 44.1 kHz ≈ 34 M iterations, well
under 100 ms with optimisation. Phase 3 adds a vDSP path for 512+ bands.

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

`AppModel` is a `@MainActor @Observable` class holding the chosen image, the
current `EncodingSettings`, the encoded matrix, the rendered audio, and
playback state. Views read it through the environment. Long work (resampling,
rendering) runs in a detached `Task`; everything crossing the boundary is a
`Sendable` value type from `MueCore`, which is what makes strict concurrency
painless here.

### Services

- `ImageLoader` — `PhotosPickerItem`/`UIImage` → RGBA bytes at a given size.
  Downscales in halving steps (large photos alias badly in one step).
- `AudioPlayer` — owns the `AVAudioEngine`, configures `AVAudioSession`
  (`.playback` so the silent switch does not mute), plays a
  `RenderedAudio`, exposes the playhead and a tap that yields analysis frames
  through an `AsyncStream`. Tap callbacks run on a realtime thread: do the FFT
  there, publish a small `Sendable` frame, never touch UI state.
- `Exporter` — writes WAV to a temporary URL for `ShareLink`.

### Features (phase 2 onward)

- `Encode` — picker, encoded preview with playhead, transport buttons.
- `Spectrogram` — live view painted into a `CGImage` the size of the matrix
  and drawn with `Canvas`; nearest-neighbour scaling keeps pixels crisp.
- `Settings` — form bound to `EncodingSettings`, persisted via `@AppStorage`
  as JSON.
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
