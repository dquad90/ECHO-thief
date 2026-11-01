import os
import wave
import struct
import math
import random

OUT_DIR = r"q:\GODOT WORKS\echo-thief\assets\audio"
os.makedirs(OUT_DIR, exist_ok=True)
SAMPLE_RATE = 22050

def write_wav(filename, samples):
    filepath = os.path.join(OUT_DIR, filename)
    with wave.open(filepath, 'w') as wav:
        wav.setnchannels(1) # mono
        wav.setsampwidth(2) # 16-bit
        wav.setframerate(SAMPLE_RATE)
        data = bytearray()
        for s in samples:
            # clamp to -1.0 .. 1.0
            val = max(-1.0, min(1.0, s))
            data.extend(struct.pack('<h', int(val * 32767.0)))
        wav.writeframes(data)

def gen_footstep():
    duration = 0.08
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = (1.0 - t / duration) ** 2.0
        # low muffled thud
        freq = 90.0 - 40.0 * (t / duration)
        noise = (random.random() * 2.0 - 1.0) * 0.15
        s = (math.sin(2 * math.pi * freq * t) + noise) * env * 0.4
        samples.append(s)
    write_wav("footstep.wav", samples)

def gen_pebble_throw():
    duration = 0.18
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (t / duration)) ** 1.5
        noise = (random.random() * 2.0 - 1.0)
        # filtered whoosh
        s = noise * env * 0.35
        samples.append(s)
    write_wav("throw.wav", samples)

def gen_pebble_impact():
    duration = 0.14
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = (1.0 - t / duration) ** 3.0
        # sharp stone ping
        s1 = math.sin(2 * math.pi * 1200.0 * t)
        s2 = math.sin(2 * math.pi * 1850.0 * t) * 0.6
        noise = (random.random() * 2.0 - 1.0) * 0.2
        s = (s1 + s2 + noise) * env * 0.5
        samples.append(s)
    write_wav("impact.wav", samples)

def gen_glass_crunch():
    duration = 0.25
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = (1.0 - t / duration) ** 2.0
        # harsh high frequency crunch
        s1 = math.sin(2 * math.pi * 2800.0 * t)
        s2 = math.sin(2 * math.pi * 3900.0 * t) * 0.8
        noise = (random.random() * 2.0 - 1.0) * 0.5
        s = (s1 + s2 + noise) * env * 0.6
        samples.append(s)
    write_wav("glass_crunch.wav", samples)

def gen_whistle():
    duration = 0.45
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = 1.0 if t < 0.35 else (1.0 - (t - 0.35) / 0.10)
        # loud piercing double whistle
        freq = 2400.0 + 80.0 * math.sin(2 * math.pi * 35.0 * t)
        s = (math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(2 * math.pi * freq * 1.5 * t)) * env * 0.6
        samples.append(s)
    write_wav("whistle.wav", samples)

def gen_pickup():
    duration = 0.35
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    # Arpeggio: C6, E6, G6, C7
    notes = [1046.5, 1318.5, 1567.98, 2093.0]
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        idx = min(len(notes) - 1, int((t / duration) * len(notes)))
        freq = notes[idx]
        note_t = t - (idx * (duration / len(notes)))
        env = (1.0 - note_t / (duration / len(notes))) ** 1.5
        s = math.sin(2 * math.pi * freq * t) * env * 0.4
        samples.append(s)
    write_wav("pickup.wav", samples)

def gen_detected():
    duration = 0.6
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        env = min(1.0, t * 15.0) * (1.0 - (t / duration) ** 2.0)
        # Low ominous tension sting
        s1 = math.sin(2 * math.pi * 110.0 * t)
        s2 = math.sin(2 * math.pi * 116.54 * t) # minor second dissonance
        s = (s1 + s2) * 0.5 * env * 0.7
        samples.append(s)
    write_wav("detected.wav", samples)

if __name__ == "__main__":
    gen_footstep()
    gen_pebble_throw()
    gen_pebble_impact()
    gen_glass_crunch()
    gen_whistle()
    gen_pickup()
    gen_detected()
    print("All audio generated!")
