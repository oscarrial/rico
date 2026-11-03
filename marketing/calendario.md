# Rico · Lanzamiento en redes (2 semanas)

Objetivo: descargas desde el primer día. Todas las piezas acaban en «Ya en la App Store» y en la bio va el enlace a la ficha de la App Store. Si la app aún no está aprobada, se cambia `LLAMADA` en `src/marca.tsx` y las frases de cierre de `voz.py` a «Pronto en iPhone» y se vuelve a renderizar.

Los vídeos están en `marketing/videos/salida/` (se generan con `npm run render` dentro de `marketing/videos`). Las capturas de la app salen de la CI (`capturas.yml`) y se copian a `public/capturas/`.

| Archivo | Formato | Para |
| --- | --- | --- |
| `06-Lanzamiento.mp4` | 9:16 · 15 s | El vídeo del día del lanzamiento: TikTok, Reels, Shorts |
| `01-ApplePay.mp4` | 9:16 · 12 s | TikTok, Reels, Shorts |
| `02-TuAno.mp4` | 9:16 · 14 s | TikTok, Reels, Shorts |
| `03-Mapa.mp4` | 9:16 · 11 s | TikTok, Reels, Shorts |
| `04-POV.mp4` | 9:16 · 12 s | TikTok, Reels |
| `05-EnPublico.mp4` | 9:16 · 12 s | TikTok, X (la historia de quien la ha hecho) |
| `X-Lanzamiento.mp4`, `X-ApplePay.mp4`, `X-TuAno.mp4` | 16:9 | X y LinkedIn |
| `post-lanzamiento.png` | 4:5 | Post fijado en Instagram y LinkedIn |
| `historia-lanzamiento.png` | 9:16 | Historias de Instagram con el sticker de enlace |
| `perfil.png`, `banner-x.png` | — | Perfil de X, TikTok e Instagram; cabecera de X |
| `portadas/*.png` | 9:16 | Portada de cada vídeo en TikTok |

## Reglas de publicación

- **TikTok, Reels y Shorts:** se sube el mismo vídeo a las tres plataformas. La música se elige al subir el vídeo, con un sonido que esté de moda; los MP4 van sin audio a propósito. Hay que poner subtítulos automáticos si hay voz y la portada de `portadas/`.
- **X:** el vídeo 16:9 y el texto. El enlace va en la primera respuesta, no en el post, porque X castiga los enlaces.
- **Horas:** TikTok de 19:00 a 21:30, que es la hora de pensar dónde cenar. X entre 8:30 y 9:30, o a las 14:00.
- **Qué se mide:** el porcentaje de gente que ve el vídeo entero (si baja del 30 %, se cambia el gancho de los dos primeros segundos), los guardados y las altas en la lista. Los likes importan poco.
- **Responder a todos los comentarios** durante la primera hora. En TikTok, contestar con un vídeo a la mejor pregunta da material gratis.

## Semana 1 · Lanzamiento

| Día | Red | Pieza | Texto |
| --- | --- | --- | --- |
| L | Todas | 06-Lanzamiento · post-lanzamiento (fijado) · historia con enlace | «Rico ya está en la App Store. Tu diario de restaurantes: pagas, te pregunta qué tal y lo valoras en 10 segundos. Enlace en la bio.» #restaurantes #dondecomer |
| L | X | X-Lanzamiento + hilo | «He sacado Rico, mi app para no olvidar dónde como. La he hecho yo solo, sin Mac. 🧵» El enlace, en la primera respuesta. Product Hunt el mismo día. |
| M | TikTok/Reels | 04-POV | «¿Cuántos sitios buenísimos se te han olvidado ya? Ahora no te pasa.» |
| X | TikTok/Reels | 01-ApplePay | «Pagas la cena y Rico te pregunta qué tal. ¿Lo probarías esta noche?» |
| J | X | X-ApplePay | «Lo que más me gusta: el pago con Apple Pay crea la visita solo. Tú solo pones las estrellas.» |
| V | TikTok/Reels | 03-Mapa | «Mi año comiendo en Vigo en 10 segundos. ¿Qué ciudad hago ahora?» |
| S–D | TikTok | Respuestas | Vídeos contestando las preguntas más repetidas (Android, precio, privacidad). |

## Semana 2 · Que la gente se vea en ello

| Día | Red | Pieza | Texto |
| --- | --- | --- | --- |
| L | TikTok/Reels | 02-TuAno | «Así sería tu año en Rico. Yo ya sé cuánto gasté en croquetas.» |
| M | X | X-TuAno | «"Tu año en Rico", estilo Wrapped pero de comida. ¿Qué dato querríais ver?» |
| X | TikTok/X | 05-EnPublico | «La he hecho yo solo y ya está en la App Store. Os leo.» |
| J | X | Hilo técnico | «Cómo hice una app iOS sin Mac: todo se compila en la nube.» |
| V | TikTok/Reels | 06-Lanzamiento, otro gancho | Mismo vídeo con otro texto: «La app que te dice dónde comiste bien.» Sirve de prueba A/B. |
| D | X | Cifras | «Primera semana: X descargas, Y visitas guardadas. Lo que más usan: …» |

## Audio

- **Voz en off:** ya va dentro del MP4. Es una voz de tráiler, grave y con un poco de sala, en los vídeos 1 a 4 y 6, y una voz cercana en primera persona en el 5. Las frases están en `marketing/videos/voz.py`: se cambia el texto, se ejecuta `python voz.py` y luego `npm run render`, y las escenas se ajustan solas a lo que dura cada frase.
- **Música:** se añade en TikTok o Instagram al subir el vídeo, con un sonido de moda. Después, en «Volumen», la música se baja al 15-25 % y el sonido original se deja al 100 %, así la voz se entiende por encima. No se mete música de TikTok dentro del MP4 porque tiene derechos y daría problemas en X o en anuncios.
- **Para X**, donde no se añade música en la app: pásame una pista sin derechos (de la biblioteca de audio de YouTube, Artlist, Epidemic…) y la mezclo por debajo de la voz.
- **La voz** sale de las voces neuronales de Microsoft (Edge). Para anuncios de pago conviene pasarla a una voz con licencia comercial clara, como ElevenLabs o Azure, o grabarla tú.
