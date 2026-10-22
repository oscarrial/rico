# Rico · Calendario de lanzamiento en redes (4 semanas)

Objetivo: gente apuntada a la beta antes de salir en la App Store. Cada pieza acaba en «Pronto en iPhone» y en la bio va el enlace a la lista de espera (TestFlight público o formulario).

Los vídeos están en `marketing/videos/salida/` (se generan con `npm run render` dentro de `marketing/videos`).

| Archivo | Formato | Para |
| --- | --- | --- |
| `01-ApplePay.mp4` | 9:16 · 12 s | TikTok, Reels, Shorts |
| `02-TuAno.mp4` | 9:16 · 14 s | TikTok, Reels, Shorts |
| `03-Mapa.mp4` | 9:16 · 11 s | TikTok, Reels, Shorts |
| `04-POV.mp4` | 9:16 · 11,5 s | TikTok, Reels |
| `05-EnPublico.mp4` | 9:16 · 12 s | TikTok, X |
| `X-ApplePay.mp4`, `X-TuAno.mp4` | 16:9 | X |
| `perfil.png`, `banner-x.png` | — | Perfil de X y TikTok |
| `portadas/*.png` | 9:16 | Portada de cada vídeo en TikTok |

## Reglas de publicación

- **TikTok, Reels y Shorts:** se sube el mismo vídeo a las tres plataformas. La música se elige al subir el vídeo, con un sonido que esté de moda; los MP4 van sin audio a propósito. Hay que poner subtítulos automáticos si hay voz y la portada de `portadas/`.
- **X:** el vídeo 16:9 y el texto. El enlace va en la primera respuesta, no en el post, porque X castiga los enlaces.
- **Horas:** TikTok de 19:00 a 21:30, que es la hora de pensar dónde cenar. X entre 8:30 y 9:30, o a las 14:00.
- **Qué se mide:** el porcentaje de gente que ve el vídeo entero (si baja del 30 %, se cambia el gancho de los dos primeros segundos), los guardados y las altas en la lista. Los likes importan poco.
- **Responder a todos los comentarios** durante la primera hora. En TikTok, contestar con un vídeo a la mejor pregunta da material gratis.

## Semana 1 · Presentar la idea

| Día | Red | Pieza | Texto |
| --- | --- | --- | --- |
| L | TikTok/Reels | 04-POV | «¿Cuántos sitios buenísimos se te han olvidado ya? 🙃 Estoy haciendo una app para que no vuelva a pasar.» #restaurantes #dondecomer #vigo |
| L | X | 05-EnPublico (9:16) | «Estoy haciendo Rico, un diario de restaurantes para iPhone. Pagas, te pregunta qué tal y lo valoras en 10 segundos. Lo voy a construir en público: aquí contaré lo que funciona y lo que no. 🧵» |
| M | X | Hilo | Por qué la hago: «Tengo una lista de 200 sitios en notas del móvil y no sé cuáles me gustaron. Las apps de reseñas son de todos; yo quería una solo mía.» |
| X | TikTok/Reels | 01-ApplePay | «Pagas la cena y Rico te pregunta qué tal. 10 segundos y queda guardado. ¿Lo usarías?» |
| J | X | X-ApplePay | «La parte que más me gusta: el pago con Apple Pay crea la visita solo. Tú solo pones las estrellas.» |
| V | TikTok/Reels | 03-Mapa | «Mi año comiendo en Vigo en 10 segundos. ¿Qué ciudad hago la próxima?» (preguntar en comentarios) |
| D | X | Captura real | Una captura de la beta con un detalle de diseño y la decisión que tomaste. |

## Semana 2 · Que la gente se vea en ello

| Día | Red | Pieza | Texto |
| --- | --- | --- | --- |
| L | TikTok/Reels | 02-TuAno | «Así sería tu año en Rico. Yo ya sé cuánto gasté en croquetas y no me arrepiento.» |
| M | X | X-TuAno | «"Tu año en Rico", estilo Wrapped pero de comida. ¿Qué dato querríais ver?» (encuesta en la respuesta) |
| X | TikTok | Respuesta a un comentario | Usar 01-ApplePay y contestar la duda más repetida (privacidad, Android, precio). |
| J | X | Hilo técnico | «Cómo hago una app iOS sin Mac: todo se compila en la nube. Lo bueno, lo malo y lo que me costó.» Al público dev de X le encanta. |
| V | TikTok/Reels | 04-POV, versión 2 | Mismo vídeo con otro gancho: «Cuando te preguntan "¿dónde era aquel sitio?"». Sirve de prueba A/B. |
| S | X | Cifras de la beta | «Semana 2: X personas en la beta, Y visitas guardadas. Lo que más usan: …» |

## Semana 3 · Prueba y escasez

| Día | Red | Pieza | Texto |
| --- | --- | --- | --- |
| L | TikTok/Reels | 03-Mapa de otra ciudad | Regenerar con la ciudad que más pidieron en comentarios (`CIUDAD` en `Mapa.tsx`). |
| M | X | Captura de un usuario | Con permiso: el mapa o el resumen de un beta tester. |
| X | TikTok/Reels | 01-ApplePay | Repetir el vídeo que mejor funcionó, con otro gancho en el texto. |
| J | X | Hilo | «Qué he quitado de la app por feedback de la beta.» |
| V | TikTok/Reels | 02-TuAno con datos reales | Tus datos de verdad (cambiar `DATOS_ANO`). |
| D | X | Anuncio | «Quedan N plazas en la beta antes del lanzamiento.» |

## Semana 4 · Lanzamiento

| Día | Red | Pieza | Texto |
| --- | --- | --- | --- |
| L | Todas | Teaser | «El jueves sale Rico en la App Store.» con 01-ApplePay |
| J | Todas | Lanzamiento | Vídeo nuevo, «Ya disponible», y fijar el post. En X, hilo con la historia completa y Product Hunt el mismo día. |
| V–D | TikTok | Respuestas | Vídeos contestando los comentarios del lanzamiento. |

## Audio

- **Voz en off:** ya va dentro del MP4. Es una voz de tráiler, grave y con un poco de sala, en los vídeos 1 a 4, y una voz cercana en primera persona en el 5. Las frases están en `marketing/videos/voz.py`: se cambia el texto, se ejecuta `python voz.py` y luego `npm run render`, y las escenas se ajustan solas a lo que dura cada frase.
- **Música:** se añade en TikTok o Instagram al subir el vídeo, con un sonido de moda. Después, en «Volumen», la música se baja al 15-25 % y el sonido original se deja al 100 %, así la voz se entiende por encima. No se mete música de TikTok dentro del MP4 porque tiene derechos y daría problemas en X o en anuncios.
- **Para X**, donde no se añade música en la app: pásame una pista sin derechos (de la biblioteca de audio de YouTube, Artlist, Epidemic…) y la mezclo por debajo de la voz.
- **La voz** sale de las voces neuronales de Microsoft (Edge). Para anuncios de pago conviene pasarla a una voz con licencia comercial clara, como ElevenLabs o Azure, o grabarla tú.
