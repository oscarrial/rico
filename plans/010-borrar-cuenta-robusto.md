# Plan 010: Borrar la cuenta lo borra todo en el servidor de una vez, limpia el iPhone y revoca el acceso de Apple

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- Packages/RicoKit/Sources/Cuenta/ App/RicoApp.swift supabase/ Tests/CuentaTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. Changes from plans 002, 003 and 009
> are expected; re-read the files and adapt line numbers.

## Status

- **Priority**: P2
- **Effort**: L
- **Risk**: MED
- **Depends on**: plans/003-datos-por-usuario.md, plans/009-recuperar-contrasena.md
- **Category**: security
- **Planned at**: commit `685cbe0`, 2026-10-20

## Why this matters

La App Store exige que se pueda borrar la cuenta desde la app y, si se usa «Iniciar sesión con Apple», que se **revoquen** los tokens de Apple al hacerlo (guía 5.1.1(v)). Hoy:

1. **Las fotos no se borran en la misma operación que la cuenta**: la app las borra una a una con la API de Storage y después llama a la función SQL `borrar_mi_cuenta()`. Si la app se cierra o pierde la conexión entre medias, queda una cuenta a medio borrar. Y cualquier otro cliente que llame solo a la función deja las fotos en el servidor, lo que choca con el derecho de supresión del RGPD.
2. **Hay un bucle `while true`** que solo termina cuando el listado vuelve vacío: si algún archivo no se puede borrar, la pantalla se queda girando para siempre.
3. **El borrado local va después de cerrar sesión**: si falla, la vista ya no está en pantalla y nadie ve el error; los datos se quedan en el iPhone. Y si no hay sesión, `borrarCuenta()` termina «bien» sin borrar nada en el servidor.
4. **No se revoca el token de Apple**: la app no guarda el `authorizationCode` y nunca llama al servicio de revocación de Apple.

## Current state

- `Packages/RicoKit/Sources/Cuenta/ServicioCuentaSupabase.swift:122-136`:

```swift
122	    public func borrarCuenta() async throws {
123	        guard let usuario = sesionActual else { return }
124	        // Las fotos no se borran en cascada desde SQL: se quitan antes con la API de Storage.
125	        let carpeta = usuario.id.uuidString.lowercased()
126	        let fotos = cliente.storage.from(Self.bucketFotos)
127	        try await traducirErrores {
128	            while true {
129	                let archivos = try await fotos.list(path: carpeta, options: SearchOptions(limit: 1000))
130	                guard !archivos.isEmpty else { break }
131	                _ = try await fotos.remove(paths: archivos.map { "\(carpeta)/\($0.name)" })
132	            }
133	            try await cliente.rpc("borrar_mi_cuenta").execute()
134	        }
135	        try? await cliente.auth.signOut()
136	    }
```

- `Packages/RicoKit/Sources/Cuenta/CuentaView.swift:111-124`:

```swift
111	    private func borrarCuenta() async {
112	        trabajando = true
113	        defer { trabajando = false }
114	        do {
115	            // Primero el servidor: si falla, el usuario no pierde sus datos locales.
116	            try await cuenta.borrarCuenta()
117	            try ContenedorRico.borrarTodo(en: contexto)
118	            cerrar()
...
```

- `ContenedorRico.borrarTodo(en:)` (`Packages/RicoKit/Sources/Modelos/ContenedorRico.swift`) borra todas las filas locales del contenedor activo y guarda.
- `Packages/RicoKit/Sources/Cuenta/ServicioCuenta.swift:4-12`: `SesionUsuario` tiene `id: UUID` y `correo: String?`; no guarda el proveedor (Apple o correo).
- `Packages/RicoKit/Sources/Cuenta/AccesoView.swift:92-119`: al iniciar sesión con Apple solo se lee `credencial.identityToken`; `credencial.authorizationCode` se descarta.
- Servidor: `supabase/migrations/20261020130000_esquema_inicial.sql:231-252` define `public.borrar_mi_cuenta()` (`security definer`, borra `auth.users` del usuario actual; las filas caen en cascada). Las fotos están en el bucket privado `fotos`, en la carpeta `{usuario_id}/` con archivos `{id}.jpg` y `{id}-mini.jpg`.
- No existe ninguna Edge Function en el repositorio (no hay carpeta `supabase/functions`).
- Pruebas: `Tests/CuentaTests.swift` tiene un `ServicioCuentaFalso` con `borrarCuenta()` que pone `borrada = true` y emite `nil`.
- Documentación oficial a seguir:
  - Revocación de Apple: <https://developer.apple.com/documentation/sign_in_with_apple/revoke_tokens> (POST `https://appleid.apple.com/auth/revoke`, con `client_id`, `client_secret` (JWT ES256 firmado con la clave de Apple) y el token).
  - Intercambio del código: <https://developer.apple.com/documentation/sign_in_with_apple/generate_and_validate_tokens> (POST `https://appleid.apple.com/auth/token`, `grant_type=authorization_code`).
  - Edge Functions de Supabase: <https://supabase.com/docs/guides/functions>.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Comprobar tipos de la función (si tienes Deno) | `deno check supabase/functions/borrar-cuenta/index.ts` | exit 0 |
| Pruebas de la app en macOS con Xcode 26 | `xcodegen generate && xcodebuild test -project Rico.xcodeproj -scheme Rico -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Sin Mac: CI en tu rama | `git push -u origin <rama>` → `gh workflow run ci.yml --ref <rama>` → `gh run list --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId'` → `gh run watch <id> --exit-status` | exit 0 |
| Desplegar la función (lo hace el **operador**) | `npx supabase functions deploy borrar-cuenta --project-ref <ref-del-proyecto>` | «Deployed Function borrar-cuenta» |

Empujar tu rama está permitido (única forma de compilar sin Mac). Nunca a `main` ni PR sin permiso del operador. **No** despliegues nada en Supabase ni pidas claves: eso lo hace el operador.

## Scope

**In scope**:
- `supabase/functions/borrar-cuenta/index.ts` (crear)
- `Packages/RicoKit/Sources/Cuenta/ServicioCuenta.swift`
- `Packages/RicoKit/Sources/Cuenta/ServicioCuentaSupabase.swift`
- `Packages/RicoKit/Sources/Cuenta/EstadoCuenta.swift`
- `Packages/RicoKit/Sources/Cuenta/CuentaView.swift`
- `App/RicoApp.swift` (solo la comprobación de borrado local pendiente al arrancar)
- `Tests/CuentaTests.swift`
- `docs/decisiones/0001-servidor-propio-supabase.md` (apartado «Cómo aplicarlo»: despliegue y secretos de la función)

**Out of scope**:
- `supabase/migrations/20261020130000_esquema_inicial.sql`: la función `borrar_mi_cuenta()` se queda (la app deja de usarla).
- `AccesoView.swift`: no hace falta guardar el `authorizationCode` al entrar; se pide uno nuevo al borrar (ver paso 4).

## Git workflow

- Rama: `advisor/010-borrar-cuenta`. Commits en castellano, estilo del repo.

## Steps

### Step 1: Edge Function `borrar-cuenta`

Crea `supabase/functions/borrar-cuenta/index.ts` (Deno, TypeScript). Debe:

1. Aceptar solo `POST`. Leer la cabecera `Authorization: Bearer <jwt>`; con un cliente de Supabase creado con `SUPABASE_URL` y `SUPABASE_ANON_KEY` (variables que Supabase inyecta), obtener el usuario con `auth.getUser(jwt)`. Sin usuario → 401.
2. Con un cliente administrador (`SUPABASE_SERVICE_ROLE_KEY`, también inyectada), borrar todo lo de `fotos/{uid}/`: listar con `storage.from("fotos").list(uid, { limit: 1000, offset })` y `remove`, en un bucle con **un máximo de 50 vueltas** y saliendo si una vuelta no borra nada; si se alcanza el máximo, responder 500 sin borrar el usuario.
3. Si el cuerpo trae `apple_codigo` (string) y existen las variables `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_ID` y `APPLE_PRIVATE_KEY`:
   - generar el `client_secret` como JWT ES256 (cabecera `kid`; `iss` = team, `sub` = client id, `aud` = `https://appleid.apple.com`, caducidad de 5 minutos), por ejemplo con `npm:jose`;
   - intercambiar el código en `https://appleid.apple.com/auth/token` (`grant_type=authorization_code`);
   - revocar el `refresh_token` obtenido en `https://appleid.apple.com/auth/revoke` con `token_type_hint=refresh_token`.

   Un fallo aquí se registra (`console.error`, sin datos personales) pero **no** impide el borrado.
4. Borrar el usuario con `auth.admin.deleteUser(uid)` (las filas caen en cascada por las claves externas).
5. Responder `200 {"ok": true, "apple_revocado": <bool>}`.

No pongas ninguna clave en el código: todo sale de `Deno.env.get(...)`.

**Verify**: `deno check supabase/functions/borrar-cuenta/index.ts` → exit 0. Si no tienes Deno, `grep -n "Deno.env.get" supabase/functions/borrar-cuenta/index.ts` → al menos 4 líneas, y `grep -nE "eyJ|BEGIN PRIVATE KEY" supabase/functions/borrar-cuenta/index.ts` → sin resultados.

### Step 2: El cliente llama a la función

1. En `ServicioCuenta.swift`:
   - añade a `SesionUsuario` el campo `proveedor: String?` (`"email"`, `"apple"`…), con valor por defecto `nil` en el `init`;
   - cambia el protocolo a `func borrarCuenta(codigoApple: String?) async throws`.
2. En `ServicioCuentaSupabase`:
   - rellena `proveedor` en `sesion(_:)` desde `sesion.user.appMetadata["provider"]` (es un `AnyJSON`; usa su valor de texto);
   - `borrarCuenta(codigoApple:)`: sin sesión → `throw ErrorCuenta.otro("Sin sesión")`; si hay sesión, llama a la función con `cliente.functions.invoke("borrar-cuenta", options: FunctionInvokeOptions(body: ["apple_codigo": codigoApple]))` (omite la clave si es `nil`) y traduce los errores con `traducirErrores`. **No** cierres sesión aquí.
   - Borra el bucle `while true` y la llamada a `rpc("borrar_mi_cuenta")`.

**Verify**: CI compila (actualiza `ServicioCuentaFalso` en las pruebas para la firma nueva).

### Step 3: Orden seguro y borrado local garantizado

1. En `EstadoCuenta`, cambia `borrarCuenta` a `borrarCuenta(codigoApple: String?, borrarLocal: () throws -> Void) async throws`:
   1. `try await servicio.borrarCuenta(codigoApple:)` (servidor).
   2. Guarda en `UserDefaults.standard` la clave `RicoBorradoLocalPendiente` con el id del usuario.
   3. `try borrarLocal()` y, si va bien, quita esa clave.
   4. `try? await servicio.cerrarSesion()`.
2. En `CuentaView.borrarCuenta()`, pasa `{ try ContenedorRico.borrarTodo(en: contexto) }`.
3. En `App/RicoApp.swift`, al abrir el contenedor de un usuario (o en `.onAppear` de la raíz), si `RicoBorradoLocalPendiente` coincide con el usuario del contenedor, ejecuta `ContenedorRico.borrarTodo(en: contenedor.mainContext)` y quita la clave.

**Verify**: CI compila.

### Step 4: Código de Apple al borrar

En `CuentaView`, si `cuenta.sesion?.proveedor == "apple"`, antes de llamar a `borrarCuenta`, pide una autorización nueva con `ASAuthorizationAppleIDProvider().createRequest()` (sin ámbitos) usando un `ASAuthorizationController` y su delegado, y extrae `credencial.authorizationCode` como texto UTF-8. Si el usuario cancela, no borres nada. Si falla por otro motivo, sigue con el borrado pasando `codigoApple: nil`. Para otros proveedores, pasa `nil`.

**Verify**: CI compila.

### Step 5: Pruebas

En `Tests/CuentaTests.swift`, adapta el falso (`borrarCuenta(codigoApple:)` guarda el código recibido) y añade:

1. `borrarCuentaBorraLoLocalAntesDeCerrarSesion`: el cierre `borrarLocal` registra que se llamó cuando `estado.sesion` aún no era `nil`, y al final la sesión es `nil`.
2. `siFallaElBorradoLocalQuedaPendiente`: `borrarLocal` lanza un error → la clave `RicoBorradoLocalPendiente` existe en `UserDefaults` (usa una suite propia, `UserDefaults(suiteName:)`, y haz que `EstadoCuenta` la reciba por parámetro con `.standard` por defecto, para no tocar los valores reales).
3. `sinSesionBorrarCuentaFalla`: con `ServicioCuentaSupabase` no se puede probar sin red; prueba en el falso que `borrarCuenta` sin sesión lanza error (refleja el contrato).

**Verify**: CI en verde con las 3 pruebas nuevas.

### Step 6: Documentar el despliegue

En el ADR, apartado «Cómo aplicarlo», añade un punto: desplegar `borrar-cuenta` con la CLI y definir con `npx supabase secrets set` las variables `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_ID` (`es.siweb.rico`) y `APPLE_PRIVATE_KEY` (contenido de la clave `.p8` de *Sign in with Apple*). Solo nombres de variables, ningún valor.

**Verify**: `grep -c "borrar-cuenta" docs/decisiones/0001-servidor-propio-supabase.md` → `≥1`.

## Test plan

Las tres pruebas del paso 5. La función de servidor y la revocación de Apple solo se pueden probar con el proyecto real: deja en el informe final los pasos de prueba manual para el operador (crear usuario de prueba con foto, borrar la cuenta desde la app, comprobar en el panel que no queda la carpeta ni el usuario).

## Done criteria

- [ ] Existe `supabase/functions/borrar-cuenta/index.ts` sin claves en el código.
- [ ] `grep -n "while true" Packages/RicoKit/Sources/Cuenta/ServicioCuentaSupabase.swift` → sin resultados.
- [ ] `grep -n "borrar_mi_cuenta" Packages/RicoKit/Sources/` -r → sin resultados.
- [ ] CI en verde con las pruebas nuevas.
- [ ] ADR actualizado con el despliegue.
- [ ] Informe final con instrucciones de despliegue y prueba manual para el operador.
- [ ] Fila en `plans/README.md`: `IN PROGRESS (pendiente de desplegar)` hasta que el operador lo confirme.

## STOP conditions

- `FunctionInvokeOptions` o `functions.invoke` no existen con esa forma en la versión resuelta de `supabase-swift`.
- `appMetadata["provider"]` no da el proveedor (tipo distinto): informa del tipo real.
- Alguien te pide desplegar la función o te ofrece claves de Apple o de servicio: no lo hagas; es tarea del operador.

## Maintenance notes

- Sin la cuenta de Apple Developer no hay `APPLE_*`: la función borra igual y responde `apple_revocado: false`. Antes de publicar en la App Store hay que configurar esas variables.
- La función SQL `borrar_mi_cuenta()` queda sin uso; puede retirarse en una migración futura.
- La revisión debe comprobar que ningún log de la función incluye correos, ids de usuario completos ni tokens.
