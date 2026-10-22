"""Voces en off con ElevenLabs (Eleven v3).

Uso (la clave va en la variable de entorno ELEVENLABS_API_KEY, nunca en un archivo):
  python voz_eleven.py muestras            -> salida/muestras-voz/<voz>.mp3 con la primera frase
  python voz_eleven.py generar VOICE_ID    -> public/voz/<video>-<n>.wav y duraciones.json
"""
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

from voz import RECORTE

AQUI = Path(__file__).parent
MODELO = "eleven_v3"
# Voces femeninas de la biblioteca básica de ElevenLabs (hablan castellano con el modelo v3).
CANDIDATAS = {
    # Voces de chica de España (biblioteca de ElevenLabs), jóvenes y alegres.
    "raquel": "1eHrpOW5l98cxiSRjbzJ",
    "aitana": "AxFLn9byyiDbMn5fmyqu",
    "cristina": "1CeqBeXMOqCleeQjfYfO",
    "adriana": "uU1QvfOppdkePeLtG9pI",
}

# Tono alegre y cercano. Las etiquetas entre corchetes las interpreta Eleven v3.
GUION = {
    "01-ApplePay": [
        "[cheerfully] Pagas la cena.",
        "Con el móvil, como siempre.",
        "[excited] ¡Y Rico te pregunta qué tal ha ido!",
        "Diez segundos, cinco estrellas... [excited] ¡y guardado!",
        "[cheerfully] Rico. ¡Muy pronto en tu iPhone!",
    ],
    "02-TuAno": [
        "[excited] ¡Este es tu año en Rico!",
        "¡Cuarenta y siete restaurantes! Ahí es nada.",
        "Trescientos doce euros... en croquetas. [laughs] Y no nos arrepentimos.",
        "Tu sitio favorito: [excited] ¡Taberna O Grelo!",
        "¿Y lo que más repetiste? ¡Pulpo a feira, claro!",
        "[curious] ¿Cómo será tu año?",
    ],
    "03-Mapa": [
        "[cheerfully] Un año comiendo por Vigo...",
        "¡Y cada sitio, un pin en tu mapa!",
        "Con su nota y su color. Los rojos... [excited] ¡son los imprescindibles!",
        "[cheerfully] Rico. Tu mapa, tus sitios.",
    ],
    "04-POV": [
        "POV:",
        "te recomendaron un sitio buenísimo...",
        "hace tres meses.",
        "Y ahora... [laughs] ¿cómo se llamaba?",
        "[excited] ¡Tranqui, que para eso está Rico!",
        "Lo guardas en «Quiero probar» y te sale en el mapa.",
        "[cheerfully] Rico. ¡Muy pronto en iPhone!",
    ],
    "05-EnPublico": [
        "[excited] ¡Estoy haciendo una app para no olvidar dónde como!",
        "Tu diario.",
        "Valoras en diez segundos.",
        "Ves lo que gastas, sin dramas.",
        "Y lo que pediste en cada sitio.",
        "La estamos haciendo desde cero. [cheerfully] ¿Te apuntas a la beta?",
    ],
}

FILTRO = "acompressor=threshold=-18dB:ratio=2.5:attack=5:release=120,loudnorm=I=-14:TP=-1.5"


def sintetizar(texto: str, voz: str, destino: Path) -> None:
    clave = os.environ["ELEVENLABS_API_KEY"]
    cuerpo = json.dumps({
        "text": texto,
        "model_id": MODELO,
        "language_code": "es",
        # Estabilidad baja = más expresiva («Creative» en la web).
        "voice_settings": {"stability": 0.3, "similarity_boost": 0.8},
    }).encode("utf-8")
    peticion = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{voz}?output_format=mp3_44100_128",
        data=cuerpo,
        headers={"xi-api-key": clave, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(peticion, timeout=120) as respuesta:
            destino.write_bytes(respuesta.read())
    except urllib.error.HTTPError as error:
        raise SystemExit(f"ElevenLabs {error.code}: {error.read().decode('utf-8', 'replace')}")


def procesar(origen: Path, destino: Path) -> float:
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(origen), "-af", RECORTE + FILTRO, "-ar", "48000", str(destino)],
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
    frase = "[cheerfully] Pagas la cena con el móvil... [excited] ¡y Rico te pregunta qué tal ha ido! Diez segundos, cinco estrellas, ¡y guardado!"
    for nombre, voz in CANDIDATAS.items():
        sintetizar(frase, voz, carpeta / f"eleven-{nombre}.mp3")
        print("ok", nombre)


def generar(voz: str) -> None:
    carpeta = AQUI / "public" / "voz"
    carpeta.mkdir(parents=True, exist_ok=True)
    duraciones: dict[str, list[float]] = {}
    for video, frases in GUION.items():
        duraciones[video] = []
        for i, frase in enumerate(frases):
            bruto = carpeta / f"{video}-{i}.mp3"
            sintetizar(frase, voz, bruto)
            duraciones[video].append(procesar(bruto, carpeta / f"{video}-{i}.wav"))
            bruto.unlink()
            print(f"{video}-{i}: {duraciones[video][-1]} s")
    (carpeta / "duraciones.json").write_text(json.dumps(duraciones, indent=2), encoding="utf-8")


if __name__ == "__main__":
    if sys.argv[1:2] == ["muestras"]:
        muestras()
    elif sys.argv[1:2] == ["generar"]:
        generar(CANDIDATAS.get(sys.argv[2], sys.argv[2]))
    else:
        print(__doc__)
