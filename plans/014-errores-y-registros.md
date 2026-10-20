# Plan 014: Los errores se registran con `Logger` y las vistas de cuenta tratan los errores en un solo sitio

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- Packages/RicoKit/Sources/ App/RicoApp.swift`
> Many files in scope were changed by earlier plans (002-013). Re-read every
> file before editing. STOP only if the duplicated `catch` blocks described
> below no longer exist (someone already centralised errors).

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/009-recuperar-contrasena.md, plans/010-borrar-cuenta-robusto.md, plans/011-reautenticar-al-cambiar-contrasena.md
- **Category**: dx
- **Planned at**: commit `685cbe0`, 2026-10-20

## Why this matters

Rico se desarrolla sin Mac ni depurador: cuando algo falle en un iPhone de TestFlight, la única pista serán los registros del sistema. Hoy no hay ni un `Logger`: el único diagnóstico es un `print` en `RicoApp`, y muchos fallos se tragan en silencio (`try?`, `guard … else { continue }`). En las vistas de cuenta se repite seis veces el mismo bloque `catch let fallo as ErrorCuenta { … } catch { self.error = .otro(error.localizedDescription) }`, y el texto técnico de `.otro` nunca se muestra ni se registra.

## Current state

- `App/RicoApp.swift:20`: `print("Rico: sin App Group (\(error)); se usa el almacenamiento de la app.")` (tras el plan 003 puede haberse movido a `abrirContenedor`).
- Bloques `catch` duplicados (líneas en `685cbe0`): `Packages/RicoKit/Sources/Cuenta/AccesoCorreoView.swift:191-195` y `:210-214`; `AccesoView.swift:109-113`; `CuentaView.swift:104-108` y `:119-123`; `NuevaContrasenaView.swift:77-81`.
- `Packages/RicoKit/Sources/Cuenta/ServicioCuentaSupabase.swift`, `traducirErrores` (≈ líneas 150-162): convierte errores desconocidos en `ErrorCuenta.otro(error.localizedDescription)`.
- Fallos silenciosos en `Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaView.swift`: `guardar()` (`catch { mostrarErrorGuardar = true }`), `anadirSugerida` (`guard … else { return }`) y `anadirDelSelector` (`guard let datos = try? … else { continue }`). En `AltaManualView.swift`, `buscar()` captura el error sin registrarlo.
- Dependencias entre módulos (`Packages/RicoKit/Package.swift`): `Modelos` depende solo de `RicoCore`; `DesignSystem` de `RicoCore`; `Visitas` y `Cuenta` dependen de `Modelos`. `RicoCore` debe seguir compilando en Linux, así que **no** puede importar `os`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Pruebas de la app en macOS con Xcode 26 | `xcodegen generate && xcodebuild test -project Rico.xcodeproj -scheme Rico -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Sin Mac: CI en tu rama | `git push -u origin <rama>` → `gh workflow run ci.yml --ref <rama>` → `gh run list --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId'` → `gh run watch <id> --exit-status` | exit 0 |

Empujar tu rama está permitido (única forma de compilar sin Mac). Nunca a `main` ni PR sin permiso del operador.

## Scope

**In scope**:
- `Packages/RicoKit/Sources/Modelos/Registro.swift` (crear)
- `Packages/RicoKit/Sources/Cuenta/EstadoCuenta.swift`
- `Packages/RicoKit/Sources/Cuenta/ServicioCuentaSupabase.swift` (solo registrar en `traducirErrores`)
- `Packages/RicoKit/Sources/Cuenta/AccesoView.swift`, `AccesoCorreoView.swift`, `CuentaView.swift`, `NuevaContrasenaView.swift` (solo los `catch`)
- `Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaView.swift`, `Packages/RicoKit/Sources/Visitas/AltaManual/AltaManualView.swift` (solo añadir registros)
- `App/RicoApp.swift` (sustituir el `print`)

**Out of scope**: `Packages/RicoCore` (no puede usar `os`); los mensajes que ve el usuario (no cambian).

## Git workflow

- Rama: `advisor/014-errores-y-registros`. Commits en castellano, estilo del repo.

## Steps

### Step 1: Registros

Crea `Packages/RicoKit/Sources/Modelos/Registro.swift`:

```swift
import os

/// Registros de la app (Consola de macOS o `log stream` con el iPhone conectado).
public enum Registro {
    public static let subsistema = "es.siweb.rico"
    public static let cuenta = Logger(subsystem: subsistema, category: "cuenta")
    public static let datos = Logger(subsystem: subsistema, category: "datos")
    public static let fotos = Logger(subsystem: subsistema, category: "fotos")
    public static let busqueda = Logger(subsystem: subsistema, category: "busqueda")
}
```

**Verify**: CI compila.

### Step 2: `EstadoCuenta` solo lanza `ErrorCuenta`

Añade en `EstadoCuenta` un ayudante privado que ejecute la operación y convierta cualquier error que no sea `ErrorCuenta` en `.otro(...)`, registrándolo con `Registro.cuenta.error("…: \(String(describing: error), privacy: .private)")`. Úsalo en todas las acciones públicas. Documenta en cada una: «Solo lanza `ErrorCuenta`.» En `ServicioCuentaSupabase.traducirErrores`, registra el caso `default` igual.

**Verify**: CI compila.

### Step 3: Un solo `catch` en las vistas

En los seis bloques duplicados, sustituye los dos `catch` por uno: `catch { self.error = error as? ErrorCuenta ?? .otro("") }`.

**Verify**: `grep -rn "catch let fallo as ErrorCuenta" Packages/RicoKit/Sources/Cuenta/` → sin resultados; CI compila.

### Step 4: Registrar fallos silenciosos

- `FichaRapidaView.guardar()`: `Registro.datos.error(...)` en el `catch`.
- `anadirSugerida` y `anadirDelSelector`: un `Registro.fotos.notice(...)` cuando no se pueden cargar o procesar los datos (sin incluir identificadores del carrete en público: `privacy: .private`).
- `AltaManualView.buscar()`: `Registro.busqueda.error(...)` en el `catch`, salvo cancelaciones.
- `RicoApp`: sustituye el `print` por `Registro.datos.notice(...)`.

**Verify**: `grep -rn "print(" App/ Packages/RicoKit/Sources/` → sin resultados; CI en verde.

## Test plan

No hacen falta pruebas nuevas: las de `CuentaTests` ya cubren que los errores de dominio llegan intactos (`credencialesIncorrectas`, `contrasenaDebil`…). Deben seguir pasando todas.

## Done criteria

- [ ] Existe `Packages/RicoKit/Sources/Modelos/Registro.swift`.
- [ ] `grep -rn "catch let fallo as ErrorCuenta" Packages/RicoKit/Sources/` → sin resultados.
- [ ] `grep -rn "print(" App/ Packages/RicoKit/Sources/` → sin resultados.
- [ ] CI en verde.
- [ ] Fila actualizada en `plans/README.md`.

## STOP conditions

- `import os` en `Modelos` rompe la compilación de algún objetivo.
- Cambiar los `catch` hace fallar alguna prueba de `CuentaTests`.

## Maintenance notes

- Nunca registres correos, contraseñas, tokens ni importes con `privacy: .public`.
- Para leer los registros de un iPhone de prueba: Consola de macOS, filtro `subsystem:es.siweb.rico`.
