# Plan 003: Cada cuenta tiene su propia base local en el iPhone

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- Packages/RicoKit/Sources/Modelos/ContenedorRico.swift App/RicoApp.swift Tests/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. Exception: changes from
> `plans/002-arranque-sin-conexion.md` in `Tests/CuentaTests.swift` are expected.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/002-arranque-sin-conexion.md
- **Category**: security
- **Planned at**: commit `685cbe0`, 2026-10-20

## Why this matters

Hoy hay **una sola base de datos local** (SwiftData) y ningún modelo guarda de quién es. Si A cierra sesión y B entra en el mismo iPhone, B ve el diario completo de A: visitas, fotos, importes y notas. Cuando exista la sincronización con Supabase, los datos de A se subirían además a la cuenta de B. La seguridad del servidor (RLS) no puede evitarlo porque el cruce ocurre en el teléfono.

La solución elegida es **un archivo de base de datos por usuario**: al cambiar de cuenta, la app abre el archivo de esa cuenta. Así nadie ve lo de otro y nadie pierde nada al cerrar sesión (los datos de A siguen en su archivo, invisibles para B). Borrar en lugar de separar perdería para siempre los datos de A, porque aún no existe sincronización.

La app **todavía no se ha distribuido a nadie** (ni TestFlight), así que no hay que migrar datos existentes.

## Current state

- `Packages/RicoKit/Sources/Modelos/ContenedorRico.swift:25-36` — un único almacén por App Group:

```swift
25	    public static func crear(enMemoria: Bool = false, usarGrupo: Bool = true) throws -> ModelContainer {
26	        let configuracion: ModelConfiguration
27	        if enMemoria {
28	            configuracion = ModelConfiguration(schema: esquema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
29	        } else {
30	            let grupo: ModelConfiguration.GroupContainer = usarGrupo
31	                ? identificadorGrupo.map { .identifier($0) } ?? .none
32	                : .none
33	            configuracion = ModelConfiguration(schema: esquema, groupContainer: grupo, cloudKitDatabase: .none)
34	        }
35	        return try ModelContainer(for: esquema, configurations: configuracion)
36	    }
```

- `App/RicoApp.swift` — el contenedor se crea una vez en `init` (líneas 15-26, `let contenedor: ModelContainer`) y se inyecta con `.modelContainer(contenedor)` (línea 56). La raíz muestra `DiarioView` para `.conSesion` y `.soloLocal` (líneas 61-66), `AccesoView` para `.sinSesion` y un fondo para `.cargando`.
- `Packages/RicoKit/Sources/Cuenta/EstadoCuenta.swift` — `fase: Fase` con casos `.cargando`, `.sinSesion`, `.conSesion(SesionUsuario)`, `.soloLocal` (Supabase sin configurar). `SesionUsuario` tiene `id: UUID` y `correo: String?` (`ServicioCuenta.swift:4-12`).
- `ContenedorRico.identificadorGrupo` lee `RicoAppGroup` del Info.plist. En la CI la app se compila sin firma y el App Group no existe: por eso `RicoApp` reintenta con `usarGrupo: false`.
- Pruebas: `Tests/FichaRapidaTests.swift` (patrón de prueba con `ContenedorRico.crear(enMemoria: true)`, `@MainActor @Suite`, Swift Testing). Los tipos de prueba se importan con `import Modelos`, `import Visitas`, `import RicoCore` (sin `@testable`).
- Regla del repo (`CLAUDE.md`): «Local primero: la app lee y escribe siempre en SwiftData; la sincronización con Supabase va aparte. Los id son UUID generados en la app.»

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Pruebas de la app en macOS con Xcode 26 | `xcodegen generate && xcodebuild test -project Rico.xcodeproj -scheme Rico -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Sin Mac: CI en tu rama | `git push -u origin <rama>` → `gh workflow run ci.yml --ref <rama>` → `gh run list --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId'` → `gh run watch <id> --exit-status` | exit 0 |
| Ver pruebas | `gh run view <id> --log \| grep -E "✔\|✖"` | nuevas con ✔ |

Empujar tu rama está permitido (única forma de compilar sin Mac). Nunca a `main` ni PR sin permiso del operador.

## Scope

**In scope**:
- `Packages/RicoKit/Sources/Modelos/ContenedorRico.swift`
- `App/RicoApp.swift`
- `Tests/AlmacenPorUsuarioTests.swift` (crear)

**Out of scope**:
- Los modelos (`Modelos.swift`): no se añade campo de usuario; la separación es por archivo.
- `CuentaView.swift` y el borrado de cuenta (lo cubre `plans/010-borrar-cuenta-robusto.md`).
- Cualquier código de sincronización (no existe todavía).

## Git workflow

- Rama: `advisor/003-datos-por-usuario`. Commits en castellano, estilo del repo.

## Steps

### Step 1: Ubicación del almacén según el usuario

En `ContenedorRico`, añade:

```swift
/// Nombre del archivo de la base local: uno por cuenta; «Rico» para el modo sin cuenta.
public static func nombreAlmacen(usuario: UUID?) -> String {
    guard let usuario else { return "Rico" }
    return "Rico-\(usuario.uuidString.lowercased())"
}

/// Carpeta de las bases locales: el App Group si existe; si no, Application Support de la app.
public static func carpetaAlmacenes(usarGrupo: Bool = true) -> URL {
    if usarGrupo, let grupo = identificadorGrupo,
       let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: grupo) {
        return url.appending(path: "Library/Application Support", directoryHint: .isDirectory)
    }
    return URL.applicationSupportDirectory
}
```

Cambia `crear` para aceptar `usuario: UUID?` y una `carpeta: URL?` opcional (para pruebas):

```swift
public static func crear(enMemoria: Bool = false, usuario: UUID? = nil, usarGrupo: Bool = true, carpeta: URL? = nil) throws -> ModelContainer {
    if enMemoria { /* igual que ahora */ }
    let base = carpeta ?? carpetaAlmacenes(usarGrupo: usarGrupo)
    try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    let url = base.appending(path: "\(nombreAlmacen(usuario: usuario)).store")
    let configuracion = ModelConfiguration(schema: esquema, url: url, cloudKitDatabase: .none)
    return try ModelContainer(for: esquema, configurations: configuracion)
}
```

Mantén el comportamiento de `enMemoria: true` intacto (lo usan las pruebas actuales).

**Verify**: CI compila y las pruebas existentes pasan.

### Step 2: Cambiar de base al cambiar de cuenta

En `App/RicoApp.swift`:

1. Sustituye `let contenedor: ModelContainer` por `@State private var contenedor: ModelContainer` y `@State private var usuarioDelContenedor: UUID?`.
2. Extrae la creación con su reintento sin App Group a un método `static func abrirContenedor(usuario: UUID?) -> ModelContainer` (mismo `do/catch` y `fatalError` que hoy, pasando `usuario:`).
3. En `init`, crea el contenedor de arranque con `usuario: nil` solo si la fase inicial es `.soloLocal`; en otro caso créalo igualmente con `nil` (es un contenedor provisional que no se muestra: durante `.cargando` y `.sinSesion` no hay vistas de datos).
4. Añade en la escena:

```swift
.onChange(of: usuarioActivo, initial: true) { _, nuevo in
    guard nuevo != usuarioDelContenedor else { return }
    contenedor = Self.abrirContenedor(usuario: nuevo)
    usuarioDelContenedor = nuevo
}
```

donde `usuarioActivo: UUID?` es una propiedad calculada: `cuenta.sesion?.id` si `.conSesion`, `nil` si `.soloLocal`, y `usuarioDelContenedor` (sin cambio) en `.cargando` y `.sinSesion`.

5. Añade `.id(usuarioDelContenedor)` a `raiz` para que las vistas de datos se recreen con la base nueva.

**Verify**: CI compila; pruebas existentes en verde.

### Step 3: Pruebas de aislamiento

Crea `Tests/AlmacenPorUsuarioTests.swift` (`@MainActor @Suite("Almacén por usuario")`), con una carpeta temporal única por prueba (`FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)`) que se borra al final:

1. `nombresDistintosPorUsuario`: `nombreAlmacen(usuario: a) != nombreAlmacen(usuario: b)`, `nombreAlmacen(usuario: nil) == "Rico"`, y el nombre de un usuario es estable entre llamadas.
2. `otroUsuarioNoVeLosDatos`: crea contenedor para A en la carpeta temporal, guarda una visita con `FichaRapidaModelo` (como en `FichaRapidaTests.guardarCreaRestauranteYVisitaValorada`); crea contenedor para B en la misma carpeta → `fetchCount(FetchDescriptor<Visita>()) == 0`.
3. `elMismoUsuarioRecuperaSusDatos`: tras lo anterior, abre de nuevo el de A → `fetchCount == 1`.

**Verify**: CI en verde; `gh run view <id> --log | grep -E "otroUsuarioNoVeLosDatos|elMismoUsuarioRecuperaSusDatos|nombresDistintosPorUsuario"` → tres ✔.

## Test plan

Las tres pruebas del paso 3. Patrón estructural: `Tests/FichaRapidaTests.swift`.

## Done criteria

- [ ] `grep -n "nombreAlmacen" Packages/RicoKit/Sources/Modelos/ContenedorRico.swift` → presente.
- [ ] `grep -n "@State private var contenedor" App/RicoApp.swift` → presente.
- [ ] CI en verde con las 3 pruebas nuevas y todas las anteriores.
- [ ] `git status` sin cambios fuera del alcance.
- [ ] Fila actualizada en `plans/README.md`.

## STOP conditions

- El operador indica que la app ya se ha instalado en dispositivos con datos reales: entonces hace falta migrar el almacén antiguo (`default.store`) y este plan no lo cubre.
- `ModelConfiguration(schema:url:cloudKitDatabase:)` no existe con esa firma en el SDK de la CI.
- Cambiar el contenedor en caliente provoca errores de SwiftData en las pruebas (por ejemplo, objetos de un contexto usados en otro).

## Maintenance notes

- La sincronización futura debe usar el contenedor del usuario activo y nunca el de modo sin cuenta (`Rico.store`).
- Al cerrar sesión los datos de esa cuenta siguen en el iPhone (en su archivo). Si se quiere borrarlos tras sincronizar, será una decisión de producto aparte.
- Datos creados en modo sin cuenta (`Rico.store`) no se pasan a la cuenta al iniciar sesión. Si eso se quiere, es un plan nuevo.
- Revisor: comprobar que ninguna vista guarda referencias a modelos de un contenedor anterior tras el cambio (`.id(...)` en la raíz lo evita).
