"""Genera las voces en off de los vídeos (public/voz/<video>-<n>.wav) y apunta su duración.

Uso: python voz.py   (necesita `pip install edge-tts` y ffmpeg en el PATH)
Las frases y su estilo están en GUION; los vídeos leen voz/duraciones.json para encajar las escenas.
"""
import asyncio
import json
import subprocess
from pathlib import Path

import edge_tts

SALIDA = Path(__file__).parent / "public" / "voz"

# Voz de tráiler: grave, pausada y con un poco de sala. La de «en público» va natural, en primera persona.
EPICA = {"voz": "es-ES-AlvaroNeural", "velocidad": "-6%", "tono": "-9Hz", "filtro": "epica"}
CERCANA = {"voz": "es-ES-AlvaroNeural", "velocidad": "+4%", "tono": "-2Hz", "filtro": "cercana"}

GUION = {
    "01-ApplePay": (EPICA, [
        "Pagas la cena.",
        "Como siempre.",
        "Pero esta vez... alguien te pregunta qué tal.",
        "Diez segundos. Cinco estrellas. Guardado para siempre.",
        "Rico. Pronto en iPhone.",
    ]),
    "02-TuAno": (EPICA, [
        "Tu año... en Rico.",
        "Cuarenta y siete restaurantes.",
        "Trescientos doce euros... en croquetas.",
        "Tu sitio top: Taberna O Grelo.",
        "Y lo que más repetiste... pulpo a feira.",
        "¿Cómo será tu año?",
    ]),
    "03-Mapa": (EPICA, [
        "Un año. Una ciudad.",
        "Cada pin, un sitio donde comiste.",
        "Su nota. Su color. Tus imprescindibles.",
        "Rico. Tu mapa, tus sitios.",
    ]),
    "04-POV": (EPICA, [
        "En un mundo...",
        "donde te recomendaron un sitio buenísimo...",
        "hace tres meses...",
        "y ya no recuerdas ni el nombre...",
        "solo una app puede salvarte.",
        "Guárdalo en Quiero probar. Y aparece en tu mapa.",
        "Rico. Pronto en iPhone.",
    ]),
    "05-EnPublico": (CERCANA, [
        "Estoy haciendo una app para no olvidar dónde como.",
        "Tu diario.",
        "Valoras en diez segundos.",
        "Lo que gastas, sin culpa.",
        "Y lo que pediste en cada sitio.",
        "La estoy haciendo yo solo. ¿Te apuntas a la beta?",
    ]),
}

# El sintetizador deja medio segundo de silencio delante y detrás: se recorta para que el ritmo sea ágil.
RECORTE = ("silenceremove=start_periods=1:start_threshold=-45dB,areverse,"
           "silenceremove=start_periods=1:start_threshold=-45dB,areverse,apad=pad_dur=0.2,")

FILTROS = {
    # Graves, compresión fuerte y un eco corto de sala: suena a voz de tráiler sin ser grotesca.
    "epica": "equalizer=f=110:t=q:w=1.2:g=5,equalizer=f=3500:t=q:w=1:g=2,"
             "acompressor=threshold=-20dB:ratio=4:attack=5:release=120,"
             "aecho=0.8:0.6:45|90:0.18|0.10,loudnorm=I=-14:TP=-1.5",
    "cercana": "equalizer=f=150:t=q:w=1:g=2,acompressor=threshold=-18dB:ratio=3,loudnorm=I=-14:TP=-1.5",
}


def duracion(archivo: Path) -> float:
    salida = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(archivo)],
        capture_output=True, text=True, check=True,
    )
    return float(salida.stdout.strip())


async def main() -> None:
    SALIDA.mkdir(parents=True, exist_ok=True)
    duraciones: dict[str, list[float]] = {}
    for video, (estilo, frases) in GUION.items():
        duraciones[video] = []
        for i, frase in enumerate(frases):
            bruto = SALIDA / f"{video}-{i}.raw.mp3"
            final = SALIDA / f"{video}-{i}.wav"
            await edge_tts.Communicate(frase, estilo["voz"], rate=estilo["velocidad"], pitch=estilo["tono"]).save(str(bruto))
            subprocess.run(
                ["ffmpeg", "-y", "-loglevel", "error", "-i", str(bruto), "-af", RECORTE + FILTROS[estilo["filtro"]], "-ar", "48000", str(final)],
                check=True,
            )
            bruto.unlink()
            duraciones[video].append(round(duracion(final), 2))
            print(f"{video}-{i}: {duraciones[video][-1]} s · {frase}")
    (SALIDA / "duraciones.json").write_text(json.dumps(duraciones, indent=2), encoding="utf-8")


if __name__ == "__main__":
    asyncio.run(main())
