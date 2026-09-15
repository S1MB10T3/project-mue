/**
 * Live spectrogram painter. The canvas has exactly the same cols x rows
 * geometry as the encoded image, and gets filled left-to-right as playback
 * proceeds, so the picture should re-emerge on top of where it started.
 */
import { frequencyForRow } from './mapping.js';

// Small "inferno"-style colour ramp: black -> purple -> orange -> pale yellow.
const STOPS = [
  [0.0, 0, 0, 4],
  [0.25, 87, 16, 110],
  [0.5, 188, 55, 84],
  [0.75, 249, 142, 9],
  [1.0, 252, 255, 164],
];
const LUT = new Uint8Array(256 * 3);
for (let i = 0; i < 256; i++) {
  const t = i / 255;
  let k = 0;
  while (k < STOPS.length - 2 && t > STOPS[k + 1][0]) k++;
  const [t0, r0, g0, b0] = STOPS[k];
  const [t1, r1, g1, b1] = STOPS[k + 1];
  const u = (t - t0) / (t1 - t0);
  LUT[i * 3] = r0 + (r1 - r0) * u;
  LUT[i * 3 + 1] = g0 + (g1 - g0) * u;
  LUT[i * 3 + 2] = b0 + (b1 - b0) * u;
}

export class SpectrogramView {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.column = null;
    this.binForRow = null;
    this.lastX = -1;
  }

  /**
   * Prepare for a run with the given geometry and frequency mapping.
   * @param {object} p  {rows, cols, fmin, fmax, scale, sampleRate, fftSize}
   */
  configure(p) {
    const { rows, cols, fmin, fmax, scale, sampleRate, fftSize } = p;
    this.rows = rows;
    this.cols = cols;
    this.canvas.width = cols;
    this.canvas.height = rows;
    this.ctx.fillStyle = '#000';
    this.ctx.fillRect(0, 0, cols, rows);
    this.column = this.ctx.createImageData(1, rows);
    this.lastX = -1;

    // For every pixel row, the [start, end) range of FFT bins it covers.
    const binCount = fftSize / 2;
    const hzPerBin = sampleRate / fftSize;
    this.binForRow = new Int32Array(rows * 2);
    // Row edges are at fractional rows y - 0.5 and y + 0.5. Invert the
    // mapping numerically by scanning bins into rows.
    const edges = new Float64Array(rows + 1);
    for (let y = 0; y <= rows; y++) edges[y] = y - 0.5;
    for (let y = 0; y < rows; y++) {
      // Frequencies of the top and bottom edge of this pixel row.
      const fTop = frequencyForRow(edges[y], rows, fmin, fmax, scale);
      const fBot = frequencyForRow(edges[y + 1], rows, fmin, fmax, scale);
      let b0 = Math.floor(Math.min(fTop, fBot) / hzPerBin);
      let b1 = Math.ceil(Math.max(fTop, fBot) / hzPerBin);
      if (b1 <= b0) b1 = b0 + 1;
      b0 = Math.max(0, Math.min(binCount - 1, b0));
      b1 = Math.max(b0 + 1, Math.min(binCount, b1));
      this.binForRow[y * 2] = b0;
      this.binForRow[y * 2 + 1] = b1;
    }
    this.freq = new Uint8Array(binCount);
  }

  /**
   * Paint the current analyser frame at horizontal position t in [0, 1].
   * Fills any skipped columns so slow frames don't leave gaps.
   */
  paint(analyser, t) {
    if (!this.binForRow) return;
    const x = Math.min(this.cols - 1, Math.floor(t * this.cols));
    if (x <= this.lastX) return;
    analyser.getByteFrequencyData(this.freq);
    const px = this.column.data;
    for (let y = 0; y < this.rows; y++) {
      const b0 = this.binForRow[y * 2];
      const b1 = this.binForRow[y * 2 + 1];
      let m = 0;
      for (let b = b0; b < b1; b++) if (this.freq[b] > m) m = this.freq[b];
      px[y * 4] = LUT[m * 3];
      px[y * 4 + 1] = LUT[m * 3 + 1];
      px[y * 4 + 2] = LUT[m * 3 + 2];
      px[y * 4 + 3] = 255;
    }
    for (let cx = this.lastX + 1; cx <= x; cx++) this.ctx.putImageData(this.column, cx, 0);
    this.lastX = x;
  }

  clear() {
    this.ctx.fillStyle = '#000';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
    this.lastX = -1;
  }
}
