# Plan 009: Recuperar la contraseña muestra la hoja, confirma el cambio y no deja errores pegados

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- Packages/RicoKit/Sources/Cuenta/EstadoCuenta.swift Packages/RicoKit/Sources/Cuenta/NuevaContrasenaView.swift Packages/RicoKit/Sources/Cuenta/AccesoView.swift App/RicoApp.swift Tests/CuentaTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. Changes from plans 002 and 003 in
> `EstadoCuenta.swift`, `RicoApp.swift` and `CuentaTests.swift` are expected:
> re-read those files and adapt the line numbers, but STOP if the recovery
> sheet or `errorEnlace` code no longer looks like the excerpts.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/003-datos-por-usuario.md
- **Category**: bug
- **Planned at**: commit `685cbe0`, 2026-10-20

## Why this matters

Al abrir el enlace de «¿Has olvidado tu contraseña?» la app debe pedir la contraseña nueva. Hoy:

1. `cambiarContrasena` pone `pidiendoNuevaContrasena = false` nada más guardar. Esa variable controla la hoja, así que la hoja se cierra al instante y el mensaje «Contraseña cambiada» nunca se ve.
2. La hoja se presenta desde la raíz justo cuando la sesión cambia y la raíz sustituye `AccesoView` (con su propia hoja de correo abierta) por el diario. Presentar una hoja mientras otra se está cerrando puede ignorarse, y entonces el usuario entra sin que se le pida contraseña nueva.
3. `errorEnlace` (enlace caducado) solo se borra con otro enlace correcto, así que se queda pegado en la pantalla de acceso; y si llega con la sesión iniciada no se muestra en ningún sitio.

## Current state

- `Packages/RicoKit/Sources/Cuenta/EstadoCuenta.swift`:
  - Líneas 18-21: `public var pidiendoNuevaContrasena = false` y `public var errorEnlace: ErrorCuenta?`.
  - Líneas 33-37: tarea que escucha la sesión y asigna `self?.fase = sesion.map(Fase.conSesion) ?? .sinSesion`.
  - Líneas 66-77, `abrirEnlace(_:)`: si va bien, `errorEnlace = nil` y `pidiendoNuevaContrasena = tipo == .recuperacion`; si falla, `errorEnlace = error`.
  - Líneas 79-82:

```swift
79	    public func cambiarContrasena(_ nueva: String) async throws {
80	        try await requerido().cambiarContrasena(nueva)
81	        pidiendoNuevaContrasena = false
82	    }
```

- `App/RicoApp.swift:52-54`: `.sheet(isPresented: $cuenta.pidiendoNuevaContrasena) { NuevaContrasenaView() }` aplicado al contenedor raíz (fuera del `switch`). La raíz (líneas 59-72) muestra `DiarioView` con `.sheet(isPresented: $mostrandoCuenta) { CuentaView() }` para `.conSesion`/`.soloLocal` y `AccesoView()` para `.sinSesion`.
- `Packages/RicoKit/Sources/Cuenta/NuevaContrasenaView.swift:56-65`: el botón de la barra hace `cuenta.pidiendoNuevaContrasena = false; cerrar()` y su texto es «Listo» si `hecho`, «Cancelar» si no. En `guardar()` (líneas 70-82), tras `cambiarContrasena` pone `hecho = true` y muestra `TarjetaListo`.
- `Packages/RicoKit/Sources/Cuenta/AccesoView.swift:65`: `if let error = error ?? cuenta.errorEnlace { MensajeError(error: error) }`.
- `Tests/CuentaTests.swift:163-174`, prueba `enlaceDeRecuperacionPideContrasenaNueva`; en la línea 172 espera `!estado.pidiendoNuevaContrasena` tras `cambiarContrasena`. Este plan cambia ese comportamiento, así que esa línea cambia.
- `Tests/CuentaTests.swift` contiene el `ServicioCuentaFalso` (que resuelve enlaces `rico://auth/...?correo=…` e inicia sesión) y el ayudante `esperar(hasta:)`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Pruebas de la app en macOS con Xcode 26 | `xcodegen generate && xcodebuild test -project Rico.xcodeproj -scheme Rico -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Sin Mac: CI en tu rama | `git push -u origin <rama>` → `gh workflow run ci.yml --ref <rama>` → `gh run list --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId'` → `gh run watch <id> --exit-status` | exit 0 |

Empujar tu rama está permitido (única forma de compilar sin Mac). Nunca a `main` ni PR sin permiso del operador.

## Scope

**In scope**:
- `Packages/RicoKit/Sources/Cuenta/EstadoCuenta.swift`
- `Packages/RicoKit/Sources/Cuenta/NuevaContrasenaView.swift`
- `App/RicoApp.swift`
- `Tests/CuentaTests.swift`

**Out of scope**: `AccesoView.swift` (sigue mostrando `errorEnlace`; solo cambia cuándo se borra), `ServicioCuentaSupabase.swift`, el flujo de «Cambiar contraseña» desde «Tu cuenta» (lo cubre `plans/011-reautenticar-al-cambiar-contrasena.md`).

## Git workflow

- Rama: `advisor/009-recuperar-contrasena`. Commits en castellano, estilo del repo.

## Steps

### Step 1: El estado no cierra la hoja; la hoja se cierra con «Listo»

1. En `EstadoCuenta.cambiarContrasena`, borra `pidiendoNuevaContrasena = false`.
2. Añade `public func terminarRecuperacion() { pidiendoNuevaContrasena = false }`.
3. En `NuevaContrasenaView`, el botón de la barra llama a `cuenta.terminarRecuperacion()` en lugar de asignar la variable.

**Verify**: CI compila.

### Step 2: Borrar el error de enlace cuando cambia la sesión

En la tarea que escucha la sesión (`EstadoCuenta.init`), tras asignar `fase`, si la nueva fase es `.conSesion` pon `self?.errorEnlace = nil`. Añade también `public func olvidarErrorEnlace() { errorEnlace = nil }`.

**Verify**: CI compila.

### Step 3: Presentar la hoja desde la rama con sesión, y avisar de enlaces fallidos

En `App/RicoApp.swift`:

1. Quita el `.sheet(isPresented: $cuenta.pidiendoNuevaContrasena)` del contenedor raíz.
2. En la rama `.conSesion, .soloLocal`, añade a `DiarioView` (después de su `.sheet` de `CuentaView`) el mismo `.sheet(isPresented: $cuenta.pidiendoNuevaContrasena) { NuevaContrasenaView() }`. Así la hoja la presenta la vista que aparece con la sesión nueva, y no la raíz mientras se desmonta `AccesoView`.
3. En esa misma rama, añade una alerta para enlaces fallidos con sesión iniciada: `.alert(Text("No se pudo abrir el enlace", bundle: .main), isPresented: <Binding que es true si cuenta.errorEnlace != nil y llama a cuenta.olvidarErrorEnlace() al ponerse a false>) { Button("Vale") {} }` con el mensaje «El enlace no es válido o ha caducado. Pide otro.». Usa los textos en castellano tal cual.

**Verify**: CI compila.

### Step 4: Pruebas

En `Tests/CuentaTests.swift`:

1. Cambia `enlaceDeRecuperacionPideContrasenaNueva`: tras `cambiarContrasena("nueva2026")`, `#expect(estado.pidiendoNuevaContrasena)` sigue siendo verdadero; luego `estado.terminarRecuperacion()` y `#expect(!estado.pidiendoNuevaContrasena)`.
2. Prueba nueva `errorDeEnlaceSeBorraAlEntrar`: con un servicio falso cuyo `gestionarEnlace` lance `ErrorCuenta.enlaceNoValido` para la ruta `rico://auth/recuperar?correo=caducado` (añade esa rama al falso), abre ese enlace → `errorEnlace == .enlaceNoValido`; luego inicia sesión (`iniciarConApple`) y espera con `esperar(hasta:)` a que `errorEnlace == nil`.

**Verify**: CI en verde; `gh run view <id> --log | grep -E "enlaceDeRecuperacionPideContrasenaNueva|errorDeEnlaceSeBorraAlEntrar"` → dos ✔.

## Test plan

Las dos pruebas del paso 4. La presentación real de hojas no se puede probar sin dispositivo: el revisor debe leer el cambio de `RicoApp`.

## Done criteria

- [ ] `grep -n "pidiendoNuevaContrasena = false" Packages/RicoKit/Sources/Cuenta/EstadoCuenta.swift` → solo dentro de `terminarRecuperacion`.
- [ ] `grep -c "pidiendoNuevaContrasena" App/RicoApp.swift` → `1` (la hoja, dentro de la rama con sesión).
- [ ] CI en verde.
- [ ] `git status` sin cambios fuera del alcance.
- [ ] Fila actualizada en `plans/README.md`.

## STOP conditions

- Tras el plan 003, `RicoApp.swift` ya no tiene una rama `.conSesion` con `DiarioView` (la estructura cambió más de lo previsto).
- Añadir una segunda `.sheet` a `DiarioView` provoca un aviso de compilación sobre hojas múltiples que no sabes resolver sin cambiar `DiarioView`.

## Maintenance notes

- Cuando exista la prueba en dispositivo (TestFlight), comprueba a mano: pedir recuperación desde la hoja de correo, abrir el enlace desde Mail con la app en segundo plano, ver la hoja «Nueva contraseña», guardar, ver «Contraseña cambiada» y cerrar con «Listo».
