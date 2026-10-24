"""Sintetiza los efectos de sonido de la primera pasada (estilo NES / jsfxr).

Canales como los de la NES: onda cuadrada con ciclo de trabajo (pulse), triangular y ruido de un
LFSR de 15 bits (determinista: mismo resultado en cada ejecución). Envolvente lineal de ataque y
caída, barridos de frecuencia y arpegios. Escribe WAV mono de 16 bits a 22050 Hz con el módulo
estándar `wave`.

Uso (desde la raíz del repo):
    python tools/audio/make_sfx.py   # escribe assets/audio/sfx/sfx_*.wav
"""
import math
import os
import struct
import wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
RATE = 22050


def n(seconds):
    return int(RATE * seconds)


def envelope(i, total, attack, release_from=None):
    """Ataque lineal en `attack` muestras y caída lineal desde `release_from` hasta el final."""
    a = min(1.0, i / attack) if attack > 0 else 1.0
    if release_from is None:
        release_from = attack
    if i > release_from:
        a *= max(0.0, 1.0 - (i - release_from) / max(1, total - release_from))
    return a


def pulse(freq_from, freq_to, seconds, volume, duty=0.5, attack=0.002, hold=0.0):
    """Cuadrada con barrido lineal de frecuencia. `hold`: fracción sin caída antes de apagarse."""
    total = n(seconds)
    out = []
    phase = 0.0
    for i in range(total):
        t = i / max(1, total - 1)
        f = freq_from + (freq_to - freq_from) * t
        phase = (phase + f / RATE) % 1.0
        s = 1.0 if phase < duty else -1.0
        out.append(s * volume * envelope(i, total, n(attack), int(total * hold)))
    return out


def triangle(freq, seconds, volume, attack=0.002, hold=0.0):
    total = n(seconds)
    out = []
    phase = 0.0
    for i in range(total):
        phase = (phase + freq / RATE) % 1.0
        s = 4.0 * abs(phase - 0.5) - 1.0
        # La NES cuantiza la triangular en 16 escalones.
        s = round(s * 8) / 8
        out.append(s * volume * envelope(i, total, n(attack), int(total * hold)))
    return out


def noise(rate_from, rate_to, seconds, volume, attack=0.001, hold=0.0, short=False):
    """Ruido del LFSR de la NES. `rate`: cambios por segundo (más alto = más agudo)."""
    total = n(seconds)
    out = []
    reg = 1
    acc = 0.0
    tap = 6 if short else 1
    for i in range(total):
        t = i / max(1, total - 1)
        rate = rate_from + (rate_to - rate_from) * t
        acc += rate / RATE
        while acc >= 1.0:
            acc -= 1.0
            bit = (reg ^ (reg >> tap)) & 1
            reg = (reg >> 1) | (bit << 14)
        s = 1.0 if reg & 1 else -1.0
        out.append(s * volume * envelope(i, total, n(attack), int(total * hold)))
    return out


def silence(seconds):
    return [0.0] * n(seconds)


def mix(*tracks):
    length = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(length)]


def cat(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def arpeggio(freqs, step, volume, duty=0.5, tail=0.0):
    parts = [pulse(f, f, step, volume, duty, hold=0.8) for f in freqs[:-1]]
    parts.append(pulse(freqs[-1], freqs[-1], step + tail, volume, duty, hold=0.3))
    return cat(*parts)


SOUNDS = {
    # Paso sobre tierra: un soplo de ruido grave, muy bajo.
    "sfx_step": lambda: noise(2500, 1500, 0.035, 0.12),
    # Letra del diálogo: un clic de cuadrada aguda, cortísimo.
    "sfx_text_blip": lambda: pulse(990, 990, 0.022, 0.13, duty=0.25),
    # Golpe con cuerpo: chasquido de impacto, caída de cuadrada, golpe grave de triangular
    # y una cola de ruido sordo para que no suene seco.
    "sfx_hit": lambda: mix(
        noise(14000, 4000, 0.05, 0.3),
        pulse(160, 45, 0.22, 0.2, duty=0.5),
        triangle(70, 0.28, 0.35),
        noise(1800, 600, 0.3, 0.12, attack=0.005),
    ),
    # Latigazo: silbido que sube y chasquido final.
    "sfx_whip": lambda: cat(
        noise(4000, 20000, 0.12, 0.12, attack=0.08, hold=1.0),
        mix(noise(22000, 6000, 0.09, 0.4, short=True), pulse(1800, 300, 0.06, 0.15, duty=0.125)),
    ),
    # Aviso del riutash: dos notas de alerta que bajan.
    "sfx_riutash_warning": lambda: cat(
        pulse(880, 880, 0.12, 0.22, duty=0.25, hold=0.7),
        silence(0.05),
        pulse(660, 660, 0.18, 0.22, duty=0.25, hold=0.6),
    ),
    # Riutash: destello. Arpegio rapidísimo hacia arriba sobre un barrido de ruido brillante.
    "sfx_riutash": lambda: mix(
        arpeggio([523, 784, 1047, 1568, 2093, 2637], 0.04, 0.16, duty=0.25, tail=0.5),
        noise(30000, 8000, 0.75, 0.12, attack=0.01),
        triangle(131, 0.75, 0.25),
    ),
    # Subir de nivel: arpegio de do mayor y nota larga.
    "sfx_level_up": lambda: mix(
        arpeggio([523, 659, 784, 1047], 0.08, 0.2, duty=0.5, tail=0.3),
        cat(silence(0.24), triangle(262, 0.4, 0.3)),
    ),
    # Menú: mover el cursor y aceptar.
    "sfx_menu_move": lambda: pulse(1320, 1320, 0.03, 0.12, duty=0.5),
    "sfx_menu_accept": lambda: cat(pulse(880, 880, 0.04, 0.16, hold=0.8), pulse(1320, 1320, 0.07, 0.16)),
}


def write_wav(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
        w.writeframes(frames)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, build in SOUNDS.items():
        samples = build()
        write_wav(os.path.join(OUT_DIR, name + ".wav"), samples)
        print("%s.wav %.3f s" % (name, len(samples) / RATE))


if __name__ == "__main__":
    main()
