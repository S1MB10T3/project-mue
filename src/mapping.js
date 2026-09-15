/**
 * Pure functions that define how an image maps onto a spectrogram.
 *
 * Convention: row 0 is the TOP of the image and maps to the HIGHEST
 * frequency, just like a spectrogram display. Column 0 is the start of time.
 *
 * These are kept free of DOM/Web Audio so they can be unit tested in Node.
 */

/**
 * Frequency (Hz) for a given image row.
 * @param {number} row       0 .. rows-1 (0 = top)
 * @param {number} rows      total number of rows / frequency bands
 * @param {number} fmin      lowest frequency (bottom row)
 * @param {number} fmax      highest frequency (top row)
 * @param {'linear'|'log'} scale
 */
export function frequencyForRow(row, rows, fmin, fmax, scale = 'linear') {
  if (rows <= 1) return fmax;
  const u = 1 - row / (rows - 1); // 1 at top, 0 at bottom
  if (scale === 'log') {
    return fmin * Math.pow(fmax / fmin, u);
  }
  return fmin + (fmax - fmin) * u;
}

/**
 * Inverse of frequencyForRow, returned as a continuous (fractional) row.
 * Used by the live spectrogram view to find which pixel a frequency lands on.
 */
export function rowForFrequency(f, rows, fmin, fmax, scale = 'linear') {
  if (rows <= 1) return 0;
  let u;
  if (scale === 'log') {
    u = Math.log(f / fmin) / Math.log(fmax / fmin);
  } else {
    u = (f - fmin) / (fmax - fmin);
  }
  return (1 - u) * (rows - 1);
}

/** Rec. 709 luma, 0..1, from 8-bit RGB. */
export function luminance(r, g, b) {
  return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
}

/**
 * Convert raw RGBA pixels into a rows x cols amplitude matrix in [0, 1].
 *
 * @param {Uint8ClampedArray|Uint8Array} rgba   pixel data, length = 4*rows*cols
 * @param {number} cols
 * @param {number} rows
 * @param {object} opts
 * @param {boolean} [opts.invert=false]   true => dark pixels are loud
 * @param {number}  [opts.gamma=1]        >1 crushes shadows, <1 lifts them
 * @param {number}  [opts.floor=0]        values below this become silence
 * @returns {{rows:number, cols:number, data:Float32Array}}  data[row*cols+col]
 */
export function pixelsToMatrix(rgba, cols, rows, opts = {}) {
  const { invert = false, gamma = 1, floor = 0 } = opts;
  const data = new Float32Array(rows * cols);
  for (let i = 0, p = 0; i < rows * cols; i++, p += 4) {
    let v = luminance(rgba[p], rgba[p + 1], rgba[p + 2]);
    // Treat transparent pixels as black (silent) before inversion.
    const a = rgba[p + 3] / 255;
    v *= a;
    if (invert) v = 1 - v;
    if (gamma !== 1) v = Math.pow(v, gamma);
    if (v < floor) v = 0;
    data[i] = v;
  }
  return { rows, cols, data };
}

/**
 * Peak-normalise a Float32Array in place so |max| == target. Returns the
 * scale factor applied (1 if the signal was silent).
 */
export function normalize(samples, target = 0.9) {
  let peak = 0;
  for (let i = 0; i < samples.length; i++) {
    const a = Math.abs(samples[i]);
    if (a > peak) peak = a;
  }
  if (peak === 0) return 1;
  const k = target / peak;
  for (let i = 0; i < samples.length; i++) samples[i] *= k;
  return k;
}
