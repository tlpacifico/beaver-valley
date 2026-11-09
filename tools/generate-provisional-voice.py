"""Generate Castor's provisional pt-PT voice lines from a local Piper model."""

from __future__ import annotations

import argparse
import wave
from pathlib import Path

from piper import PiperVoice


LINES: dict[str, str] = {
    "dam_start": "Vamos ajudar o castor a construir uma represa!",
    "help_collect": "Escolhe um ramo para levar.",
    "help_place": "Agora leva o ramo até à represa.",
    "first_placement": "Olha, a água está a mudar!",
    "dam_completed": "Fizeste uma represa!",
    "thick_branch": "Este ramo é grosso. Podes roê-lo ou escolher outro.",
    "rotten_branch": "O ramo podre dobrou! Vamos escolher outro.",
    "help_compatible": "Escolhe o ramo verde para a represa.",
    "home_invite": "Agora vamos construir a casa!",
    "help_home_collect": "Escolhe uma peça para a casa.",
    "help_home_place": "Leva a peça até à casa.",
    "food_invite": "Agora vamos guardar comida para o inverno!",
    "help_food_collect": "Escolhe um feixe de ramos para guardar.",
    "help_food_place": "Leva o feixe até à água.",
    "food_unsuitable": "Este feixe é pequeno. Escolhe outro.",
    "food_complete": "A comida está guardada!",
    "winter_arrived": "O inverno chegou! A família do castor está reunida.",
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
