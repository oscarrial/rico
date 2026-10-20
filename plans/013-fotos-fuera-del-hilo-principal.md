# Plan 013: Las fotos se decodifican y reducen sin bloquear la pantalla ni disparar la memoria

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- Packages/RicoKit/Sources/DesignSystem/Componentes.swift Packages/RicoKit/Sources/Visitas/Servicios/Fotos.swift Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaView.swift Packages/RicoKit/Sources/Visitas/Diario/DiarioView.swift Packages/RicoKit/Sources/Visitas/Restaurante/FichaRestauranteView.swift`
> Changes from plans 007 and 012 are expected. Re-read the files; STOP only if
> `ImagenVisita`, `ProcesadorFotos` or the `miniatura(_:)` helper no longer
> look like the excerpts below.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/007-logica-del-diario-y-restaurante.md, plans/012-fotos-del-selector-sin-duplicados.md
- **Category**: perf
- **Planned at**: commit `685cbe0`, 2026-10-20

## Why this matters

1. Cada tarjeta del diario y la cabecera del restaurante hacen `UIImage(data:)` dentro de `body`: decodificar un JPEG (y leerlo de disco, porque las miniaturas usan almacenamiento externo) en el hilo principal cada vez que la vista se repinta. Eso provoca tirones al hacer scroll y al escribir en la búsqueda.
2. `ProcesadorFotos` decodifica la foto original entera (una foto de 48 MP son unos 190 MB en memoria) y la vuelve a dibujar dos veces. Con tres fotos grandes, iOS puede cerrar la app por memoria.
3. Las miniaturas sugeridas se piden una tras otra, con acceso a red (iCloud), así que la tira «Fotos que hiciste aquí» tarda en aparecer.

## Current state

- `Packages/RicoKit/Sources/DesignSystem/Componentes.swift:126-153`, `ImagenVisita`:

```swift
136	    public var body: some View {
137	        if let miniatura, let imagen = UIImage(data: miniatura) {
138	            Image(uiImage: imagen)
139	                .resizable()
140	                .scaledToFill()
141	                .accessibilityHidden(true)
142	        } else {
143	            let colores = Color.ricoPlaceholders
144	            colores[abs(semilla) % colores.count]
...
```

  Se usa en `DiarioView.swift` (tarjeta de visita) y `FichaRestauranteView.swift` (cabecera), con `ImagenVisita(miniatura:semilla:)`.
- `Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaView.swift:346-356`, ayudante `miniatura(_ datos: Data)` con `UIImage(data: datos)` en el cuerpo.
- `Packages/RicoKit/Sources/Visitas/Servicios/Fotos.swift:110-141`, `ProcesadorFotos`: `procesar(_:)` usa `UIImage(data:)` y `redimensionar(_:ladoMaximo:)` con `UIGraphicsImageRenderer` (2048 px la grande, 600 px la miniatura; JPEG 0,8 y 0,7). `procesarEnSegundoPlano` lo ejecuta en `Task.detached`.
- Mismo archivo, líneas 61-68: las miniaturas sugeridas se piden en un `for … await` secuencial (máximo 12).
- `DESIGN.md` §6: `ImagenVisita` «Foto o relleno estable. Siempre recortada al marco, nunca deformada.» El relleno de color se mantiene mientras carga.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Pruebas de la app en macOS con Xcode 26 | `xcodegen generate && xcodebuild test -project Rico.xcodeproj -scheme Rico -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Sin Mac: CI en tu rama | `git push -u origin <rama>` → `gh workflow run ci.yml --ref <rama>` → `gh run list --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId'` → `gh run watch <id> --exit-status` | exit 0 |

Empujar tu rama está permitido (única forma de compilar sin Mac). Nunca a `main` ni PR sin permiso del operador.

## Scope

**In scope**:
- `Packages/RicoKit/Sources/DesignSystem/Componentes.swift` (solo `ImagenVisita`)
- `Packages/RicoKit/Sources/Visitas/Servicios/Fotos.swift`
- `Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaView.swift` (solo el ayudante `miniatura(_:)`)
- `Tests/ProcesadorFotosTests.swift` (crear)

**Out of scope**: los modelos, el número de fotos, la calidad JPEG (se mantienen 0,8 y 0,7), el aspecto visual.

## Git workflow

- Rama: `advisor/013-fotos-rendimiento`. Commits en castellano, estilo del repo.

## Steps

### Step 1: Reducir con ImageIO

Reescribe `ProcesadorFotos.procesar(_:)` con `CGImageSourceCreateWithData` y `CGImageSourceCreateThumbnailAtIndex`, con las opciones `kCGImageSourceCreateThumbnailFromImageAlways: true`, `kCGImageSourceCreateThumbnailWithTransform: true` (respeta la orientación) y `kCGImageSourceThumbnailMaxPixelSize` = 2048 y 600. Codifica cada `CGImage` como JPEG (por ejemplo `UIImage(cgImage:).jpegData(compressionQuality:)`). Mantén la firma pública y `Resultado`. Borra `redimensionar` si queda sin uso.

**Verify**: CI compila.

### Step 2: Prueba del procesado

Crea `Tests/ProcesadorFotosTests.swift`: genera una imagen de 3000×2000 con `UIGraphicsImageRenderer` (formato con `scale = 1`), conviértela en JPEG y pásala por `ProcesadorFotos.procesar`. Comprueba con `UIImage(data:)` del resultado que la grande mide como mucho 2048 por el lado largo, la miniatura como mucho 600, y que se mantiene la proporción 3:2 (con ±1 px).

**Verify**: CI en verde con la prueba nueva.

### Step 3: Decodificar fuera del hilo principal

1. `ImagenVisita`: añade `@State private var imagen: UIImage?`. En el cuerpo, si `imagen` existe muestra `Image(uiImage:)` y si no, el relleno de color de siempre. Añade `.task(id: miniatura) { imagen = await Self.decodificar(miniatura) }`, donde `decodificar` es `nonisolated static func decodificar(_ datos: Data?) async -> UIImage?` que hace `UIImage(data:)` y después `await imagen.byPreparingForDisplay()`.
2. Añade una caché pequeña: `NSCache<NSData, UIImage>` estática con `countLimit = 100`, consultada antes de decodificar.
3. En `FichaRapidaView`, sustituye el cuerpo del ayudante `miniatura(_:)` por `ImagenVisita(miniatura: datos, semilla: 0)` dentro del mismo marco y recorte.

**Verify**: CI compila; `grep -n "UIImage(data:" Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaView.swift` → sin resultados; en `Componentes.swift` solo dentro de `decodificar`.

### Step 4: Miniaturas sugeridas en paralelo

En `SugeridorFotosCarrete.fotos(...)`, sustituye el bucle secuencial por un `withTaskGroup` que lance como mucho 4 peticiones a la vez y conserve el orden original (guarda el índice y ordena al final).

**Verify**: CI en verde.

## Test plan

La prueba del paso 2. La fluidez del scroll y la memoria solo se ven en un dispositivo: deja en el informe una comprobación manual para TestFlight (añadir 3 fotos de 48 MP sin que la app se cierre; hacer scroll en un diario con 30 visitas con foto).

## Done criteria

- [ ] `grep -n "CGImageSourceCreateThumbnailAtIndex" Packages/RicoKit/Sources/Visitas/Servicios/Fotos.swift` → presente.
- [ ] `grep -n "withTaskGroup" Packages/RicoKit/Sources/Visitas/Servicios/Fotos.swift` → presente.
- [ ] CI en verde con `ProcesadorFotosTests`.
- [ ] `git status` sin cambios fuera del alcance.
- [ ] Fila actualizada en `plans/README.md`.

## STOP conditions

- `byPreparingForDisplay()` o la caché provocan errores de concurrencia estricta de Swift 6 que no se resuelven sin `@unchecked Sendable` o `nonisolated(unsafe)`: informa en lugar de silenciarlos.
- La prueba de proporción falla por la orientación EXIF.

## Maintenance notes

- Si se suben fotos al servidor (sincronización), usa los mismos `Resultado.datos` y `Resultado.miniatura`; no vuelvas a procesar el original.
