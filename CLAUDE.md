# Rico

Diario gastronómico para iPhone. El plan de producto completo está en `docs/plan-producto.md` (solo en local, no se versiona); las pantallas de referencia, en el lienzo de diseño (https://claude.ai/artifact/4qWi1ehNw9WpY8xi3mvxBE).

## Estructura

- `Packages/RicoCore`: lógica pura sin frameworks de Apple (emparejado de comercios, importes, estrellas, filtro de pagos). Se prueba también en Linux: `swift test --package-path Packages/RicoCore`.
- `Packages/RicoKit`: módulos de la app (`Modelos` con SwiftData, `DesignSystem`, `Visitas`, `Cuenta` con Supabase Auth, `Sincronizacion` con la base de Supabase: ver `docs/decisiones/0004-sincronizacion.md`). Los módulos nuevos del plan (`Captura`, `Mapa`, `Listas`, `Estadisticas`, `Premium`, `IA`) se añaden aquí cuando toque su bloque.
- `supabase/migrations`: esquema de PostgreSQL con seguridad por fila. Decisión y pasos para aplicarlo en `docs/decisiones/0001-servidor-propio-supabase.md`.
- `Config/`: `Rico.xcconfig` versionado; `Secretos.xcconfig` (host y clave de Supabase) no se versiona. Sin él, la app funciona solo en local.
- `App/`: punto de entrada. `Tests/`: pruebas de los módulos en el simulador.
- `project.yml`: proyecto de XcodeGen. `Rico.xcodeproj` no se versiona: `xcodegen generate`.

## Reglas

- **Diseño:** todo lo visual sigue [DESIGN.md](DESIGN.md) (marca, color, tipografía, componentes, textos y accesibilidad). Si algo nuevo no encaja, se actualiza DESIGN.md primero.

- Solo lo marcado como MVP en el plan, en el orden del backlog.
- Swift 6 (concurrencia estricta), SwiftUI, SwiftData (base local) + Supabase en la UE (servidor, cuentas y fotos), MapKit. Nada de Google Places ni Firebase.
- Local primero: la app lee y escribe siempre en SwiftData; la sincronización con Supabase va aparte. Los id son UUID generados en la app.
- Toda tabla nueva en Supabase lleva `usuario_id`, política RLS «solo el dueño», claves externas que incluyen `usuario_id`, `actualizado_en` con disparador y `borrado_en`. Los cambios de esquema van en una migración nueva, nunca editando una ya aplicada.
- Modelos de SwiftData: propiedades opcionales o con valor por defecto y enums guardados como texto (`estadoRaw`) con propiedad calculada.
- Textos visibles en castellano con `Text("…", bundle: .module)` / `String(localized:bundle:)` para que entren en el String Catalog del módulo.
- Servicios detrás de un protocolo (`BuscadorLugares`, `SugeridorFotos`) para poder probar con datos falsos.
- Accesibilidad: estilos de texto (Dynamic Type), objetivos de 44 pt, VoiceOver en la ficha de valoración, contraste AA en claro y oscuro.
- El desarrollo se hace en Windows: no hay Xcode local. Todo se compila y prueba en GitHub Actions (`.github/workflows/ci.yml`).
- Dependencias: las versiones quedan fijadas en `Config/Package.resolved`. Para actualizarlas, lanza la CI con `actualizar_dependencias: true` (`gh workflow run ci.yml --ref <rama> -f actualizar_dependencias=true`), descarga el artefacto `package-resolved` y versiónalo.
