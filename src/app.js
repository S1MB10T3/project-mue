/**
 * UI wiring for mue. Keeps all DOM access in one place; the interesting
 * work lives in synth.js / image.js / spectrogram.js.
 */
import { loadImage, imageToMatrix, drawMatrix } from './image.js';
import { renderImageToAudio } from './synth.js';
import { Player } from './player.js';
import { SpectrogramView } from './spectrogram.js';
import { encodeWav } from './wav.js';

const $ = (id) => document.getElementById(id);
const el = {
  file: $('file'),
  pick: $('pick'),
  dropzone: $('dropzone'),
  preview: $('preview'),
  previewWrap: $('preview-wrap'),
  playhead: $('playhead'),
  spectrogram: $('spectrogram'),
  play: $('play'),
  stop: $('stop'),
  save: $('save'),
  status: $('status'),
  duration: $('duration'),
  bands: $('bands'),
  fmin: $('fmin'),
  fmax: $('fmax'),
  scale: $('scale'),
  gamma: $('gamma'),
  cps: $('cps'),
  invert: $('invert'),
  floor: $('floor'),
};

const state = {
  img: null,        // HTMLImageElement of the chosen picture
  matrix: null,     // encoded rows x cols amplitudes
  buffer: null,     // rendered AudioBuffer
  dirty: true,      // settings/image changed since last render
  rendering: false,
  fileName: 'image',
};

const player = new Player();
const spec = new SpectrogramView(el.spectrogram);

function settings() {
  const duration = clamp(parseFloat(el.duration.value) || 6, 0.5, 60);
  const rows = clamp(parseInt(el.bands.value, 10) || 128, 8, 1024);
  let fmin = clamp(parseFloat(el.fmin.value) || 400, 20, 20000);
  let fmax = clamp(parseFloat(el.fmax.value) || 8000, 20, 20000);
  if (fmax <= fmin) fmax = fmin + 100;
  const scale = el.scale.value === 'log' ? 'log' : 'linear';
  const gamma = clamp(parseFloat(el.gamma.value) || 1, 0.1, 8);
  const cps = clamp(parseFloat(el.cps.value) || 40, 4, 200);
  const cols = Math.max(2, Math.round(duration * cps));
  const invert = el.invert.checked;
  const floor = clamp(parseFloat(el.floor.value) || 0, 0, 1);
  return { duration, rows, cols, fmin, fmax, scale, gamma, invert, floor };
}

function clamp(v, lo, hi) {
  return Math.min(hi, Math.max(lo, v));
}

function setStatus(msg, kind = '') {
  el.status.textContent = msg;
  el.status.dataset.kind = kind;
}

function updateButtons() {
  const hasImage = !!state.img;
  el.play.disabled = !hasImage || state.rendering;
  el.play.textContent = state.rendering ? 'Rendering…' : state.dirty ? 'Render & play' : 'Play';
  el.stop.disabled = !player.playing;
  el.save.disabled = !state.buffer || state.dirty;
}

/** Rebuild the preview matrix from the current image + settings. */
function encode() {
  if (!state.img) return;
  const s = settings();
  state.matrix = imageToMatrix(state.img, s.cols, s.rows, {
    invert: s.invert,
    gamma: s.gamma,
    floor: s.floor,
  });
  drawMatrix(el.preview, state.matrix);
  el.previewWrap.style.aspectRatio = `${s.cols} / ${s.rows}`;
  el.spectrogram.style.aspectRatio = `${s.cols} / ${s.rows}`;
  spec.configure({
    rows: s.rows,
    cols: s.cols,
    fmin: s.fmin,
    fmax: s.fmax,
    scale: s.scale,
    sampleRate: player.sampleRate,
    fftSize: 4096,
  });
  state.dirty = true;
  state.buffer = null;
  setStatus(`${s.cols} × ${s.rows} cells · ${s.fmin}–${s.fmax} Hz ${s.scale} · ${s.duration}s`);
  updateButtons();
}

async function render() {
  const s = settings();
  state.rendering = true;
  updateButtons();
  setStatus('Rendering audio…');
  const t0 = performance.now();
  try {
    state.buffer = await renderImageToAudio(state.matrix, {
      duration: s.duration,
      fmin: s.fmin,
      fmax: s.fmax,
      scale: s.scale,
      sampleRate: 44100,
    });
    state.dirty = false;
    setStatus(`Rendered ${s.duration}s in ${((performance.now() - t0) / 1000).toFixed(2)}s`);
  } catch (err) {
    console.error(err);
    setStatus(`Render failed: ${err.message}`, 'error');
  } finally {
    state.rendering = false;
    updateButtons();
  }
}

let raf = 0;
function tick() {
  if (!player.playing) {
    el.playhead.style.left = '0%';
    updateButtons();
    return;
  }
  const t = player.duration ? player.position / player.duration : 0;
  el.playhead.style.left = `${(t * 100).toFixed(2)}%`;
  spec.paint(player.analyser, t);
  raf = requestAnimationFrame(tick);
}

async function onPlay() {
  if (!state.img) return;
  try {
    // Create/resume the AudioContext inside the tap handler (iOS requirement).
    player.ensureContext();
    // The analyser geometry depends on the real device sample rate.
    if (state.dirty || !state.buffer) {
      encode(); // refresh with the real sample rate now that we have a context
      await render();
      if (!state.buffer) return;
    }
    spec.clear();
    player.onended = () => {
      cancelAnimationFrame(raf);
      el.playhead.style.left = '0%';
      updateButtons();
    };
    player.play(state.buffer);
    cancelAnimationFrame(raf);
    raf = requestAnimationFrame(tick);
    updateButtons();
  } catch (err) {
    console.error(err);
    setStatus(`Playback failed: ${err.message}`, 'error');
  }
}

function onStop() {
  player.stop();
  cancelAnimationFrame(raf);
  el.playhead.style.left = '0%';
  updateButtons();
}

async function onSave() {
  if (!state.buffer) return;
  const wav = encodeWav([state.buffer.getChannelData(0)], state.buffer.sampleRate);
  const blob = new Blob([wav], { type: 'audio/wav' });
  const name = `${state.fileName.replace(/\.[^.]+$/, '') || 'mue'}.wav`;
  // iOS Safari: the share sheet is the nicest way to get a file out.
  if (navigator.canShare && navigator.canShare({ files: [new File([blob], name, { type: 'audio/wav' })] })) {
    try {
      await navigator.share({ files: [new File([blob], name, { type: 'audio/wav' })], title: name });
      return;
    } catch (err) {
      if (err && err.name === 'AbortError') return; // user cancelled
      // fall through to download
    }
  }
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = name;
  document.body.appendChild(a);
  a.click();
  setTimeout(() => { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
}

async function onFile(file) {
  if (!file) return;
  onStop();
  setStatus('Loading image…');
  try {
    state.img = await loadImage(file);
    state.fileName = file.name || 'image';
    el.dropzone.classList.add('has-image');
    encode();
  } catch (err) {
    console.error(err);
    setStatus(err.message, 'error');
  }
}

// --- events -----------------------------------------------------------
el.pick.addEventListener('click', () => el.file.click());
el.file.addEventListener('change', () => onFile(el.file.files && el.file.files[0]));
el.play.addEventListener('click', onPlay);
el.stop.addEventListener('click', onStop);
el.save.addEventListener('click', onSave);

for (const key of ['duration', 'bands', 'fmin', 'fmax', 'scale', 'gamma', 'cps', 'invert', 'floor']) {
  el[key].addEventListener('change', () => { onStop(); encode(); });
}

// Desktop drag-and-drop and paste, handy while developing on a laptop.
el.dropzone.addEventListener('dragover', (e) => { e.preventDefault(); el.dropzone.classList.add('drag'); });
el.dropzone.addEventListener('dragleave', () => el.dropzone.classList.remove('drag'));
el.dropzone.addEventListener('drop', (e) => {
  e.preventDefault();
  el.dropzone.classList.remove('drag');
  onFile(e.dataTransfer.files && e.dataTransfer.files[0]);
});
window.addEventListener('paste', (e) => {
  const item = [...(e.clipboardData?.items || [])].find((i) => i.type.startsWith('image/'));
  if (item) onFile(item.getAsFile());
});

// Progressive enhancement: offline support when served over https/localhost.
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => { /* not fatal */ });
  });
}

updateButtons();
setStatus('Pick a photo to begin.');
