import { test } from 'node:test';
import assert from 'node:assert/strict';
import { frequencyForRow, rowForFrequency, luminance, pixelsToMatrix, normalize } from '../src/mapping.js';

test('top row is fmax, bottom row is fmin (linear and log)', () => {
  for (const scale of ['linear', 'log']) {
    assert.equal(frequencyForRow(0, 100, 200, 8000, scale), 8000);
    assert.ok(Math.abs(frequencyForRow(99, 100, 200, 8000, scale) - 200) < 1e-9);
  }
});

test('linear scale spaces rows evenly in Hz', () => {
  const a = frequencyForRow(10, 101, 0, 1000, 'linear');
  const b = frequencyForRow(11, 101, 0, 1000, 'linear');
  assert.ok(Math.abs(b - a + 10) < 1e-9);
});

test('log scale spaces rows evenly in octaves', () => {
  const rows = 41; // 40 steps over 4 octaves = 10 rows per octave
  const f0 = frequencyForRow(0, rows, 500, 8000, 'log');
  const f10 = frequencyForRow(10, rows, 500, 8000, 'log');
  assert.ok(Math.abs(f0 / f10 - 2) < 1e-9);
});

test('rowForFrequency inverts frequencyForRow', () => {
  for (const scale of ['linear', 'log']) {
    for (const row of [0, 7, 63, 127]) {
      const f = frequencyForRow(row, 128, 400, 8000, scale);
      assert.ok(Math.abs(rowForFrequency(f, 128, 400, 8000, scale) - row) < 1e-6, `${scale} row ${row}`);
    }
  }
});

test('luminance of white is 1 and black is 0', () => {
  assert.ok(Math.abs(luminance(255, 255, 255) - 1) < 1e-9);
  assert.equal(luminance(0, 0, 0), 0);
});

test('pixelsToMatrix handles invert, gamma, floor and alpha', () => {
  // 2x1 image: white opaque, white transparent
  const rgba = new Uint8ClampedArray([255, 255, 255, 255, 255, 255, 255, 0]);
  let m = pixelsToMatrix(rgba, 2, 1);
  assert.equal(m.rows, 1);
  assert.equal(m.cols, 2);
  assert.ok(Math.abs(m.data[0] - 1) < 1e-6);
  assert.equal(m.data[1], 0);

  m = pixelsToMatrix(rgba, 2, 1, { invert: true });
  assert.ok(Math.abs(m.data[0]) < 1e-6);
  assert.equal(m.data[1], 1);

  const grey = new Uint8ClampedArray([128, 128, 128, 255]);
  const g1 = pixelsToMatrix(grey, 1, 1, { gamma: 1 }).data[0];
  const g2 = pixelsToMatrix(grey, 1, 1, { gamma: 2 }).data[0];
  assert.ok(Math.abs(g2 - g1 * g1) < 1e-6);

  assert.equal(pixelsToMatrix(grey, 1, 1, { floor: 0.9 }).data[0], 0);
});

test('normalize scales peak to target and leaves silence alone', () => {
  const s = new Float32Array([0.1, -0.5, 0.25]);
  const k = normalize(s, 0.9);
  assert.ok(Math.abs(k - 1.8) < 1e-6);
  assert.ok(Math.abs(s[1] + 0.9) < 1e-6);
  const z = new Float32Array([0, 0]);
  assert.equal(normalize(z), 1);
});
