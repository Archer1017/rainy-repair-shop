#!/usr/bin/env python3
"""Rebuild the original, dependency-free sound design for Rain & Repair.

All sounds are synthesized here; no downloaded or third-party audio is used.
The WAV writer intentionally emits a canonical 44-byte PCM header so Godot can
read the files directly, even before the editor has imported any resources.
"""
import math
import random
import struct
from pathlib import Path

RATE = 22050
TAU = math.tau
OUT = Path(__file__).resolve().parents[1] / "assets" / "audio"
RNG = random.Random(73019)


def write_wave(name, channels, gain=1.0):
    frames = len(channels[0])
    pcm = bytearray(frames * len(channels) * 2)
    offset = 0
    for index in range(frames):
        for channel in channels:
            sample = max(-1.0, min(1.0, channel[index] * gain))
            struct.pack_into("<h", pcm, offset, round(sample * 32767))
            offset += 2
    channel_count = len(channels)
    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI", b"RIFF", 36 + len(pcm), b"WAVE",
        b"fmt ", 16, 1, channel_count, RATE, RATE * channel_count * 2,
        channel_count * 2, 16, b"data", len(pcm),
    )
    (OUT / (name + ".wav")).write_bytes(header + pcm)


def envelope(t, duration, attack=0.012, release=0.07):
    return min(1.0, t / attack) * min(1.0, max(0.0, (duration - t) / release))


def synth(duration, function):
    return [function(i / RATE, i) for i in range(round(duration * RATE))]


def add_note(buffer, start, frequency, duration, strength=0.3, bell=False):
    first = round(start * RATE)
    for i in range(round(duration * RATE)):
        t = i / RATE
        if bell:
            tone = (math.sin(TAU * frequency * t)
                    + 0.22 * math.sin(TAU * frequency * 2.005 * t)
                    + 0.05 * math.sin(TAU * frequency * 3.99 * t))
            amplitude = math.exp(-t * 4.2) * min(1.0, t / 0.008)
        else:
            tone = (math.sin(TAU * frequency * t)
                    + 0.12 * math.sin(TAU * frequency * 2 * t)
                    + 0.03 * math.sin(TAU * frequency * 3 * t))
            amplitude = math.exp(-t * 1.8) * envelope(t, duration, 0.045, 0.18)
        buffer[(first + i) % len(buffer)] += tone * amplitude * strength


def rain_channel(length):
    # Warm the circular filters for one complete pass. Their state at the loop
    # boundary then agrees; no crossfade, silent seam or audible repeating drip.
    white = [RNG.uniform(-1, 1) for _ in range(length)]
    low = smooth = 0.0
    result = []
    for turn in range(2):
        for i, value in enumerate(white):
            low += 0.012 * (value - low)
            smooth += 0.38 * (value - smooth)
            if turn == 1:
                drift = 0.92 + 0.05 * math.sin(TAU * i / length)
                result.append((smooth * 0.48 + low * 1.75) * drift)
    # Tiny, soft roof droplets dispersed across the whole loop.
    for _ in range(64):
        start = RNG.randrange(length)
        frequency = RNG.uniform(1050, 2700)
        strength = RNG.uniform(0.009, 0.028)
        duration = RNG.uniform(0.018, 0.045)
        for j in range(round(duration * RATE)):
            t = j / RATE
            result[(start + j) % length] += strength * math.sin(TAU * frequency * t) * math.exp(-t * 120)
    return result


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rain_frames = RATE * 16
    write_wave("rain", [rain_channel(rain_frames), rain_channel(rain_frames)], 1.15)

    screw = synth(0.22, lambda t, i: envelope(t, 0.22, 0.003, 0.04) * (
        0.19 * math.sin(TAU * (155 * t + 95 * t * t)) * math.exp(-t * 10)
        + 0.14 * RNG.uniform(-1, 1) * (0.2 + 0.8 * max(0, math.sin(TAU * 34 * t)))
    ))
    write_wave("screw", [screw])

    previous = 0.0
    brush = []
    for i in range(round(0.48 * RATE)):
        t = i / RATE
        noise = RNG.uniform(-1, 1)
        previous += 0.29 * (noise - previous)
        pressure = math.sin(math.pi * t / 0.48) ** 0.8
        brush.append(previous * pressure * 0.6)
    write_wave("brush", [brush])

    solder = synth(0.55, lambda t, i: envelope(t, 0.55, 0.03, 0.11) * (
        RNG.uniform(-0.12, 0.12) * (0.65 + 0.35 * math.sin(TAU * 41 * t))
        + 0.019 * math.sin(TAU * 190 * t)
    ))
    write_wave("solder", [solder])

    test = [0.0] * round(0.40 * RATE)
    add_note(test, 0.005, 880.0, 0.14, 0.16, True)
    add_note(test, 0.14, 1174.66, 0.24, 0.15, True)
    write_wave("test", [test])

    success = [0.0] * round(1.8 * RATE)
    for start, frequency, strength in ((0, 523.25, 0.22), (0.105, 659.25, 0.20), (0.22, 783.99, 0.18), (0.37, 1046.50, 0.12)):
        add_note(success, start, frequency, 1.2, strength, True)
    write_wave("success", [success])

    error = [0.0] * round(0.40 * RATE)
    add_note(error, 0.0, 246.94, 0.17, 0.16)
    add_note(error, 0.18, 220.00, 0.20, 0.15)
    write_wave("error", [error])

    # The repaired radio plays a restrained, original music-box phrase.
    radio = [0.0] * (RATE * 12)
    phrase = ((0.0, 329.63), (0.75, 392.0), (1.5, 440.0), (2.25, 392.0),
              (3.0, 293.66), (4.5, 261.63), (6.0, 329.63), (6.75, 392.0),
              (7.5, 523.25), (8.25, 440.0), (9.0, 392.0), (10.5, 329.63))
    for start, frequency in phrase:
        add_note(radio, start, frequency, 1.4, 0.14)
    for start, frequencies in ((0, (130.81, 196.0)), (3, (146.83, 220.0)), (6, (130.81, 196.0)), (9, (164.81, 246.94))):
        for frequency in frequencies:
            add_note(radio, start, frequency, 2.8, 0.035)
    # Periodic crackle retains the intimate, slightly old-fashioned character.
    for i in range(len(radio)):
        radio[i] += RNG.uniform(-0.0015, 0.0015)
    write_wave("radio", [radio])

    clock = [0.0] * RATE
    for start, frequency in ((0.0, 1350), (0.5, 1060)):
        for i in range(round(RATE * 0.035)):
            t = i / RATE
            tick = (0.10 * math.sin(TAU * frequency * t) + RNG.uniform(-0.04, 0.04))
            clock[round(start * RATE) + i] += tick * math.exp(-t * 180)
    write_wave("clock", [clock])

    lantern = synth(2.0, lambda t, i: 0.055 * math.sin(TAU * 100 * t) + 0.012 * math.sin(TAU * 200 * t))
    write_wave("lantern", [lantern])
    print("Generated 10 original WAV files in", OUT)


if __name__ == "__main__":
    main()
