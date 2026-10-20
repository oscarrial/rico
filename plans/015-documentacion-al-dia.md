# Plan 015: Los comentarios y las guías ya no hablan de CloudKit

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- Packages/RicoKit/Sources/Modelos/Modelos.swift Packages/RicoKit/Sources/Visitas/Servicios/Fotos.swift CLAUDE.md`
> Changes from plans 001 and 013 are expected (CLAUDE.md gains a line;
> Fotos.swift is refactored). Re-read the files and locate the lines by text.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/001-ci-reproducible.md, plans/013-fotos-fuera-del-hilo-principal.md
- **Category**: docs
- **Planned at**: commit `685cbe0`, 2026-10-20

## Why this matters

La decisión `docs/decisiones/0001-servidor-propio-supabase.md` sustituyó CloudKit por Supabase, pero varios comentarios siguen explicando el código con CloudKit. Quien lea el modelo de fotos creerá que se suben a iCloud. Y en `CLAUDE.md` la frase sobre los módulos futuros está en el punto de `Config/`, lo que sugiere que los módulos van en esa carpeta.

## Current state

- `Packages/RicoKit/Sources/Modelos/Modelos.swift:5-6`:

```swift
5	// Reglas de CloudKit: todas las propiedades opcionales o con valor por defecto,
6	// relaciones opcionales y sin restricciones `unique`. Los enums se guardan como texto.
```

- Mismo archivo, línea 140: `/// Imagen completa. Con almacenamiento externo, CloudKit la sube como `CKAsset`.`
- `Packages/RicoKit/Sources/Visitas/Servicios/Fotos.swift:109`: `/// Reduce las fotos antes de guardarlas: ocupan el iCloud del usuario.`
- `CLAUDE.md`, sección «Estructura»: el punto de `Packages/RicoKit` (línea 8) y el de `Config/` (línea 10), que termina con «Los módulos nuevos del plan (`Captura`, `Mapa`, `Listas`, `Estadisticas`, `Premium`, `IA`) se añaden aquí cuando toque su bloque.»
- Regla vigente (`CLAUDE.md`): «Modelos de SwiftData: propiedades opcionales o con valor por defecto y enums guardados como texto (`estadoRaw`) con propiedad calculada.» Las fotos se guardan en el iPhone (SwiftData con almacenamiento externo) y, con la sincronización, irán al bucket privado `fotos` de Supabase Storage.
- `docs/plan-producto.md` existe solo en local (está en `.gitignore`) y aún dice «SwiftData + CloudKit». No se versiona.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Buscar restos | `grep -rn "CloudKit\|iCloud\|CKAsset" --include=*.swift Packages/ App/` | sin resultados al terminar |
| CI | `git push -u origin <rama>` → `gh workflow run ci.yml --ref <rama>` → `gh run watch <id> --exit-status` | exit 0 |

Empujar tu rama está permitido (única forma de compilar sin Mac). Nunca a `main` ni PR sin permiso del operador.

## Scope

**In scope**: los dos comentarios de `Modelos.swift`, el de `Fotos.swift`, `CLAUDE.md` (mover una frase) y, solo si existe en tu copia local, `docs/plan-producto.md` (no se versiona).

**Out of scope**: cualquier cambio de código; `docs/decisiones/0001-servidor-propio-supabase.md` (habla de CloudKit a propósito, como historia).

## Git workflow

- Rama: `advisor/015-documentacion`. Un commit, en castellano.

## Steps

### Step 1: Comentarios del código

- `Modelos.swift:5-6` → «// Reglas de los modelos: propiedades opcionales o con valor por defecto, relaciones opcionales y enums guardados como texto. Así se pueden sincronizar con Supabase y migrar sin romper datos.»
- `Modelos.swift:140` → «/// Imagen completa, en almacenamiento externo de SwiftData. Con la sincronización se sube al bucket privado `fotos` de Supabase.»
- `Fotos.swift` (comentario de `ProcesadorFotos`) → «/// Reduce las fotos antes de guardarlas: ocupan espacio en el iPhone y en el servidor.»

**Verify**: `grep -rn "CloudKit\|iCloud\|CKAsset" --include=*.swift Packages/ App/` → sin resultados.

### Step 2: CLAUDE.md

Quita la frase «Los módulos nuevos del plan (…) se añaden aquí cuando toque su bloque.» del punto de `Config/` y añádela al final del punto de `Packages/RicoKit`.

**Verify**: `grep -n "Los módulos nuevos" CLAUDE.md` → una línea, la del punto de `Packages/RicoKit`.

### Step 3: Plan local (solo si existe)

Si existe `docs/plan-producto.md`, añade «(sustituido por `docs/decisiones/0001-servidor-propio-supabase.md`)» al final de las líneas que mencionan CloudKit en las secciones «Reglas para quien ejecute el plan» y «Backlog del MVP». No lo añadas a git (está ignorado).

**Verify**: `git status --short docs/` → sin `plan-producto.md`.

## Test plan

Sin pruebas: solo comentarios y documentación. La CI debe seguir en verde.

## Done criteria

- [ ] Ninguna mención a CloudKit, iCloud ni `CKAsset` en `Packages/` ni `App/`.
- [ ] Frase de módulos en el punto correcto de `CLAUDE.md`.
- [ ] CI en verde.
- [ ] Fila actualizada en `plans/README.md`.

## STOP conditions

- Encuentras código (no comentarios) que todavía use CloudKit: no lo cambies; informa.

## Maintenance notes

- La regla de `CLAUDE.md` es la referencia para las reglas de modelos; no repitas la justificación en comentarios largos.
