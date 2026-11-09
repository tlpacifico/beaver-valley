"""Generate original, deterministic placeholder sound effects for Castor."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


SAMPLE_RATE = 22_050
EFFECTS: dict[str, tuple[float, int]] = {
    "collect": (0.18, 1201),
    "gnaw": (0.48, 2017),
    "place": (0.28, 3011),
    "complete": (0.92, 4013),
}


def envelope(event_id: str, time: float, duration: float) -> float:
    fade_in = min(1.0, time / 0.008)
    fade_out = min(1.0, max(0.0, (duration - time) / 0.045))
    if event_id == "collect":
        return fade_in * fade_out * math.exp(-time * 13.0)
    if event_id == "gnaw":
        pulse = max(0.0, math.sin(math.pi * (time * 11.0 % 1.0))) ** 2
        return fade_in * fade_out * pulse
    if event_id == "place":
        return fade_in * fade_out * math.exp(-time * 9.0)
    return fade_in * fade_out


def sample(event_id: str, time: float, duration: float, noise: float) -> float:
    gain = envelope(event_id, time, duration)
    if event_id == "collect":
        frequency = 680.0 - 430.0 * (time / duration)
        tone = math.sin(2.0 * math.pi * frequency * time)
        click = noise * math.exp(-time * 180.0) * 0.32
        return gain * (tone * 0.58 + math.sin(4.0 * math.pi * frequency * time) * 0.16 + click)
    if event_id == "gnaw":
        frequency = 760.0 + 170.0 * math.sin(2.0 * math.pi * time * 5.2)
        crunch = noise * 0.42
        return gain * (math.sin(2.0 * math.pi * frequency * time) * 0.30 + crunch)
    if event_id == "place":
        low = math.sin(2.0 * math.pi * 115.0 * time)
        knock = math.sin(2.0 * math.pi * 235.0 * time)
        tap = noise * math.exp(-time * 75.0) * 0.12
        return gain * (low * 0.48 + knock * 0.18 + tap)
    notes = (523.25, 659.25, 783.99, 1046.50)
    result = 0.0
    for index, frequency in enumerate(notes):
        start = index * 0.15
        elapsed = time - start
        if elapsed >= 0:
            note_gain = math.exp(-elapsed * 4.6)
            result += note_gain * math.sin(2.0 * math.pi * frequency * elapsed) * 0.21
    return gain * result


def generate(event_id: str, duration: float, seed: int, output_dir: Path) -> Path:
    rng = random.Random(seed)
    frame_count = round(SAMPLE_RATE * duration)
    output_path = output_dir / f"{event_id}.wav"
    with wave.open(str(output_path), "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        samples = bytearray()
        for frame in range(frame_count):
            time = frame / SAMPLE_RATE
            value = sample(event_id, time, duration, rng.uniform(-1.0, 1.0))
            value = max(-0.92, min(0.92, value))
            samples.extend(struct.pack("<h", round(value * 32767)))
        wav_file.writeframes(samples)
    return output_path


def main() -> None:
    output_dir = Path(__file__).resolve().parents[1] / "game" / "audio" / "effects"
    output_dir.mkdir(parents=True, exist_ok=True)
    for event_id, (duration, seed) in EFFECTS.items():
        output_path = generate(event_id, duration, seed, output_dir)
        print(f"Generated {output_path} ({duration:.2f}s, {SAMPLE_RATE} Hz mono)")


if __name__ == "__main__":
    main()
