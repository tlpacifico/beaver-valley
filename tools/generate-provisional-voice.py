"""Generate Castor's milestone 2 voice lines from a local Piper voice model."""

from __future__ import annotations

import argparse
import wave
from pathlib import Path

from piper import PiperVoice


LINES: dict[str, str] = {
    "dam_start": "Vamos ajudar o castor a construir uma represa!",
    "help_collect": "Escolhe um galho para levar.",
    "help_place": "Agora leva o galho até à represa.",
    "first_placement": "Olha, a água está a mudar!",
    "dam_completed": "Fizeste uma represa!",
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    voice = PiperVoice.load(str(args.model))
    for event_id, text in LINES.items():
        output_path = args.output_dir / f"{event_id}.wav"
        with wave.open(str(output_path), "wb") as wav_file:
            voice.synthesize_wav(text, wav_file)
        print(f"Generated {output_path} ({text})")


if __name__ == "__main__":
    main()
