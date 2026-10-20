# Plan 002: La app abre el diario sin conexión aunque la sesión haya caducado

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- Packages/RicoKit/Sources/Cuenta/ServicioCuentaSupabase.swift Packages/RicoKit/Sources/Cuenta/EstadoCuenta.swift Tests/CuentaTests.swift`
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

Rico es «local primero»: el diario vive en el iPhone y debe abrirse siempre. Pero el token de sesión de Supabase dura una hora. Con la configuración actual, al arrancar sin conexión (o con mala cobertura, típico dentro de un restaurante) más de una hora después del último uso, la librería intenta renovar la sesión antes de avisar a la app; si la renovación falla, avisa «sin sesión». Resultado: la pantalla de arranque se queda esperando hasta que vence la red y luego aparece la pantalla de inicio de sesión, aunque todos los datos estén en el teléfono.

Esto está comprobado en el código fuente de `supabase-swift` 2.55.4 (`Sources/Auth/AuthClient.swift`, función `emitInitialSession`): con `emitLocalSessionAsInitialSession == false` (valor por defecto) hace `let session = try? await session` (que renueva si ha caducado) y emite `nil` si falla. Con `true`, emite la sesión guardada al instante y la renueva en segundo plano.

## Current state

- `Packages/RicoKit/Sources/Cuenta/ServicioCuentaSupabase.swift:26-30` — el cliente se crea sin opciones:

```swift
26	public enum ClienteRico {
27	    public static func crear(_ configuracion: ConfiguracionSupabase) -> SupabaseClient {
28	        SupabaseClient(supabaseURL: configuracion.url, supabaseKey: configuracion.clavePublica)
29	    }
30	}
```

- `Packages/RicoKit/Sources/Cuenta/EstadoCuenta.swift:26-38` — la fase se queda en `.cargando` hasta el primer valor del flujo de sesión:

```swift
26	    public init(servicio: (any ServicioCuenta)?) {
27	        self.servicio = servicio
28	        guard let servicio else {
29	            fase = .soloLocal
30	            return
31	        }
32	        fase = .cargando
33	        escucha = Task { [weak self] in
34	            for await sesion in servicio.cambiosDeSesion() {
35	                self?.fase = sesion.map(Fase.conSesion) ?? .sinSesion
36	            }
37	        }
38	    }
```

- `App/RicoApp.swift:42` — mientras `cuenta.fase == .cargando` se muestra la pantalla de arranque; `.sinSesion` muestra `AccesoView`.
- API de la librería (v2.55.4, `Sources/Supabase/Types.swift`): `SupabaseClientOptions(auth: SupabaseClientOptions.AuthOptions(flowType:emitLocalSessionAsInitialSession:...))` y `SupabaseClient(supabaseURL:supabaseKey:options:)`.
- Pruebas de cuentas: `Tests/CuentaTests.swift`, con un `ServicioCuentaFalso` (líneas 9-86) que emite la sesión por un `AsyncStream`, y un ayudante `esperar(hasta:segundos:)` (líneas 88-97). Sigue ese patrón.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Pruebas de la app en macOS con Xcode 26 | `xcodegen generate && xcodebuild test -project Rico.xcodeproj -scheme Rico -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Sin Mac: CI en tu rama | `git push -u origin <rama>` → `gh workflow run ci.yml --ref <rama>` → `gh run list --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId'` → `gh run watch <id> --exit-status` | exit 0 |
| Ver qué pruebas pasaron | `gh run view <id> --log \| grep -E "✔\|✖"` | las nuevas con ✔ |

Empujar tu rama de trabajo está permitido (es la única forma de compilar sin Mac). Nunca empujes a `main` ni abras PR salvo que el operador lo pida.

## Scope

**In scope**:
- `Packages/RicoKit/Sources/Cuenta/ServicioCuentaSupabase.swift` (solo `ClienteRico.crear`)
- `Packages/RicoKit/Sources/Cuenta/EstadoCuenta.swift`
- `Tests/CuentaTests.swift`

**Out of scope**:
- `App/RicoApp.swift` — la pantalla de arranque ya se retira sola cuando la fase deja de ser `.cargando`.
- Cambiar el tipo de flujo de autenticación: debe quedar en `.pkce`, que ya es el valor por defecto; solo se hace explícito.

## Git workflow

- Rama: `advisor/002-arranque-sin-conexion`.
- Commits con frase en castellano (estilo del repo: «Supabase: migración aplicada y seguridad comprobada»).

## Steps

### Step 1: Emitir la sesión guardada al arrancar

En `ClienteRico.crear`:

```swift
SupabaseClient(
    supabaseURL: configuracion.url,
    supabaseKey: configuracion.clavePublica,
    options: SupabaseClientOptions(
        auth: .init(
            flowType: .pkce,
            // Local primero: abre el diario con la sesión guardada aunque haya caducado;
            // la librería la renueva en segundo plano cuando hay red.
            emitLocalSessionAsInitialSession: true
        )
    )
)
```

**Verify**: la CI compila (`gh run watch <id> --exit-status` → exit 0).

### Step 2: Límite de espera en `.cargando`

Añade a `EstadoCuenta.init` un parámetro `esperaMaxima: Duration = .seconds(3)`. Tras crear `escucha`, lanza otra tarea que, si al cabo de `esperaMaxima` la fase sigue en `.cargando`, la fije con lo que haya guardado:

```swift
Task { [weak self] in
    try? await Task.sleep(for: esperaMaxima)
    guard let self, self.fase == .cargando else { return }
    self.fase = servicio.sesionActual.map(Fase.conSesion) ?? .sinSesion
}
```

(`servicio.sesionActual` lee la sesión del llavero sin red.)

**Verify**: la CI compila.

### Step 3: Pruebas

En `Tests/CuentaTests.swift`:

1. Añade al `ServicioCuentaFalso` una opción para no emitir nunca (por ejemplo un `init(sesionInicial:emitir:)` donde `emitir: false` no hace `continuacion.yield`).
2. Prueba nueva `sinRespuestaDelServidorUsaLaSesionGuardada`: servicio con `sesionInicial` = una `SesionUsuario` y `emitir: false`; `EstadoCuenta(servicio:esperaMaxima: .milliseconds(50))`; espera con `esperar(hasta:)` a que `fase == .conSesion(sesion)`.
3. Prueba nueva `sinRespuestaNiSesionGuardadaPideAcceso`: igual sin sesión → `fase == .sinSesion`.

**Verify**: CI en verde y `gh run view <id> --log | grep -E "sinRespuesta"` → dos líneas con ✔.

## Test plan

- Las dos pruebas del paso 3.
- Patrón: `recuperaLaSesionGuardada` en `Tests/CuentaTests.swift`.
- La opción de `emitLocalSessionAsInitialSession` no se puede probar sin servidor: queda cubierta por la revisión del código.

## Done criteria

- [ ] `grep -n "emitLocalSessionAsInitialSession: true" Packages/RicoKit/Sources/Cuenta/ServicioCuentaSupabase.swift` → una línea.
- [ ] `grep -n "flowType: .pkce" Packages/RicoKit/Sources/Cuenta/ServicioCuentaSupabase.swift` → una línea.
- [ ] CI en verde; las dos pruebas nuevas pasan y las anteriores siguen pasando.
- [ ] `git status` sin cambios fuera del alcance.
- [ ] Fila actualizada en `plans/README.md`.

## STOP conditions

- `SupabaseClientOptions.AuthOptions` no tiene el parámetro `emitLocalSessionAsInitialSession` en la versión resuelta (error de compilación): informa de la versión de `supabase-swift` que aparece en el log.
- Alguna prueba existente de `CuentaTests` empieza a fallar por el nuevo temporizador.

## Maintenance notes

- Con esta opción, la app puede mostrar el diario con un token caducado. Cualquier llamada al servidor (la futura sincronización) debe tolerar un primer fallo 401 mientras la librería renueva, y no debe borrar datos locales por ello.
- Si la renovación falla porque el refresco ya no es válido (sesión revocada), la librería emite `signedOut` y la app vuelve a `AccesoView`: es el comportamiento deseado.
