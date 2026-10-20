# Plan 011: Cambiar la contraseña desde «Tu cuenta» pide la contraseña actual

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- Packages/RicoKit/Sources/Cuenta/NuevaContrasenaView.swift Packages/RicoKit/Sources/Cuenta/CuentaView.swift Packages/RicoKit/Sources/Cuenta/EstadoCuenta.swift Tests/CuentaTests.swift`
> Changes from plans 009 and 010 are expected in these files. Re-read them;
> STOP only if `NuevaContrasenaView` no longer has a single mode used both
> from the recovery link and from «Tu cuenta».

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/010-borrar-cuenta-robusto.md
- **Category**: security
- **Planned at**: commit `685cbe0`, 2026-10-20

## Why this matters

Desde «Tu cuenta», cualquiera con el iPhone desbloqueado puede poner una contraseña nueva sin saber la actual y quedarse la cuenta. En una cuenta creada con Apple, eso **añade** una contraseña que el dueño no conoce. Además, si en Supabase se activa «Secure password change», la llamada actual fallará porque la app no se reautentica. Desde el enlace de recuperación no se pide la actual (es el caso de «la he olvidado»): ese flujo se queda como está.

## Current state

- `Packages/RicoKit/Sources/Cuenta/CuentaView.swift`: botón «Cambiar contraseña» (≈ líneas 36-40) que abre `NuevaContrasenaView()` en una hoja (≈ líneas 78-80). Se muestra siempre que hay sesión.
- `Packages/RicoKit/Sources/Cuenta/NuevaContrasenaView.swift`: pide dos veces la contraseña nueva con `CampoContrasena` y `ListaReglas` (definidos en `AccesoCorreoView.swift`), y en `guardar()` llama a `cuenta.cambiarContrasena(contrasena)`.
- `Packages/RicoKit/Sources/Cuenta/ServicioCuentaSupabase.swift`: `cambiarContrasena` hace `cliente.auth.update(user: UserAttributes(password: nueva))`; `iniciarSesion(correo:contrasena:)` hace `signIn(email:password:)` y traduce `invalid_credentials` a `ErrorCuenta.credencialesIncorrectas`.
- Tras `plans/010-borrar-cuenta-robusto.md`, `SesionUsuario` tiene `proveedor: String?` (`"email"`, `"apple"`, …).
- Textos de error: `MensajeError` (en `AccesoView.swift`) muestra «El correo o la contraseña no son correctos.» para `.credencialesIncorrectas`.
- Regla de textos: todo texto visible con `Text("…", bundle: .module)`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Pruebas de la app en macOS con Xcode 26 | `xcodegen generate && xcodebuild test -project Rico.xcodeproj -scheme Rico -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Sin Mac: CI en tu rama | `git push -u origin <rama>` → `gh workflow run ci.yml --ref <rama>` → `gh run list --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId'` → `gh run watch <id> --exit-status` | exit 0 |

Empujar tu rama está permitido (única forma de compilar sin Mac). Nunca a `main` ni PR sin permiso del operador.

## Scope

**In scope**:
- `Packages/RicoKit/Sources/Cuenta/NuevaContrasenaView.swift`
- `Packages/RicoKit/Sources/Cuenta/CuentaView.swift`
- `Packages/RicoKit/Sources/Cuenta/EstadoCuenta.swift`
- `Tests/CuentaTests.swift`

**Out of scope**: el flujo del enlace de recuperación (sigue sin pedir la actual); `ServicioCuentaSupabase.swift` (se reutiliza `iniciarSesion`).

## Git workflow

- Rama: `advisor/011-reautenticar`. Commits en castellano, estilo del repo.

## Steps

### Step 1: Comprobar la contraseña actual en el estado

En `EstadoCuenta`, añade:

```swift
/// Cambio desde «Tu cuenta»: comprueba la contraseña actual volviendo a iniciar sesión.
public func cambiarContrasena(actual: String, nueva: String) async throws {
    guard let correo = sesion?.correo else { throw ErrorCuenta.credencialesIncorrectas }
    try await requerido().iniciarSesion(correo: correo, contrasena: actual)
    try await requerido().cambiarContrasena(nueva)
}
```

**Verify**: CI compila.

### Step 2: Modo «desde la cuenta» en la vista

1. Añade a `NuevaContrasenaView` un `enum Origen { case recuperacion, cuenta }` y un `init(origen: Origen = .recuperacion)`.
2. Con `.cuenta`, muestra arriba un campo «Contraseña actual» (`CampoContrasena` con `tipo: .password`), exige que no esté vacío para activar «Guardar contraseña» y llama a `cambiarContrasena(actual:nueva:)`. Si falla con `.credencialesIncorrectas`, muestra «La contraseña actual no es correcta.» (texto nuevo con `bundle: .module`) en lugar del mensaje genérico.
3. En `CuentaView`, abre `NuevaContrasenaView(origen: .cuenta)` y muestra el botón «Cambiar contraseña» solo si `cuenta.sesion?.proveedor == "email"`.

**Verify**: CI compila.

### Step 3: Pruebas

En `Tests/CuentaTests.swift`:

1. `cambiarContrasenaExigeLaActual`: registra (sin confirmación) `ana@ejemplo.com` / `pulpo2026`; `cambiarContrasena(actual: "otra2026", nueva: "nueva2026")` lanza `.credencialesIncorrectas` y `servicio.usuarios["ana@ejemplo.com"]` sigue siendo `pulpo2026`.
2. `cambiarContrasenaConLaActualCorrecta`: con `actual: "pulpo2026"` → la contraseña guardada es `nueva2026`.

(Asegúrate de que el `ServicioCuentaFalso` rellena `correo` en la sesión al iniciar sesión, como ya hace.)

**Verify**: CI en verde con las dos pruebas.

## Test plan

Las dos pruebas del paso 3. Patrón: `contrasenaIncorrecta` en el mismo archivo.

## Done criteria

- [ ] `grep -n "Contraseña actual" Packages/RicoKit/Sources/Cuenta/NuevaContrasenaView.swift` → presente.
- [ ] `grep -n "proveedor == \"email\"" Packages/RicoKit/Sources/Cuenta/CuentaView.swift` → presente.
- [ ] CI en verde con las pruebas nuevas.
- [ ] `git status` sin cambios fuera del alcance.
- [ ] Fila actualizada en `plans/README.md`.

## STOP conditions

- `SesionUsuario.proveedor` no existe (el plan 010 no se ha ejecutado).
- Volver a iniciar sesión dispara el cambio de contenedor del plan 003 (la app recarga el diario) y rompe la hoja abierta.

## Maintenance notes

- Recomendación para el operador: activar «Secure password change» en *Authentication* de Supabase cuando esto esté desplegado.
