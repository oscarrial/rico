# Plan 001: La CI compila siempre con las mismas versiones, más rápido y con permisos mínimos

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- .github/workflows/ci.yml .gitignore CLAUDE.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `685cbe0`, 2026-10-20

## Why this matters

El proyecto se desarrolla en Windows sin Xcode: GitHub Actions es el **único** sitio donde se compila y se prueba la app. Hoy cada ejecución resuelve la última versión 2.x de `supabase-swift` (y sus dependencias), usa la última versión estable de Xcode del día y una versión cualquiera de XcodeGen. Una publicación ajena puede poner la CI en rojo sin que cambie nada del repositorio, y nadie puede reproducir una compilación anterior. Además, la CI no tiene caché (cada ejecución clona todos los paquetes en el runner de macOS, que cuesta 10 veces más que Linux), repite las pruebas de RicoCore que ya pasan en Linux, recibe secretos sin un bloque `permissions` y usa acciones de terceros por etiqueta móvil.

## Current state

- `.github/workflows/ci.yml` — único workflow. Dos trabajos: `nucleo` (Linux, `container: swift:6.1`) e `ios` (`runs-on: macos-15`).
- `.gitignore:11` — `Package.resolved` está ignorado en todo el repositorio.
- `Packages/RicoKit/Package.swift:14` — `.package(url: "https://github.com/supabase/supabase-swift.git", from: "2.20.0")`.
- El proyecto de Xcode no se versiona: se genera en la CI con `xcodegen generate` a partir de `project.yml`. Por eso no existe ningún `Package.resolved` en el repositorio.

Extractos de `.github/workflows/ci.yml` (en `685cbe0`):

```yaml
 1	name: CI
 3	on:
 4	  push:
 5	    branches: [main]
 6	  pull_request:
 7	  workflow_dispatch:
...
20	      - uses: actions/checkout@v4
...
29	      - uses: actions/checkout@v4
31	      - name: Elegir la última versión estable de Xcode
32	        uses: maxim-lobanov/setup-xcode@v1
33	        with:
34	          xcode-version: latest-stable
36	      - name: Instalar XcodeGen
37	        run: brew install xcodegen
39	      - name: Pruebas de RicoCore (macOS)
40	        run: swift test --package-path Packages/RicoCore
...
54	      - name: Generar Rico.xcodeproj
55	        run: xcodegen generate
57	      - name: Compilar y probar en el simulador
58	        run: |
59	          set -o pipefail
60	          mkdir -p build
61	          SIMULADOR=$(xcrun simctl list devices available | grep -m1 -E '^\s+iPhone' | grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}')
62	          echo "Simulador: $SIMULADOR"
63	          xcodebuild test \
64	            -project Rico.xcodeproj \
65	            -scheme Rico \
66	            -destination "id=$SIMULADOR" \
67	            -resultBundlePath build/Resultados.xcresult \
68	            CODE_SIGNING_ALLOWED=NO \
69	            2>&1 | tee build/xcodebuild.log | xcbeautify --renderer github-actions
...
73	        uses: actions/upload-artifact@v4
```

La última ejecución en verde usó **Xcode 26.3** («Xcode is set to 26.3.0») y **XcodeGen 2.46.0** (instalado por brew).

Convención del repositorio: comentarios y nombres de pasos en castellano, igual que los existentes.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Lanzar la CI en tu rama | `git push -u origin <rama>` y después `gh workflow run ci.yml --ref <rama>` | exit 0 |
| Obtener el id de la ejecución | `gh run list --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId'` | un número |
| Esperar el resultado | `gh run watch <id> --exit-status` | exit 0, ambos trabajos ✓ |
| Ver los fallos | `gh run view <id> --log-failed` | — |
| Descargar un artefacto | `gh run download <id> -n <nombre> -D <carpeta>` | archivos en la carpeta |
| Validar YAML (si tienes Python) | `python -c "import yaml,sys;yaml.safe_load(open('.github/workflows/ci.yml'))"` | sin salida, exit 0 |

No hace falta Mac: todo se comprueba en GitHub Actions. Empujar la rama `advisor/001-ci-reproducible` está permitido porque es la única forma de compilar; **nunca** empujes a `main` ni abras PR salvo que el operador lo pida.

## Scope

**In scope**:
- `.github/workflows/ci.yml`
- `.gitignore`
- `Config/Package.resolved` (crear)
- `.github/dependabot.yml` (crear)
- `CLAUDE.md` (añadir una línea en «Reglas» sobre cómo actualizar dependencias)

**Out of scope**:
- `project.yml` y `Packages/*/Package.swift` — no se cambian las dependencias ni sus rangos; solo se fija lo resuelto.
- El paso «Claves de Supabase» de la CI — se queda igual.
- El trabajo `nucleo` salvo la línea de `actions/checkout` (fijarla por SHA).

## Git workflow

- Rama: `advisor/001-ci-reproducible`.
- Un commit por paso lógico. Estilo del repositorio: frase en castellano, en presente o como resumen, sin prefijos (ejemplo de `git log`: «Cuentas con correo y contraseña en lugar de código»).
- No hagas merge a `main`.

## Steps

### Step 1: Exportar el `Package.resolved` desde la CI

En el trabajo `ios`, justo después del paso «Compilar y probar en el simulador», añade un paso que suba siempre el archivo resuelto como artefacto:

```yaml
      - name: Guardar Package.resolved
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: package-resolved
          path: Rico.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
          if-no-files-found: error
```

Empuja la rama, lanza la CI con `gh workflow run` y espera a que termine.

**Verify**: `gh run download <id> -n package-resolved -D /tmp/resuelto && grep -c '"identity" : "supabase-swift"' /tmp/resuelto/Package.resolved` → `1`.

### Step 2: Versionar el archivo resuelto

1. Copia el archivo descargado a `Config/Package.resolved`.
2. En `.gitignore`, justo debajo de la línea `Package.resolved` (línea 11), añade `!Config/Package.resolved`.

**Verify**: `git check-ignore -v Config/Package.resolved; echo $?` → `1` (no ignorado) y `git status --short Config/Package.resolved` muestra `??`.

### Step 3: Usar el archivo versionado al compilar, con caché

En el trabajo `ios`:

1. Añade a nivel de trabajo un `workflow_dispatch` input para regenerar dependencias. Arriba, en `on.workflow_dispatch`, declara:

```yaml
  workflow_dispatch:
    inputs:
      actualizar_dependencias:
        description: "Resolver dependencias de nuevo (ignora Config/Package.resolved)"
        type: boolean
        default: false
```

2. Tras «Generar Rico.xcodeproj», añade:

```yaml
      - name: Fijar versiones de dependencias
        if: ${{ !inputs.actualizar_dependencias }}
        run: |
          mkdir -p Rico.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
          cp Config/Package.resolved Rico.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

      - name: Caché de paquetes Swift
        uses: actions/cache@v4
        with:
          path: build/SourcePackages
          key: spm-${{ hashFiles('Config/Package.resolved') }}
```

3. En `xcodebuild test`, añade estos argumentos (antes de `CODE_SIGNING_ALLOWED=NO`): `-clonedSourcePackagesDirPath build/SourcePackages` y, solo cuando no se actualizan dependencias, `-onlyUsePackageVersionsFromResolvedFile`. Hazlo con una variable de shell:

```bash
          FIJAR=""
          if [ "${{ inputs.actualizar_dependencias }}" != "true" ]; then FIJAR="-onlyUsePackageVersionsFromResolvedFile"; fi
```

y pasa `$FIJAR` a `xcodebuild`.

**Verify**: CI en verde; `gh run view <id> --log | grep -c onlyUsePackageVersionsFromResolvedFile` → `≥1`. Lanza la CI una segunda vez y comprueba `gh run view <id2> --log | grep -i "Cache restored from key: spm-"` → una línea.

### Step 4: Fijar Xcode y XcodeGen

1. `xcode-version: latest-stable` → `xcode-version: "26.3"` y cambia el nombre del paso a «Elegir Xcode 26.3».
2. Sustituye «Instalar XcodeGen» (`brew install xcodegen`) por la versión fija:

```yaml
      - name: Instalar XcodeGen 2.46.0
        run: |
          curl -fsSL -o "$RUNNER_TEMP/xcodegen.zip" https://github.com/yonaskolb/XcodeGen/releases/download/2.46.0/xcodegen.zip
          unzip -q "$RUNNER_TEMP/xcodegen.zip" -d "$RUNNER_TEMP"
          echo "$RUNNER_TEMP/xcodegen/bin" >> "$GITHUB_PATH"
```

**Verify**: CI en verde; `gh run view <id> --log | grep -E "Xcode is set to 26\.3"` → una línea; `grep -n "latest-stable\|brew install xcodegen" .github/workflows/ci.yml` → sin resultados.

### Step 5: Quitar la prueba duplicada de RicoCore en macOS

Borra el paso «Pruebas de RicoCore (macOS)» (líneas 39-40). El trabajo `nucleo` de Linux ya las ejecuta.

**Verify**: `grep -n "Pruebas de RicoCore (macOS)" .github/workflows/ci.yml` → sin resultados; CI en verde y el trabajo `RicoCore (Linux)` sigue mostrando «Test run with 21 tests» o más.

### Step 6: Permisos mínimos y acciones fijadas por SHA

1. Debajo de `on:` añade a nivel raíz:

```yaml
permissions:
  contents: read
```

2. Obtén los SHA de las etiquetas que se usan:
   - `gh api repos/actions/checkout/commits/v4 --jq .sha`
   - `gh api repos/actions/upload-artifact/commits/v4 --jq .sha`
   - `gh api repos/actions/cache/commits/v4 --jq .sha`
   - `gh api repos/maxim-lobanov/setup-xcode/commits/v1 --jq .sha`
3. Sustituye cada `uses: <acción>@vN` por `uses: <acción>@<sha> # vN`.

**Verify**: `grep -nE "uses: [^ ]+@v[0-9]+\s*$" .github/workflows/ci.yml` → sin resultados; CI en verde.

### Step 7: Dependabot para las acciones y nota en CLAUDE.md

1. Crea `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: monthly
```

2. En `CLAUDE.md`, sección «Reglas», añade al final: «- Dependencias: las versiones quedan fijadas en `Config/Package.resolved`. Para actualizarlas, lanza la CI con `actualizar_dependencias: true` (`gh workflow run ci.yml --ref <rama> -f actualizar_dependencias=true`), descarga el artefacto `package-resolved` y versiónalo.»

**Verify**: `python -c "import yaml;yaml.safe_load(open('.github/dependabot.yml'))"` → exit 0; `grep -c "Config/Package.resolved" CLAUDE.md` → `1`.

## Test plan

No hay pruebas nuevas: el cambio es de infraestructura. La verificación son dos ejecuciones completas de la CI en verde (la segunda con caché restaurada) y una ejecución con `-f actualizar_dependencias=true` también en verde.

## Done criteria

- [ ] `Config/Package.resolved` versionado y contiene `supabase-swift`.
- [ ] `grep -n "latest-stable\|brew install xcodegen\|Pruebas de RicoCore (macOS)" .github/workflows/ci.yml` → sin resultados.
- [ ] `grep -c "permissions:" .github/workflows/ci.yml` → `1`.
- [ ] Ninguna acción usa etiqueta móvil sin SHA.
- [ ] Última ejecución de la CI en la rama: ambos trabajos ✓, log con «Xcode is set to 26.3» y con `-onlyUsePackageVersionsFromResolvedFile`.
- [ ] Una segunda ejecución restaura la caché `spm-…`.
- [ ] `git status` sin cambios fuera del alcance.
- [ ] Fila de este plan actualizada en `plans/README.md`.

## STOP conditions

- `gh run download` no encuentra `Package.resolved` en la ruta indicada (Xcode lo guarda en otra ruta): informa de la ruta real que aparezca en el log (`find . -name Package.resolved` añadido temporalmente al paso).
- Xcode 26.3 ya no está disponible en `macos-15` (setup-xcode falla): informa de las versiones que lista el log; no elijas otra por tu cuenta.
- El zip de XcodeGen no contiene `xcodegen/bin/xcodegen`.
- La CI falla con `-onlyUsePackageVersionsFromResolvedFile` por un error de resolución dos veces seguidas.

## Maintenance notes

- Cuando se suba la versión de Xcode, cambia `"26.3"` en un commit propio y comprueba la CI.
- Añadir una dependencia nueva a `Package.swift` exige regenerar `Config/Package.resolved` (input `actualizar_dependencias`), o la CI fallará por versión no resuelta. Es intencionado.
- Revisor: comprueba que los SHA corresponden a las etiquetas comentadas.
