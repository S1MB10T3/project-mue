/**
 * Image loading and resampling helpers (browser only).
 */
import { pixelsToMatrix } from './mapping.js';

/** Load a File/Blob into an HTMLImageElement (Safari applies EXIF rotation). */
export function loadImage(file) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.onload = () => { URL.revokeObjectURL(url); resolve(img); };
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error('Could not decode image')); };
    img.src = url;
  });
}

/**
 * Resample an image to exactly cols x rows pixels. Large photos are halved
 * step-by-step first, because a single drawImage() from 4000px to 200px
 * aliases badly in most browsers.
 * @returns {ImageData}
 */
export function resample(img, cols, rows) {
  let src = img;
  let w = img.naturalWidth || img.width;
  let h = img.naturalHeight || img.height;
  while (w / 2 >= cols && h / 2 >= rows) {
    const c = document.createElement('canvas');
    w = Math.floor(w / 2);
    h = Math.floor(h / 2);
    c.width = w;
    c.height = h;
    const cx = c.getContext('2d');
    cx.imageSmoothingEnabled = true;
    cx.imageSmoothingQuality = 'high';
    cx.drawImage(src, 0, 0, w, h);
    src = c;
  }
  const out = document.createElement('canvas');
  out.width = cols;
  out.height = rows;
  const ox = out.getContext('2d', { willReadFrequently: true });
  ox.imageSmoothingEnabled = true;
  ox.imageSmoothingQuality = 'high';
  ox.drawImage(src, 0, 0, cols, rows);
  return ox.getImageData(0, 0, cols, rows);
}

/** Convenience: image element -> amplitude matrix. */
export function imageToMatrix(img, cols, rows, opts) {
  const px = resample(img, cols, rows);
  return pixelsToMatrix(px.data, cols, rows, opts);
}

/** Paint a matrix as a greyscale preview into a canvas (1 px per cell). */
export function drawMatrix(canvas, matrix) {
  const { rows, cols, data } = matrix;
  canvas.width = cols;
  canvas.height = rows;
  const ctx = canvas.getContext('2d');
  const img = ctx.createImageData(cols, rows);
  for (let i = 0, p = 0; i < rows * cols; i++, p += 4) {
    const v = Math.round(data[i] * 255);
    img.data[p] = v;
    img.data[p + 1] = v;
    img.data[p + 2] = v;
    img.data[p + 3] = 255;
  }
  ctx.putImageData(img, 0, 0);
}
