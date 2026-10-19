// Genera los sonidos mágicos de KikiDraw en assets/sounds/*.wav.
// Son sintetizados acá (sin samples de terceros), así no hay licencias
// que revisar y pesan poco. Para regenerarlos:
//   node tool/generate_sounds.mjs
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RATE = 22050;
const outDir = join(dirname(fileURLToPath(import.meta.url)), "..", "assets", "sounds");
mkdirSync(outDir, { recursive: true });

// --- utilidades ---------------------------------------------------------

const buffer = (seconds) => new Float32Array(Math.ceil(seconds * RATE));

// Generador pseudoaleatorio con semilla: los .wav salen idénticos cada vez.
function rng(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 2 ** 32;
  };
}

const noteHz = (midi) => 440 * 2 ** ((midi - 69) / 12);

/** Campanita: fundamental + parciales inarmónicos que decaen rápido. */
function bell(out, start, hz, { decay = 0.5, gain = 0.5 } = {}) {
  const partials = [
    [1, 1],
    [2.76, 0.4],
    [5.4, 0.18],
    [8.93, 0.08],
  ];
  const s0 = Math.floor(start * RATE);
  for (let i = s0; i < out.length; i++) {
    const t = (i - s0) / RATE;
    let v = 0;
    for (const [mult, amp] of partials) {
      v += amp * Math.sin(2 * Math.PI * hz * mult * t) * Math.exp(-t / (decay / mult ** 0.5));
    }
    out[i] += gain * v * Math.min(1, t / 0.003);
  }
}

/** Cuerda pulsada (arpa): seno con un poco de segundo armónico. */
function pluck(out, start, hz, { decay = 0.35, gain = 0.4 } = {}) {
  const s0 = Math.floor(start * RATE);
  for (let i = s0; i < out.length; i++) {
    const t = (i - s0) / RATE;
    const v = Math.sin(2 * Math.PI * hz * t) + 0.3 * Math.sin(4 * Math.PI * hz * t);
    out[i] += gain * v * Math.exp(-t / decay) * Math.min(1, t / 0.002);
  }
}

/** Barrido de frecuencia (fase acumulada, sin saltos). */
function sweep(out, start, length, fromHz, toHz, { gain = 0.5, curve = 2 } = {}) {
  const s0 = Math.floor(start * RATE);
  const n = Math.floor(length * RATE);
  let phase = 0;
  for (let k = 0; k < n && s0 + k < out.length; k++) {
    const p = k / n;
    const hz = fromHz + (toHz - fromHz) * p ** curve;
    phase += (2 * Math.PI * hz) / RATE;
    const env = Math.sin(Math.PI * p) ** 0.6;
    out[s0 + k] += gain * Math.sin(phase) * env;
  }
}

/** Normaliza al [peak] y aplica fundido corto en los bordes (sin clics). */
function finish(samples, peak = 0.7) {
  let max = 0;
  for (const v of samples) max = Math.max(max, Math.abs(v));
  const k = max > 0 ? peak / max : 1;
  const fade = Math.floor(0.004 * RATE);
  for (let i = 0; i < samples.length; i++) {
    let v = samples[i] * k;
    if (i < fade) v *= i / fade;
    if (i > samples.length - fade) v *= (samples.length - i) / fade;
    samples[i] = v;
  }
  return samples;
}

function writeWav(name, samples) {
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((v, i) => data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v)) * 32767), i * 2));
  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // mono
  header.writeUInt32LE(RATE, 24);
  header.writeUInt32LE(RATE * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write("data", 36);
  header.writeUInt32LE(data.length, 40);
  writeFileSync(join(outDir, `${name}.wav`), Buffer.concat([header, data]));
  console.log(`${name}.wav  ${(samples.length / RATE).toFixed(2)} s`);
}

// --- sonidos ------------------------------------------------------------

// Colores: pentatónica de Do (do re mi sol la), dos octavas. Sin semitonos
// "feos": cualquier secuencia que toque suena bien.
const PENTATONIC = [72, 74, 76, 79, 81, 84, 86, 88, 91, 93];
PENTATONIC.forEach((midi, i) => {
  const s = buffer(0.7);
  bell(s, 0, noteHz(midi), { decay: 0.35 });
  writeWav(`note_${i}`, finish(s, 0.55));
});

// Purpurina: destellos agudos al azar.
{
  const s = buffer(0.6);
  const r = rng(7);
  for (let k = 0; k < 9; k++) {
    bell(s, r() * 0.35, noteHz(96 + Math.floor(r() * 10)), { decay: 0.08, gain: 0.25 + r() * 0.2 });
  }
  writeWav("sparkle", finish(s, 0.5));
}

// Arcoíris: glissando de arpa hacia arriba.
{
  const s = buffer(0.9);
  [72, 74, 76, 79, 81, 84, 86, 88].forEach((midi, k) => pluck(s, k * 0.045, noteHz(midi), { decay: 0.3 }));
  writeWav("harp", finish(s, 0.55));
}

// Sellos (estrellitas, corazones, flores): "pop" corto.
{
  const s = buffer(0.14);
  sweep(s, 0, 0.12, 900, 380, { curve: 0.5 });
  writeWav("pop", finish(s, 0.6));
}

// Balde: burbuja ("bloop") que sube.
{
  const s = buffer(0.25);
  sweep(s, 0, 0.2, 260, 1000, { curve: 2.2 });
  sweep(s, 0.05, 0.15, 520, 1400, { curve: 2.2, gain: 0.2 });
  writeWav("bloop", finish(s, 0.6));
}

// Acuarela: gota de agua ("plip").
{
  const s = buffer(0.16);
  sweep(s, 0, 0.12, 1200, 2400, { curve: 3 });
  writeWav("drip", finish(s, 0.45));
}

// Neón: "zap" eléctrico con vibrato.
{
  const s = buffer(0.3);
  const n = Math.floor(0.28 * RATE);
  let phase = 0;
  for (let k = 0; k < n; k++) {
    const p = k / n;
    const hz = 500 + 900 * p + 60 * Math.sin(2 * Math.PI * 30 * (k / RATE));
    phase += (2 * Math.PI * hz) / RATE;
    // Onda cuadrada suavizada: más "eléctrica" que un seno.
    s[k] += Math.tanh(3 * Math.sin(phase)) * (1 - p) ** 1.5;
  }
  writeWav("zap", finish(s, 0.35));
}

// Goma: "swish" de ruido filtrado.
{
  const s = buffer(0.25);
  const r = rng(3);
  let lp = 0;
  for (let i = 0; i < s.length; i++) {
    const p = i / s.length;
    lp += 0.25 * (r() * 2 - 1 - lp);
    s[i] = lp * Math.sin(Math.PI * p) ** 1.2;
  }
  writeWav("swish", finish(s, 0.4));
}

// Deshacer: "fiuuu" que baja.
{
  const s = buffer(0.3);
  sweep(s, 0, 0.28, 1400, 300, { curve: 0.6, gain: 0.5 });
  writeWav("whoosh", finish(s, 0.45));
}

// Rehacer: el mismo pero subiendo.
{
  const s = buffer(0.3);
  sweep(s, 0, 0.28, 300, 1400, { curve: 1.6, gain: 0.5 });
  writeWav("whoosh_up", finish(s, 0.45));
}

// Guardar: dos campanitas (mi, si).
{
  const s = buffer(0.9);
  bell(s, 0, noteHz(88), { decay: 0.4 });
  bell(s, 0.12, noteHz(95), { decay: 0.5 });
  writeWav("chime", finish(s, 0.55));
}

// Exportar / celebración: arpegio + acorde + destellos ("¡tadá!").
{
  const s = buffer(1.6);
  [72, 76, 79, 84].forEach((midi, k) => bell(s, k * 0.09, noteHz(midi), { decay: 0.3 }));
  [72, 76, 79, 84, 88].forEach((midi) => bell(s, 0.42, noteHz(midi), { decay: 0.7, gain: 0.3 }));
  const r = rng(11);
  for (let k = 0; k < 10; k++) {
    bell(s, 0.45 + r() * 0.6, noteHz(98 + Math.floor(r() * 8)), { decay: 0.07, gain: 0.15 });
  }
  writeWav("tada", finish(s, 0.6));
}
