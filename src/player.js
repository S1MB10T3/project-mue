/**
 * Real-time playback with an AnalyserNode tap for the live spectrogram.
 */
const AudioCtx = globalThis.AudioContext || globalThis.webkitAudioContext;

export class Player {
  constructor() {
    this.ctx = null;
    this.analyser = null;
    this.source = null;
    this.startedAt = 0;
    this.duration = 0;
    this.onended = null;
  }

  /** Must be called from a user gesture on iOS the first time. */
  ensureContext() {
    if (!this.ctx) {
      if (!AudioCtx) throw new Error('Web Audio is not supported in this browser');
      this.ctx = new AudioCtx();
      this.analyser = this.ctx.createAnalyser();
      this.analyser.fftSize = 4096;
      this.analyser.smoothingTimeConstant = 0;
      this.analyser.minDecibels = -85;
      this.analyser.maxDecibels = -20;
      this.analyser.connect(this.ctx.destination);
    }
    if (this.ctx.state === 'suspended') this.ctx.resume();
    return this.ctx;
  }

  get sampleRate() {
    return this.ctx ? this.ctx.sampleRate : 44100;
  }

  play(buffer) {
    this.ensureContext();
    this.stop();
    const src = this.ctx.createBufferSource();
    src.buffer = buffer;
    src.connect(this.analyser);
    src.onended = () => {
      if (this.source === src) {
        this.source = null;
        if (this.onended) this.onended();
      }
    };
    this.source = src;
    this.duration = buffer.duration;
    this.startedAt = this.ctx.currentTime;
    src.start();
  }

  stop() {
    if (this.source) {
      const s = this.source;
      this.source = null;
      try { s.stop(); } catch (_) { /* already stopped */ }
    }
  }

  get playing() {
    return this.source !== null;
  }

  /** Seconds since playback started (clamped to duration). */
  get position() {
    if (!this.source) return 0;
    return Math.min(this.duration, this.ctx.currentTime - this.startedAt);
  }
}
