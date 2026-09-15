/**
 * Image -> audio renderer.
 *
 * Every image row becomes a sine oscillator at a fixed frequency; the row's
 * pixel brightness over time (its columns) drives that oscillator's gain.
 * Rendering happens offline (faster than real time) with an
 * OfflineAudioContext, so the result is a plain AudioBuffer we can play,
 * replay, and export as WAV.
 */
import { frequencyForRow, normalize } from './mapping.js';

const OfflineCtx = globalThis.OfflineAudioContext || globalThis.webkitOfflineAudioContext;

/**
 * @param {{rows:number, cols:number, data:Float32Array}} matrix
 * @param {object} opts
 * @param {number} opts.duration     seconds
 * @param {number} opts.fmin         Hz, bottom row
 * @param {number} opts.fmax         Hz, top row
 * @param {'linear'|'log'} opts.scale
 * @param {number} [opts.sampleRate=44100]
 * @param {number} [opts.fade=0.01]  master fade in/out in seconds (avoids clicks)
 * @returns {Promise<AudioBuffer>}
 */
export async function renderImageToAudio(matrix, opts) {
  if (!OfflineCtx) throw new Error('OfflineAudioContext is not supported in this browser');
  const { rows, cols, data } = matrix;
  const { duration, fmin, fmax, scale, sampleRate = 44100, fade = 0.01 } = opts;
  const length = Math.max(1, Math.ceil(duration * sampleRate));
  const ctx = new OfflineCtx(1, length, sampleRate);

  // Master bus: scale by 1/sqrt(rows) so many bright rows don't blow up, then
  // fade the edges. We peak-normalise afterwards anyway.
  const master = ctx.createGain();
  master.gain.setValueAtTime(0, 0);
  master.gain.linearRampToValueAtTime(1 / Math.sqrt(rows), Math.min(fade, duration / 2));
  master.gain.setValueAtTime(1 / Math.sqrt(rows), Math.max(0, duration - fade));
  master.gain.linearRampToValueAtTime(0, duration);
  master.connect(ctx.destination);

  const nyquist = sampleRate / 2;
  let active = 0;
  for (let r = 0; r < rows; r++) {
    const f = frequencyForRow(r, rows, fmin, fmax, scale);
    if (f <= 0 || f >= nyquist) continue;

    // Gain curve for this row over the whole duration. setValueCurveAtTime
    // interpolates linearly between points, which smooths column edges.
    let curve;
    let silent = true;
    if (cols >= 2) {
      curve = data.subarray(r * cols, (r + 1) * cols);
      for (let c = 0; c < cols; c++) if (curve[c] > 0) { silent = false; break; }
      curve = Float32Array.from(curve); // setValueCurveAtTime copies, but be safe on old Safari
    } else {
      const v = data[r * cols];
      silent = v <= 0;
      curve = new Float32Array([v, v]);
    }
    if (silent) continue;

    const osc = ctx.createOscillator();
    osc.type = 'sine';
    osc.frequency.value = f;
    const g = ctx.createGain();
    g.gain.setValueCurveAtTime(curve, 0, duration);
    osc.connect(g).connect(master);
    // Oscillators always start at phase 0. Staggering the start by up to one
    // period gives each partial a random phase, so they don't all pile up
    // into a click at t = 0.
    osc.start(Math.random() / f);
    osc.stop(duration);
    active++;
  }

  const buffer = await ctx.startRendering();
  if (active > 0) normalize(buffer.getChannelData(0), 0.9);
  return buffer;
}
