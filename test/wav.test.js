import { test } from 'node:test';
import assert from 'node:assert/strict';
import { encodeWav } from '../src/wav.js';

test('encodeWav writes a valid 16-bit PCM header and samples', () => {
  const buf = encodeWav([new Float32Array([0, 1, -1, 0.5])], 44100);
  const v = new DataView(buf);
  const ascii = (o, n) => String.fromCharCode(...new Uint8Array(buf, o, n));
  assert.equal(buf.byteLength, 44 + 4 * 2);
  assert.equal(ascii(0, 4), 'RIFF');
  assert.equal(ascii(8, 4), 'WAVE');
  assert.equal(v.getUint32(4, true), 36 + 8);
  assert.equal(v.getUint16(20, true), 1); // PCM
  assert.equal(v.getUint16(22, true), 1); // mono
  assert.equal(v.getUint32(24, true), 44100);
  assert.equal(v.getUint16(34, true), 16);
  assert.equal(ascii(36, 4), 'data');
  assert.equal(v.getUint32(40, true), 8);
  assert.equal(v.getInt16(44, true), 0);
  assert.equal(v.getInt16(46, true), 0x7fff);
  assert.equal(v.getInt16(48, true), -0x8000);
  assert.equal(v.getInt16(50, true), 16383); // 0.5 * 0x7fff truncated
});

test('encodeWav clips out-of-range samples and interleaves channels', () => {
  const buf = encodeWav([new Float32Array([2, -2]), new Float32Array([0.5, -0.5])], 8000);
  const v = new DataView(buf);
  assert.equal(v.getUint16(22, true), 2);
  assert.equal(v.getUint32(28, true), 8000 * 4);
  assert.equal(v.getInt16(44, true), 0x7fff);   // L0 clipped
  assert.equal(v.getInt16(46, true), 16383);    // R0 = 0.5 * 0x7fff truncated
  assert.equal(v.getInt16(48, true), -0x8000);  // L1 clipped
  assert.equal(v.getInt16(50, true), -16384);   // R1
});
