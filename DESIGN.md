# Rico · Sistema de diseño

Las normas que sigue todo lo que se ve en Rico: la app, el icono, la web y lo que se comparte. Si algo nuevo no encaja en estas reglas, se cambia este documento antes que el diseño.

- Pantallas de referencia y tablero de marca: [lienzo de diseño](https://claude.ai/artifact/4qWi1ehNw9WpY8xi3mvxBE).
- Código: `Packages/RicoKit/Sources/DesignSystem`. Fuentes del logo: `Brand/`.

## 1. Principios

1. **Veinte segundos, una mano.** Valorar una visita tiene que poder hacerse con el pulgar y sin pensar. Lo importante va abajo o al centro; lo opcional, después.
2. **Tus datos, no los de todos.** Rico no es una red de reseñas. Nada de contadores públicos, likes ni rankings ajenos: todo habla en segunda persona («tu mapa», «lo que pediste»).
3. **El dinero como dato, sin culpa.** Los importes se muestran claros y sin juicio: nada de rojos de alarma por gastar.
4. **Comida primero.** Fotos y nombres de platos llevan el peso visual; los controles se apartan.
5. **Cálido y concreto.** Colores de cocina, letra redondeada y frases cortas. Nada de degradados, brillos de IA ni emojis como iconos.

## 2. Marca

### Concepto
«Rico» es lo que dices cuando algo está bueno. El símbolo es **un tomate cuyo cáliz es la estrella de la nota**: comida y valoración en un solo gesto.

### Símbolo
- Construcción (lienzo de 100 × 100): cuerpo en círculo achatado por arriba, estrella de cinco puntas como cáliz y tallo con curva. Formas exactas en `Brand/simbolo.svg` y en `FormasRico` (`Marca.swift`).
- **Color:** cuerpo tomate, cáliz y tallo albahaca y un brillo crema al 55 % arriba a la izquierda. El brillo desaparece en la versión oscura y a una tinta.
- **A una tinta:** la estrella se separa del cuerpo con un recorte del color de fondo (`SimboloRico(estilo: .monocromo(...))`).
- **Tamaño mínimo:** 16 pt. Por debajo de 24 pt se quita el brillo.
- **Espacio libre:** como mínimo, la altura de la estrella alrededor del símbolo.

### Logotipo
- «rico» en minúsculas, redondeada Black, con el interletraje apretado (−3 %). Nunca en mayúsculas ni en cursiva.
- **Versión vertical** (arranque y portadas): símbolo encima y palabra debajo. Imagen `Logotipo` en el catálogo de la app.
- **Versión horizontal** (cabeceras): símbolo a la izquierda, a 1,1 veces la altura de la letra (`LogotipoRico`).
- En piezas de marca, el punto de la «i» puede ser el propio tomate.

### No se hace
- Estirar, girar, contornear o añadir sombras al símbolo.
- Cambiar los colores del tomate o del cáliz por otros de la paleta.
- Poner el símbolo a color sobre fondo tomate: ahí va la versión a una tinta en crema.
- Usar el tomate como ilustración decorativa repetida. Es una firma, no un patrón.

### Icono de la app
Tres variantes de 1024 px en `App/Assets.xcassets/AppIcon.appiconset` (fuentes en `Brand/icono-*.svg`):

| Variante | Fondo | Símbolo |
| --- | --- | --- |
| Claro | Crema `#FBF6F0`, opaco y a sangre | Tomate, albahaca y brillo |
| Oscuro | Transparente (iOS pone el fondo) | Tomate `#FF5A3C`, albahaca `#7FA866`, sin brillo |
| Tintado | Negro | Gris `#D9D9D9` con la estrella recortada |

El símbolo ocupa el 58 % del ancho del icono, centrado. Nunca se añaden esquinas redondeadas: las pone iOS.

### Pantalla de arranque
- Fondo `FondoInicio` (crema; `#17130F` en oscuro) con la imagen `Logotipo` centrada en la pantalla completa.
- Al cargar, `PantallaInicio` continúa la imagen en el mismo sitio, da un latido (escala 1,06, muelle) y se desvanece en 0,25 s. **Medio segundo en total.** Es un saludo, no una espera: nunca se alarga para tapar una carga.
- Con «Reducir movimiento» activo no hay latido: solo el fundido.

## 3. Color

Tokens en `Colores.swift`. Cada uno tiene su valor en oscuro y cumple contraste AA sobre su fondo.

| Token | Claro | Oscuro | Uso |
| --- | --- | --- | --- |
| `ricoTomate` | `#D2381F` | `#FF6A4D` | Acción principal, selección, marca. Uno o dos por pantalla. |
| `ricoSobreTomate` | `#FFFFFF` | `#1F0A05` | Texto e iconos sobre tomate. |
| `ricoTomateSuave` | `#FBE3DC` | `#4A2219` | Avisos suaves («2 visitas por valorar»), etiqueta «no repetiría». |
| `ricoTomateTexto` | `#A8291A` | `#FF8F78` | Texto tomate sobre fondos suaves. |
| `ricoFondo` | `#FBF6F0` | `#17130F` | Fondo de todas las pantallas. |
| `ricoSuperficie` | `#FFFFFF` | `#241E19` | Tarjetas, campos y barras. |
| `ricoSuperficieHundida` | `#F3ECE4` | `#2E2620` | Controles segmentados y huecos de foto. |
| `ricoLinea` | `#EADFD3` | `#3A322B` | Bordes de 1 px y separadores. |
| `ricoTinta` | `#1F1A16` | `#F5EEE6` | Texto principal. |
| `ricoSecundario` | `#6B6158` | `#B5A99D` | Texto secundario, etiquetas y metadatos. |
| `ricoEstrella` | `#F0A202` | `#F5B331` | **Solo** estrellas rellenas. |
| `ricoEstrellaVacia` | `#DCCFC2` | `#4A4038` | Estrellas vacías. |
| `ricoAlbahaca` | `#3F5A30` | `#7FA866` | **Solo** el cáliz del símbolo. |
| `ricoVerde` / `ricoVerdeSuave` | `#1F5A37` / `#DDEFE3` | `#7FD3A0` / `#1D3A28` | «Volvería», «me encantó» y confirmaciones. |

Reglas:
- **Una acción tomate por vista.** Si hay dos botones principales, uno pasa a secundario.
- **El miel es de las estrellas.** No se usa para destacar otra cosa.
- **El dinero no va en rojo.** Los importes se escriben en tinta; el tomate se reserva para actuar.
- **Pines del mapa por nota:** 4,5 o más `#B02A17`, de 3,5 a 4 `#EE8A3C`, menos `#8E8379`, «quiero probar» blanco con borde `#2F6FA8`. Los colores se distinguen también por luminosidad, no solo por tono.
- **Huecos sin foto:** se rellenan con un color de `ricoPlaceholders` elegido de forma estable por el id y un `fork.knife` blanco al 55 %. Nunca se dejan en gris vacío.

## 4. Tipografía

- **App:** SF Pro Rounded (`.rico(_:peso:)`), siempre con estilos de texto para respetar Dynamic Type. Nada de tamaños fijos en texto.
- **Web, redes y piezas de marca:** Nunito (Black para titulares, Bold o SemiBold para el resto).
- Peso alto por defecto: la marca es redondeada y gruesa.

| Uso | Estilo | Peso |
| --- | --- | --- |
| Título de pantalla | `.largeTitle` | Black |
| Nombre del restaurante en tarjeta | `.headline` | Heavy |
| Importe grande | `.title` | Black |
| Texto normal | `.body` | Bold |
| Metadatos (ciudad · fecha · €) | `.footnote` / `.subheadline` | Semibold |
| Título de sección | `.footnote`, versalitas, +0,8 de interletraje | Heavy, color secundario |
| Etiquetas y chips | `.caption` | Heavy |

## 5. Espacio, forma y elevación

Constantes en `Medidas` (`Tipografia.swift`).

- **Margen lateral:** 20 pt. **Separación entre bloques:** 14–22 pt. **Dentro de una tarjeta:** 16 pt.
- **Radios:** tarjetas 20 pt, controles 12–14 pt, botones en cápsula y pantallas 40 pt en el lienzo.
- **Toque mínimo:** 44 × 44 pt, también en iconos sueltos (cerrar, quitar foto, estrellas).
- **Botón principal:** cápsula de 54 pt de alto a todo el ancho, fija abajo en `safeAreaInset` con `fondoBarraInferior()`. En iOS 26 flota en cristal; antes, sobre `.bar`.
- **Elevación:** las tarjetas usan borde de 1 px `ricoLinea`, no sombra. Lo que flota usa cristal en iOS 26 (ver Liquid Glass) y sombra suave en versiones anteriores.

### Liquid Glass (iOS 26)

La app se compila con el SDK de iOS 26 y **no** se desactiva el diseño nuevo (nunca se pone `UIDesignRequiresCompatibility`). Las barras de navegación, la búsqueda, las toolbars, las hojas y las pestañas nativas ya son de cristal; no se les pone fondo propio.

- **Cristal solo en la capa de navegación:** lo que flota sobre el contenido. Es decir, el botón + (`BotonFlotante`), la acción principal fija abajo (`BotonPrincipalStyle`), los controles sobre el mapa y las barras.
- **Nunca en el contenido:** tarjetas de visita, listas, fichas, fotos, pastillas y estrellas siguen sólidas. Cristal sobre cristal no se lee.
- **Tinte tomate solo en la acción principal** (`.regular.tint(.ricoTomate).interactive()`). Los demás elementos de cristal van sin tinte.
- **Sin fondo detrás del cristal:** encima del contenido no se pone `.background(.bar)` ni rellenos opacos; iOS 26 ya aplica el efecto de borde al hacer scroll.
- **Varios botones de cristal juntos** (por ejemplo, sobre el mapa) van dentro de un `GlassEffectContainer` para que se fundan entre sí.
- **Alternativa en iOS 17–25:** el mismo componente con relleno sólido y sombra (`if #available(iOS 26.0, *)` dentro del componente, nunca en cada pantalla).
- **Accesibilidad:** con «Reducir transparencia», iOS vuelve el cristal opaco solo. No hay que hacer nada, pero el texto sobre cristal tiene que cumplir contraste con el tinte.

## 6. Componentes

| Componente | Dónde | Reglas |
| --- | --- | --- |
| `BotonPrincipalStyle` (`.ricoPrincipal`) | Guardar, continuar | Uno por vista. Desactivado al 40 %. En iOS 26, cristal tomate interactivo; antes, cápsula sólida que reduce su escala a 0,98 al pulsar. |
| `BotonFlotante` | El + del diario | 60 pt, redondo. Cristal tomate en iOS 26; sólido con sombra antes. |
| `BotonSecundarioStyle` | Alternativas | Cápsula blanca con borde. |
| `Pastillas` | ¿Volverías?, nota de plato | Opciones excluyentes. Tocar la activa la deselecciona. 44 pt (36 en platos). Vibración de selección. |
| `SelectorEstrellas` | Ficha rápida | Tocar una estrella pone esa nota; repetir en la misma resta media. VoiceOver: ajustable en pasos de 0,5. |
| `EstrellasView` / `NotaCompacta` | Listas y tarjetas | Medias estrellas con `star.leadinghalf.filled`. En espacios pequeños, «★ 4,5». |
| `Tarjeta` | Agrupar campos | Superficie, borde y radio 20. |
| `TituloSeccion` | Cabeceras de lista | Versalitas en gris; marcado como cabecera para VoiceOver. |
| `ImagenVisita` | Portadas | Foto o relleno estable. Siempre recortada al marco, nunca deformada. |
| `SimboloRico` / `LogotipoRico` | Arranque, estados vacíos, cabeceras | Ver la sección Marca. |

## 7. Iconos

- **SF Symbols**, con peso a juego con el texto (semibold o bold). Nada de emojis como iconos de interfaz.
- Pestañas: diario (libro), mapa, listas (marcador) y resumen (barras). La activa en tomate y las demás en secundario.
- Los iconos solos llevan siempre `accessibilityLabel`; los decorativos van ocultos.

## 8. Movimiento y respuesta táctil

- Muelles cortos (`.snappy`, `.spring` de 0,25–0,3 s). Nada dura más de 0,4 s salvo que el usuario lo arrastre.
- **Vibración:** selección al cambiar estrellas o pastillas; éxito al guardar una visita.
- Con «Reducir movimiento» se quitan los latidos y escalados y se dejan los fundidos.

## 9. Voz y textos

- **Castellano de España, tuteando**, cercano y concreto. Frases cortas y sin signos de exclamación salvo en celebraciones reales («¡Funciona!»).
- **Verbos en los botones:** «Guardar visita», «Añadir plato», «Abrir Atajos». Nunca «OK» ni «Enviar».
- **Hablar de la comida, no de la app:** «¿Qué tal estuvo?», «¿Dónde fue?», «Lo que pediste».
- **Sin vocabulario técnico:** no se dice «IA», «sincronizar» ni «emparejado». Se dice lo que pasa: «Dicta tu reseña», «Guardado en tu diario».
- **Estados vacíos con siguiente paso:** «Tu diario está vacío. Pulsa + para guardar el primer sitio donde has comido.»
- **Formato:**
  - Importes con dos decimales y la moneda del sistema: «48,00 €».
  - Precio por persona como «24,00 € por persona».
  - Fechas: «Hoy», «Ayer», día de la semana dentro de los últimos 7 días y después «11 oct».
  - Plurales con concordancia automática (`^[\(n) visita](inflect: true)`).
- **Localización:** todo texto visible con `Text("…", bundle: .module)` o `String(localized:bundle:)` para que entre en el String Catalog de su módulo. El idioma base es el castellano y el segundo, el inglés.

## 10. Accesibilidad (mínimos)

- Dynamic Type en todo; las cifras grandes pueden reducirse (`minimumScaleFactor`), pero el texto normal no.
- Contraste AA en claro y en oscuro: 4,5:1 para texto y 3:1 para texto de 24 pt o más.
- La ficha de valoración se completa entera con VoiceOver: estrellas ajustables, opciones con el rasgo «seleccionado», campos con etiqueta.
- Los colores que significan algo (pines, etiquetas de plato) siempre van con texto o con distinta luminosidad.

## 11. Patrones de pantalla

- **Raíz:** `NavigationStack` con título grande, fondo `ricoFondo` y búsqueda nativa (`.searchable`).
- **Listas de visitas:** tarjetas con foto arriba, nombre y nota en una fila, metadatos debajo y agrupadas por mes.
- **Formularios rápidos:** hoja con «Cancelar» arriba a la izquierda y la acción principal fija abajo. Los cambios se guardan solo al pulsar Guardar; cancelar no deja nada a medias.
- **Paywall:** nunca al abrir la app ni antes de la primera visita valorada. Siempre muestra precio, renovación automática, «Restaurar compras», términos y privacidad.
- **Notificaciones:** firmadas con el símbolo. Título con el nombre del sitio y acción directa (estrellas o «Valorar»).

## 12. Piezas para compartir

- Historias 9:16 a una tinta (fondo tomate, texto crema): **un dato grande**, la marca pequeña arriba y `rico.app` abajo.
- Listas públicas y Wrapped llevan siempre el símbolo: cada pieza compartida es un anuncio.

## 13. Cómo se mantiene este documento

- Un color, tamaño o componente nuevo se añade primero aquí y en `DesignSystem`; después se usa.
- Si una pantalla del lienzo y este documento no coinciden, manda este documento: se corrige el lienzo.
