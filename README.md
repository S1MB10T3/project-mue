# mue — image → sound

Turn a picture into sound. Every row of pixels becomes a sine wave at a fixed
frequency, every column a slice of time, and brightness the loudness. Look at
the resulting audio in a spectrogram and the picture comes back.

Inspired by Benn Jordan's video *"I Saved a PNG Image To A Bird"*.

**Status:** proof-of-concept. It works; the UI is functional but unpolished.

## Try it

It's a plain web app with no build step and no dependencies.

```sh
git clone https://github.com/s1mb10t3/project-mue.git
cd project-mue
npm start            # = python3 -m http.server 8080
```

Open <http://localhost:8080>. Pick an image, tap **Render & play**, and watch
the live spectrogram underneath fill in with your picture.

### On an iPhone (13 mini or anything running iOS 15+)

Option A — local Wi-Fi:

1. Run `npm start` on your computer.
2. Find the computer's LAN address (`ipconfig getifaddr en0` on macOS).
3. On the phone, open Safari at `http://<that-address>:8080`.

Option B — GitHub Pages (no computer needed after the first push):

1. Repo **Settings → Pages → Source: GitHub Actions**.
2. Push to `main`. The `Deploy to GitHub Pages` workflow publishes the app.
3. Open the Pages URL in Safari, tap **Share → Add to Home Screen** to install
   it as an app. It then works offline.

iPhone notes:

- **Choose or take a photo** opens the camera / photo library picker.
- **Save WAV** opens the share sheet, so you can AirDrop the file or save it to
  Files.
- If you hear nothing, flip the ring/silent switch: Safari's Web Audio obeys
  it.
- To really test the concept, play it out loud and point a second device
  running any spectrogram app at the speaker.

## How it works

```
image ──▶ resample to cols × rows ──▶ brightness matrix ──▶ one sine per row,
                                                            gain = row brightness over time
                                                        ──▶ OfflineAudioContext render
                                                        ──▶ AudioBuffer (play / save WAV)
```

- `src/mapping.js` — pure functions: row ↔ frequency (linear or log spacing),
  luminance, gamma/invert/floor, peak normalisation. Unit tested.
- `src/image.js` — loads a file, downsamples it in halving steps (so big photos
  don't alias), converts pixels to the amplitude matrix.
- `src/synth.js` — builds an `OfflineAudioContext` with one `OscillatorNode`
  + `GainNode` per row; the gain uses `setValueCurveAtTime` with the row's
  brightness curve, so columns are smoothly interpolated. Oscillator start
  times are jittered by up to one period to randomise phase (avoids a click
  at t = 0). Rendering is faster than real time.
- `src/player.js` — real-time playback through an `AnalyserNode`.
- `src/spectrogram.js` — paints the analyser output into a canvas with exactly
  the same cols × rows geometry and frequency mapping as the input, so the
  picture should land on top of where it came from.
- `src/wav.js` — 16-bit PCM WAV encoder. Unit tested.
- `src/app.js` — DOM wiring only.

### Settings

| Setting | Default | What it does |
| --- | --- | --- |
| Duration | 6 s | Length of the sound. Columns = duration × columns/second. |
| Bands | 128 | Number of image rows = number of oscillators. |
| Low / high freq | 400–8000 Hz | Bottom and top row frequencies. |
| Scale | linear | Linear matches most spectrogram apps; log sounds more musical. |
| Columns per second | 40 | Horizontal resolution in time. |
| Gamma | 1.6 | > 1 darkens midtones (cleaner, less hiss); < 1 brightens them. |
| Silence floor | 0.05 | Pixels darker than this are muted. |
| Invert | off | Dark pixels become loud (for black-on-white drawings). |

The image is stretched to the cols × rows grid; the preview shows exactly what
gets encoded.

## Development

```sh
npm test        # node's built-in test runner, no deps
npm run icons   # regenerate icons/*.png from scripts/make-icons.mjs
```

ES modules need to be served over HTTP; opening `index.html` directly from
disk won't work.

## Roadmap / ideas

- [ ] UI polish (this pass is deliberately plain)
- [ ] Draw / paint directly on the canvas
- [ ] Stereo (e.g. colour channels → left/right)
- [ ] Microphone input: decode a picture *from* sound (the other half of the trick)
- [ ] Share links / presets

Contributions welcome — open an issue or PR.

## License

MIT — see [LICENSE](LICENSE).
