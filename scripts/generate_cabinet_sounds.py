#!/usr/bin/env python3
"""合成原创短音；不读取、采样或下载任何第三方音频。"""
import math
import pathlib
import random
import struct
import wave

root = pathlib.Path(__file__).resolve().parents[1] / 'cheatsheet/Resources/InteractionSounds'
root.mkdir(parents=True, exist_ok=True)
rate = 48000
for name, duration, peak, frequency, seed in [('copy', 0.105, 0.32, 720, 19), ('save', 0.075, 0.19, 610, 23)]:
    rng = random.Random(seed)
    low = 0.0
    samples = []
    for index in range(round(rate * duration)):
        t = index / rate
        low += 0.18 * (rng.uniform(-1, 1) - low)
        attack = 1 - math.exp(-t / 0.0018)
        body = (math.sin(2 * math.pi * frequency * t) * math.exp(-t / 0.012)
                + 0.32 * math.sin(2 * math.pi * frequency * 0.53 * t) * math.exp(-t / 0.018))
        grain = 0.4 * low * math.exp(-t / 0.007)
        tail = min(1, max(0, (duration - t) / 0.012))
        samples.append((body + grain) * attack * tail)
    normalizer = peak / max(abs(value) for value in samples)
    pcm = b''.join(struct.pack('<h', round(value * normalizer * 32767)) for value in samples)
    path = root / f'cabinet-{name}.wav'
    with wave.open(str(path), 'wb') as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(rate)
        output.writeframes(pcm)
    print(f'{path.name}: {duration * 1000:.0f}ms, PCM16 mono 48kHz, peak={peak:.2f}, bytes={len(pcm)}')
