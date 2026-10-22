"""Voces en off con VoiceStudio (OmniVoice, en local con la GPU).

Uso:
  python voz_studio.py muestras            -> salida/muestras-voz/ con varias semillas
  python voz_studio.py generar SEMILLA     -> public/voz/<video>-<n>.wav y duraciones.json

Necesita VoiceStudio abierto (API en http://127.0.0.1:3900). Las frases son las de voz.py.
"""
import json
import subprocess
import sys
import urllib.request
from pathlib import Path

from voz import GUION, RECORTE

API = "http://127.0.0.1:3900/v1/audio/speech"
AQUI = Path(__file__).parent
# Voz diseñada, sin clonar a nadie: hombre adulto, muy grave. La cercana, un tono más natural.
DISENO = {
    "epica": "male, middle-aged, very low pitch",
    "cercana": "male, young adult, low pitch",
}
# Solo un poco de compresión y sala en la épica; el modelo ya suena limpio.
FILTRO = {
    "epica": "equalizer=f=100:t=q:w=1.2:g=3,acompressor=threshold=-20dB:ratio=3:attack=5:release=150,"
             "aecho=0.8:0.5:40|75:0.12|0.07,loudnorm=I=-14:TP=-1.5",
    "cercana": "acompressor=threshold=-18dB:ratio=2.5,loudnorm=I=-14:TP=-1.5",
}


def sintetizar(texto: str, diseno: str, semilla: int, destino: Path, velocidad: float = 1.0) -> None:
    cuerpo = json.dumps({
        "model": "omnivoice",
        "input": texto,
        "language": "es",
        "instruct": diseno,
        "seed": semilla,
        "speed": velocidad,
        "response_format": "wav",
    }).encode("utf-8")
    peticion = urllib.request.Request(API, data=cuerpo, headers={"Content-Type": "application/json; charset=utf-8"})
    with urllib.request.urlopen(peticion, timeout=300) as respuesta:
        destino.write_bytes(respuesta.read())


def procesar(origen: Path, destino: Path, estilo: str) -> float:
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(origen), "-af", RECORTE + FILTRO[estilo], "-ar", "48000", str(destino)],
        check=True,
    )
    salida = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(destino)],
        capture_output=True, text=True, check=True,
    )
    return round(float(salida.stdout.strip()), 2)


def muestras() -> None:
    carpeta = AQUI / "salida" / "muestras-voz"
    carpeta.mkdir(parents=True, exist_ok=True)
    frase = "Pagas la cena. Como siempre. Pero esta vez... alguien te pregunta qué tal."
    for semilla in (7, 21, 42, 99):
        bruto = carpeta / f"bruto-{semilla}.wav"
        sintetizar(frase, DISENO["epica"], semilla, bruto, velocidad=0.92)
        print(semilla, procesar(bruto, carpeta / f"voz-semilla-{semilla}.wav", "epica"), "s")
        bruto.unlink()


def generar(semilla: int) -> None:
    carpeta = AQUI / "public" / "voz"
    carpeta.mkdir(parents=True, exist_ok=True)
    duraciones: dict[str, list[float]] = {}
    for video, (estilo, frases) in GUION.items():
        tipo = estilo["filtro"]
        duraciones[video] = []
        for i, frase in enumerate(frases):
            bruto = carpeta / f"{video}-{i}.bruto.wav"
            sintetizar(frase, DISENO[tipo], semilla, bruto, velocidad=0.92 if tipo == "epica" else 1.0)
            duraciones[video].append(procesar(bruto, carpeta / f"{video}-{i}.wav", tipo))
            bruto.unlink()
            print(f"{video}-{i}: {duraciones[video][-1]} s")
    (carpeta / "duraciones.json").write_text(json.dumps(duraciones, indent=2), encoding="utf-8")


if __name__ == "__main__":
    if sys.argv[1:2] == ["muestras"]:
        muestras()
    elif sys.argv[1:2] == ["generar"]:
        generar(int(sys.argv[2]))
    else:
        print(__doc__)
