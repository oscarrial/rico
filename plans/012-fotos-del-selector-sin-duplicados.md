# Plan 012: Las fotos elegidas con el selector no se duplican y conservan su fecha

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaView.swift Packages/RicoKit/Sources/Visitas/Servicios/Fotos.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `685cbe0`, 2026-10-20

## Why this matters

La ficha rápida evita añadir dos veces la misma foto comparando su identificador del carrete. Pero el selector de fotos (`PhotosPicker`) se crea sin `photoLibrary: .shared()`, y en ese caso iOS no da identificador (`itemIdentifier == nil`). Resultado: una foto elegida con el selector sigue apareciendo en «Fotos que hiciste aquí» y se puede añadir otra vez, gastando una de las 3 plazas del plan gratis. Además se guarda con la fecha de ahora en lugar de la de la foto.

## Current state

- `Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaView.swift:253`:

```swift
253	                    PhotosPicker(selection: $seleccionFotos, maxSelectionCount: modelo.fotosRestantes, matching: .images) {
```

- Mismo archivo, líneas 389-402:

```swift
389	    private func anadirDelSelector(_ elementos: [PhotosPickerItem]) async {
390	        guard !elementos.isEmpty else { return }
391	        for elemento in elementos {
392	            guard let datos = try? await elemento.loadTransferable(type: Data.self),
393	                  let procesada = await ProcesadorFotos.procesarEnSegundoPlano(datos) else { continue }
394	            modelo.anadirFoto(BorradorFoto(
395	                miniatura: procesada.miniatura,
396	                datos: procesada.datos,
397	                fecha: .now,
398	                identificadorCarrete: elemento.itemIdentifier
399	            ))
400	        }
401	        seleccionFotos = []
402	    }
```

- `FichaRapidaModelo.anadirFoto` descarta una foto si ya hay otra con el mismo `identificadorCarrete` no nulo.
- `Packages/RicoKit/Sources/Visitas/Servicios/Fotos.swift`: `SugeridorFotosCarrete` con funciones `nonisolated private static` que buscan un `PHAsset` por `localIdentifier` (por ejemplo `datos(id:)`, línea 77). Sigue ese estilo (fuera del actor principal).
- El permiso de fotos (`NSPhotoLibraryUsageDescription`) ya está en `project.yml`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Pruebas de la app en macOS con Xcode 26 | `xcodegen generate && xcodebuild test -project Rico.xcodeproj -scheme Rico -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Sin Mac: CI en tu rama | `git push -u origin <rama>` → `gh workflow run ci.yml --ref <rama>` → `gh run list --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId'` → `gh run watch <id> --exit-status` | exit 0 |

Empujar tu rama está permitido (única forma de compilar sin Mac). Nunca a `main` ni PR sin permiso del operador.

## Scope

**In scope**:
- `Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaView.swift`
- `Packages/RicoKit/Sources/Visitas/Servicios/Fotos.swift`

**Out of scope**: `FichaRapidaModelo.swift`; el procesado de imágenes (`plans/013-fotos-fuera-del-hilo-principal.md`).

## Git workflow

- Rama: `advisor/012-fotos-sin-duplicados`. Commits en castellano, estilo del repo.

## Steps

### Step 1: Identificador del carrete en el selector

Línea 253: añade `photoLibrary: .shared()` como último argumento de `PhotosPicker(selection:maxSelectionCount:matching:photoLibrary:)`.

**Verify**: CI compila; `grep -n "photoLibrary: .shared()" Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaView.swift` → una línea.

### Step 2: Fecha real de la foto

1. En `Fotos.swift`, añade a `SugeridorFotosCarrete` (o como función libre pública en el mismo archivo) `public nonisolated static func fechaDeCreacion(id: String) -> Date?` que devuelve `PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject?.creationDate`. Sin permiso de fotos devuelve `nil`.
2. En `anadirDelSelector`, `fecha: elemento.itemIdentifier.flatMap(SugeridorFotosCarrete.fechaDeCreacion) ?? .now`.

**Verify**: CI compila y todas las pruebas pasan.

## Test plan

No hay prueba automática: `PhotosPickerItem` no se puede construir en pruebas. La deduplicación por `identificadorCarrete` ya está cubierta por `noRepiteLaMismaFotoDelCarrete` en `Tests/FichaRapidaTests.swift`. Deja en el informe una comprobación manual para TestFlight: elegir una foto con el selector y comprobar que desaparece de «Fotos que hiciste aquí».

## Done criteria

- [ ] `grep -n "photoLibrary: .shared()" Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaView.swift` → una línea.
- [ ] `grep -n "fecha: .now" Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaView.swift` → sin resultados.
- [ ] CI en verde.
- [ ] Fila actualizada en `plans/README.md`.

## STOP conditions

- El inicializador de `PhotosPicker` con `photoLibrary:` no compila con la firma usada.

## Maintenance notes

- Con `photoLibrary: .shared()`, iOS puede pedir permiso de fotos al usar el selector en algunas versiones; el texto de permiso ya existe.
