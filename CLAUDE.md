# Rico

Diario gastronómico para iPhone. El plan de producto completo está en `docs/plan-producto.md` (solo en local, no se versiona); las pantallas de referencia, en el lienzo de diseño (https://claude.ai/artifact/4qWi1ehNw9WpY8xi3mvxBE).

## Estructura

- `Packages/RicoCore`: lógica pura sin frameworks de Apple (emparejado de comercios, importes, estrellas, filtro de pagos). Se prueba también en Linux: `swift test --package-path Packages/RicoCore`.
- `Packages/RicoKit`: módulos de la app (`Modelos` con SwiftData, `DesignSystem`, `Visitas`). Los módulos nuevos del plan (`Captura`, `Mapa`, `Listas`, `Estadisticas`, `Premium`, `IA`) se añaden aquí cuando toque su bloque.
- `App/`: punto de entrada. `Tests/`: pruebas de los módulos en el simulador.
- `project.yml`: proyecto de XcodeGen. `Rico.xcodeproj` no se versiona: `xcodegen generate`.

## Reglas

- Solo lo marcado como MVP en el plan, en el orden del backlog.
- Swift 6 (concurrencia estricta), SwiftUI, SwiftData + CloudKit, MapKit. Nada de Google Places, Firebase ni almacenamiento propio de datos de usuario.
- SwiftData con CloudKit: propiedades opcionales o con valor por defecto, relaciones opcionales, sin `unique`. Enums guardados como texto (`estadoRaw`) con propiedad calculada.
- Textos visibles en castellano con `Text("…", bundle: .module)` / `String(localized:bundle:)` para que entren en el String Catalog del módulo.
- Servicios detrás de un protocolo (`BuscadorLugares`, `SugeridorFotos`) para poder probar con datos falsos.
- Accesibilidad: estilos de texto (Dynamic Type), objetivos de 44 pt, VoiceOver en la ficha de valoración, contraste AA en claro y oscuro.
- El desarrollo se hace en Windows: no hay Xcode local. Todo se compila y prueba en GitHub Actions (`.github/workflows/ci.yml`).
