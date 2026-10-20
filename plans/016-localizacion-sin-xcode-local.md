# Plan 016: Saber si los textos se pueden extraer sin Xcode local, y no anunciar inglés mientras no exista

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- project.yml .github/workflows/ci.yml Packages/RicoKit/Sources/*/Resources/Localizable.xcstrings`
> Changes from plan 001 in `ci.yml` are expected.

## Status

- **Priority**: P3
- **Effort**: S (investigación) + M si hay que automatizar
- **Risk**: LOW
- **Depends on**: plans/001-ci-reproducible.md
- **Category**: dx
- **Planned at**: commit `685cbe0`, 2026-10-20

## Why this matters

El código ya cumple la regla de localización: todos los textos visibles usan `Text("…", bundle: .module)` o `String(localized:bundle:)`. Pero los tres catálogos de textos (`Localizable.xcstrings`) están vacíos, porque normalmente es Xcode quien los rellena al compilar en el Mac, y aquí nunca se compila en un Mac con Xcode abierto. Mientras tanto, la app declara que está en español **e inglés** (`CFBundleLocalizations: [es, en]`), así que la App Store la listará en inglés aunque todo salga en castellano. Este plan investiga si la CI puede rellenar los catálogos y, entretanto, deja de anunciar inglés.

## Current state

- Catálogos vacíos (los tres iguales):

```json
{
  "sourceLanguage" : "es",
  "strings" : {

  },
  "version" : "1.0"
}
```

  en `Packages/RicoKit/Sources/{Cuenta,DesignSystem,Visitas}/Resources/Localizable.xcstrings`.
- `project.yml:45`: `CFBundleLocalizations: [es, en]`. Ajustes globales `LOCALIZATION_PREFERS_STRING_CATALOGS: YES` y `SWIFT_EMIT_LOC_STRINGS: YES` (líneas 24-25).
- `project.yml:55`: texto de permiso de fotos solo en castellano (`NSPhotoLibraryUsageDescription`).
- CI: `.github/workflows/ci.yml`, trabajo `ios` en `macos-15` con `xcodegen generate` y `xcodebuild test` (ver plan 001 para los cambios recientes).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lanzar la CI en tu rama | `git push -u origin <rama>` → `gh workflow run ci.yml --ref <rama>` | exit 0 |
| Esperar | `gh run list --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId'` → `gh run watch <id> --exit-status` | exit 0 |
| Descargar artefactos | `gh run download <id> -n <nombre> -D <carpeta>` | archivos |

Empujar tu rama está permitido (única forma de compilar sin Mac). Nunca a `main` ni PR sin permiso del operador.

## Scope

**In scope**:
- `.github/workflows/ci.yml` (un paso temporal de investigación y, si funciona, un trabajo manual permanente)
- `project.yml` (solo `CFBundleLocalizations`)
- `Packages/RicoKit/Sources/*/Resources/Localizable.xcstrings` (solo si la investigación produce catálogos rellenos)
- `docs/decisiones/0002-localizacion.md` (crear, con el resultado)

**Out of scope**: traducir al inglés (es trabajo de contenido, no de este plan); cambiar textos en castellano.

## Git workflow

- Rama: `advisor/016-localizacion`. Commits en castellano, estilo del repo.

## Steps

### Step 1: Dejar de anunciar inglés

En `project.yml`, `CFBundleLocalizations: [es, en]` → `CFBundleLocalizations: [es]`.

**Verify**: `grep -n "CFBundleLocalizations" project.yml` → `[es]`; CI en verde.

### Step 2: Investigar en la CI

Añade al trabajo `ios`, después de compilar, un paso de investigación:

```yaml
      - name: Investigación de localización
        if: always()
        run: |
          git status --porcelain -- '*.xcstrings' > build/xcstrings-cambiados.txt || true
          xcodebuild -exportLocalizations -project Rico.xcodeproj -localizationPath build/localizacion -exportLanguage es || true
          find build/localizacion -name '*.xliff' -exec grep -c "<trans-unit" {} \; > build/unidades.txt || true
```

y sube `build/xcstrings-cambiados.txt`, `build/unidades.txt`, `build/localizacion` y los `.xcstrings` del repositorio como artefacto `localizacion`.

Ejecuta la CI y descarga el artefacto.

**Verify**: el artefacto existe y contiene los tres archivos.

### Step 3: Decidir y documentar

Con lo descargado:

- **A.** Si `xcstrings-cambiados.txt` lista catálogos modificados (la compilación los rellenó): copia esos `.xcstrings` del artefacto al repositorio y comprueba que tienen claves (`grep -c '"localizations"\|"extractionState"'`). Convierte el paso en un trabajo **manual** (`workflow_dispatch` con un input `extraer_textos`) que suba los catálogos como artefacto, y documenta cómo usarlo.
- **B.** Si no cambian pero el `.xliff` exportado tiene unidades: documenta que la vía es `-exportLocalizations` → traducir el `.xliff` → `-importLocalizations` en la CI, y deja el trabajo manual que exporta.
- **C.** Si nada funciona: documéntalo y propón como siguiente paso abrir el proyecto una vez en un Mac.

Escribe el resultado en `docs/decisiones/0002-localizacion.md` (contexto, qué se probó, resultado, cómo extraer textos a partir de ahora). Quita el paso de investigación temporal si no es el trabajo manual final.

**Verify**: existe `docs/decisiones/0002-localizacion.md` con una de las tres conclusiones; CI en verde.

## Test plan

Sin pruebas automáticas: es una investigación. La comprobación son los artefactos y la decisión escrita.

## Done criteria

- [ ] `CFBundleLocalizations: [es]` en `project.yml`.
- [ ] `docs/decisiones/0002-localizacion.md` con la conclusión A, B o C y las instrucciones.
- [ ] Si la conclusión es A, los catálogos versionados tienen textos.
- [ ] CI en verde.
- [ ] Fila actualizada en `plans/README.md`.

## STOP conditions

- `xcodebuild -exportLocalizations` falla por necesitar firma o un dispositivo: documenta el error en el ADR y termina con la conclusión C.

## Maintenance notes

- Cuando haya inglés, vuelve a añadir `en` a `CFBundleLocalizations` y traduce también el texto de permiso de fotos (`InfoPlist.xcstrings`).
