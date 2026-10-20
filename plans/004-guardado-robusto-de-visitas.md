# Plan 004: Guardar una visita no deja cambios a medias, conserva los platos y no pierde fotos

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaModelo.swift Tests/FichaRapidaTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `685cbe0`, 2026-10-20

## Why this matters

`FichaRapidaModelo.guardar(en:)` promete en su comentario que «cancelar no deja nada a medias», pero:

1. Inserta la visita (y quizá un restaurante) y modifica objetos **antes** de `save()`. Si `save()` falla, nada se deshace: el autoguardado de SwiftData lo persistirá después, y un segundo toque en «Guardar» inserta **otra** visita.
2. En cada guardado borra todos los platos y crea otros nuevos con el mismo `id`. Para la futura sincronización por `id` eso será un borrado más una inserción del mismo registro, y los enlaces foto→plato no sobreviven a ninguna edición.
3. Al editar, las fotos sin miniatura se quedan fuera del borrador y luego se **borran** por no estar en él.

## Current state

`Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaModelo.swift`:

- Líneas 40-41, comentario de la clase: «Trabaja sobre un borrador y solo toca SwiftData al guardar, así cancelar no deja nada a medias.»
- Líneas 104-107, el borrador de fotos omite las que no tienen miniatura:

```swift
104	        fotos = visita.fotosOrdenadas.compactMap { foto in
105	            guard let miniatura = foto.miniatura else { return nil }
106	            return BorradorFoto(id: foto.id, miniatura: miniatura, datos: nil, fecha: foto.fecha, identificadorCarrete: foto.identificadorCarrete)
107	        }
```

- Líneas 142-144: `quitarFoto(_:)` solo quita del array `fotos`.
- Líneas 150-183, `guardar(en:)`: inserta y modifica, llama a `guardarPlatos` y `guardarFotos`, pone `estado = .valorada` y termina con `try contexto.save()`. No hay `catch` ni `rollback`.
- Líneas 185-199, `guardarPlatos`:

```swift
185	    private func guardarPlatos(en visita: Visita, contexto: ModelContext) {
186	        let anteriores = visita.platos ?? []
187	        var nuevos: [Plato] = []
188	        for (orden, borrador) in platos.enumerated() {
189	            guard let nombre = borrador.nombre.nilSiVacio else { continue }
190	            let plato = Plato(nombre: nombre, valoracion: borrador.valoracion, orden: orden)
191	            plato.id = borrador.id
192	            contexto.insert(plato)
193	            nuevos.append(plato)
194	        }
195	        visita.platos = nuevos
196	        for plato in anteriores {
197	            contexto.delete(plato)
198	        }
199	    }
```

- Líneas 201-218, `guardarFotos`: borra toda foto existente cuyo `id` no esté en el borrador (`for foto in existentes where !idsBorrador.contains(foto.id) { contexto.delete(foto) }`), reordena las existentes e inserta las nuevas.
- Modelo `Plato` (`Packages/RicoKit/Sources/Modelos/Modelos.swift:111-135`): `id`, `nombre`, `valoracionRaw` (con propiedad calculada `valoracion`), `precioCentimos`, `nota`, `orden`, `visita`, `fotos`.
- Pruebas existentes en `Tests/FichaRapidaTests.swift` (por ejemplo `editarReemplazaPlatosYConservaFotos`, líneas 59-79). Patrón: `@MainActor @Suite`, contenedor `ContenedorRico.crear(enMemoria: true)`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Pruebas de la app en macOS con Xcode 26 | `xcodegen generate && xcodebuild test -project Rico.xcodeproj -scheme Rico -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Sin Mac: CI en tu rama | `git push -u origin <rama>` → `gh workflow run ci.yml --ref <rama>` → `gh run list --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId'` → `gh run watch <id> --exit-status` | exit 0 |
| Ver pruebas | `gh run view <id> --log \| grep -E "✔\|✖"` | nuevas con ✔ |

Empujar tu rama está permitido (única forma de compilar sin Mac). Nunca a `main` ni PR sin permiso del operador.

## Scope

**In scope**:
- `Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaModelo.swift`
- `Tests/FichaRapidaTests.swift`

**Out of scope**:
- `FichaRapidaView.swift` — el manejo de errores de la vista no cambia (`mostrarErrorGuardar`).
- Los modelos de `Modelos.swift`.
- El importe y la moneda (los cubre `plans/006-importes-y-moneda.md`).

## Git workflow

- Rama: `advisor/004-guardado-robusto`. Commits en castellano, estilo del repo.

## Steps

### Step 1: Deshacer si el guardado falla

Envuelve todo lo que hay en `guardar(en:)` después del `guard puedeGuardar` en un `do { … } catch { contexto.rollback(); throw error }`. El `rollback()` de `ModelContext` descarta los cambios sin guardar (inserciones, borrados y modificaciones).

**Verify**: CI compila y las pruebas existentes pasan.

### Step 2: Actualizar los platos en su sitio

Reescribe `guardarPlatos` para:

1. Hacer un diccionario `existentes` de `visita.platos ?? []` por `id`.
2. Para cada borrador con nombre no vacío (en orden): si hay un `Plato` existente con ese `id`, actualizar `nombre`, `valoracion` y `orden`; si no, crear uno nuevo con `plato.id = borrador.id`, `contexto.insert(plato)` y asociarlo (`plato.visita = visita`).
3. Borrar solo los existentes cuyo `id` no aparece entre los borradores conservados.

No vuelvas a asignar `visita.platos = nuevos`: basta con fijar `plato.visita` en los nuevos (la inversa se mantiene sola).

**Verify**: CI compila y `editarReemplazaPlatosYConservaFotos` sigue pasando.

### Step 3: Borrar solo las fotos que el usuario quitó

1. Añade `private var fotosQuitadas: Set<UUID> = []`.
2. En `quitarFoto(_:)`, además de quitarla del array, `fotosQuitadas.insert(id)`.
3. En `guardarFotos`, borra solo `existentes` cuyo `id` esté en `fotosQuitadas` (y no las que simplemente no están en el borrador).
4. El orden de las fotos que no están en el borrador (sin miniatura) no se toca.

**Verify**: CI compila.

## Test plan

En `Tests/FichaRapidaTests.swift`, tres pruebas nuevas:

1. `editarConservaLosMismosPlatos`: guarda una visita con dos platos; recuerda `visita.platosOrdenados.map(\.persistentModelID)`; edita (cambia la valoración del primero) y guarda; los `persistentModelID` son los mismos y la valoración cambió.
2. `quitarUnPlatoSoloBorraEse`: guarda con dos platos, edita quitando uno (`quitarPlato`), guarda → queda uno y `fetchCount(FetchDescriptor<Plato>()) == 1`.
3. `editarNoBorraFotosSinMiniatura`: guarda una visita; inserta a mano en el contexto una `Foto(datos: Data([1]), miniatura: nil)` asociada (`foto.visita = visita`) y guarda; abre `FichaRapidaModelo(visita:)`, cambia las estrellas y guarda → `visita.fotos?.count` sigue igual.

Patrón: `editarReemplazaPlatosYConservaFotos`.

**Verify**: CI en verde; `gh run view <id> --log | grep -E "editarConservaLosMismosPlatos|quitarUnPlatoSoloBorraEse|editarNoBorraFotosSinMiniatura"` → tres ✔.

## Done criteria

- [ ] `grep -n "rollback()" Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaModelo.swift` → una línea.
- [ ] `grep -n "fotosQuitadas" Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaModelo.swift` → al menos tres líneas.
- [ ] CI en verde con las 3 pruebas nuevas y las anteriores.
- [ ] `git status` sin cambios fuera del alcance.
- [ ] Fila actualizada en `plans/README.md`.

## STOP conditions

- `ModelContext.rollback()` no está disponible en el SDK de la CI.
- La prueba `editarReemplazaPlatosYConservaFotos` falla tras el paso 2 y el fallo no se explica por el cambio de identidad de los platos.

## Maintenance notes

- No hay prueba directa del `rollback` porque forzar un fallo de `save()` en SwiftData en memoria no es fiable; el revisor debe leer el `catch`.
- Cuando se añada la sincronización, `fotosQuitadas` y los platos borrados deberán marcarse como borrado suave (`borrado_en`) en lugar de borrarse en el servidor.
