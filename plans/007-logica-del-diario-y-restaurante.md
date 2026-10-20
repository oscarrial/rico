# Plan 007: La lógica del diario y de la ficha del restaurante está fuera de las vistas, probada y sin recálculos

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- Packages/RicoKit/Sources/Visitas/Diario/DiarioView.swift Packages/RicoKit/Sources/Visitas/Restaurante/FichaRestauranteView.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: LOW
- **Depends on**: plans/006-importes-y-moneda.md
- **Category**: tests
- **Planned at**: commit `685cbe0`, 2026-10-20

## Why this matters

El diario (búsqueda, agrupación por meses, «Este mes») y la ficha del restaurante (nota media, gasto medio por persona, «Lo que pediste») son las pantallas centrales de Rico. Toda su lógica son propiedades privadas calculadas dentro de las vistas: no se pueden probar, y se recalculan muchas veces en cada pintado. La ficha ordena la lista de visitas unas 7 veces por pintado y reconstruye la agrupación de platos una vez **por fila**. El diario copia el array del mes en cada visita (coste cuadrático) y lo recalcula todo en cada tecla de la búsqueda. Además, los totales suman céntimos de monedas distintas y muestran el resultado en la moneda de la primera visita, y la media se trunca en lugar de redondearse.

## Current state

- `Packages/RicoKit/Sources/Visitas/Diario/DiarioView.swift`:
  - Líneas 9-14: `@Query` de visitas con `estadoRaw == "valorada"`, orden por fecha descendente.
  - Líneas 33 y 53: `secciones` se evalúa dos veces por pintado.
  - Líneas 86-94 (`filtradas`): busca en nombre, ciudad, reseña y platos con `localizedStandardContains`.
  - Líneas 97-108 (`secciones`): agrupa por `FormatoFecha.mes(fecha)`; la línea 102 hace `Seccion(titulo: titulo, visitas: ultima.visitas + [visita])` (copia el array).
  - Líneas 110-122: `delMes` y `resumenMes`, que suma `importeCentimos` sin mirar la moneda y lo muestra como `Importe(centimos: total).textoMoneda` (EUR por defecto).
- `Packages/RicoKit/Sources/Visitas/Restaurante/FichaRestauranteView.swift`:
  - Líneas 98-102: `visitas` (filtra valoradas y ordena) es calculada y se lee en `fotoPortada`, `notaMedia`, `gastoMedioPorPersona`, `platos`, `cifras` y el `ForEach`.
  - Líneas 44-46: `ForEach(platos, id: \.nombre) { … if plato.nombre != platos.last?.nombre { Divider() } }` recalcula `platos` por fila.
  - Líneas 114-119 (`gastoMedioPorPersona`): suma `centimos` de todas las monedas, divide con `/` entera y etiqueta con la moneda de la primera.
  - Líneas 121-146: `ResumenPlato` y la agrupación por `nombre.lowercased()`, quedándose con la valoración más reciente.
- Tipos relevantes: `Visita.importePorPersona: Importe?`, `Visita.estrellas: Double?`, `Visita.platosOrdenados`, `Visita.fotosOrdenadas`, `Importe(centimos:divisa:)`. `FormatoFecha.mes(_:)` está en `Packages/RicoKit/Sources/Visitas/Formato.swift`.
- Patrón de prueba: `Tests/FichaRapidaTests.swift` (`@MainActor @Suite`, contenedor `ContenedorRico.crear(enMemoria: true)`, visitas creadas con `FichaRapidaModelo(lugar:)` + `guardar(en:)`). Las pruebas importan `Visitas` sin `@testable`, así que los tipos nuevos deben ser `public`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Pruebas de la app en macOS con Xcode 26 | `xcodegen generate && xcodebuild test -project Rico.xcodeproj -scheme Rico -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Sin Mac: CI en tu rama | `git push -u origin <rama>` → `gh workflow run ci.yml --ref <rama>` → `gh run list --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId'` → `gh run watch <id> --exit-status` | exit 0 |
| Ver pruebas | `gh run view <id> --log \| grep -E "✔\|✖"` | nuevas con ✔ |

Empujar tu rama está permitido (única forma de compilar sin Mac). Nunca a `main` ni PR sin permiso del operador.

## Scope

**In scope**:
- `Packages/RicoKit/Sources/Visitas/Resumenes.swift` (crear)
- `Packages/RicoKit/Sources/Visitas/Diario/DiarioView.swift`
- `Packages/RicoKit/Sources/Visitas/Restaurante/FichaRestauranteView.swift`
- `Tests/ResumenesTests.swift` (crear)

**Out of scope**:
- El aspecto de las pantallas: no cambies colores, textos visibles ni maquetación.
- `FormatoFecha.corta` (lo cubre `plans/008-fechas-relativas.md`).
- Decodificación de imágenes (`plans/013-fotos-fuera-del-hilo-principal.md`).

## Git workflow

- Rama: `advisor/007-logica-del-diario`. Commits en castellano, estilo del repo.

## Steps

### Step 1: Tipos puros en `Resumenes.swift`

Crea `Packages/RicoKit/Sources/Visitas/Resumenes.swift` con, como mínimo:

```swift
public struct PlatoResumido: Equatable, Sendable {
    public let nombre: String
    public let veces: Int
    public let ultimaValoracion: ValoracionPlato?
}

/// Cifras de un restaurante, calculadas una vez por pintado.
public struct ResumenRestaurante {
    public let visitas: [Visita]            // valoradas, de la más reciente a la más antigua
    public let notaMedia: Double?
    public let gastoMedioPorPersona: Importe?
    public let platos: [PlatoResumido]      // más pedidos primero; empate: nombre ascendente
    public let fotoPortada: Data?
    public init(restaurante: Restaurante)
}

public enum AgrupadorDiario {
    public struct Seccion: Identifiable { public let titulo: String; public let visitas: [Visita]; public var id: String { titulo } }
    public static func filtrar(_ visitas: [Visita], busqueda: String) -> [Visita]
    public static func secciones(_ visitas: [Visita], titulo: (Date) -> String = FormatoFecha.mes) -> [Seccion]
    /// Visitas y gasto del mes de `ahora`, en la moneda principal.
    public static func resumenMes(_ visitas: [Visita], ahora: Date = .now, calendario: Calendar = .current) -> (visitas: Int, gasto: Importe)
}
```

Reglas:

- `filtrar`: misma lógica que hoy (`DiarioView.swift:86-94`).
- `secciones`: un solo recorrido; acumula en un array mutable de la sección actual y la añade al cambiar de título (sin `+ [visita]`).
- **Moneda principal**: la `divisa` más frecuente entre las visitas con importe (empate: `"EUR"` si está entre las empatadas; si no, orden alfabético). `gastoMedioPorPersona` y `resumenMes.gasto` solo cuentan visitas en esa moneda.
- Media de gasto: `(suma / n).rounded()` en céntimos, no división entera.
- Platos: misma agrupación que hoy (clave `nombre.lowercased()`, valoración de la visita más reciente).

Si `FormatoFecha` es `internal`, puedes usarlo como valor por defecto solo si la función también es pública con un parámetro por defecto accesible; si el compilador no lo permite, haz `FormatoFecha.mes` público (no cambies `corta`).

**Verify**: CI compila.

### Step 2: Usar los tipos en las vistas

- `DiarioView`: en `body`, calcula una vez `let secciones = AgrupadorDiario.secciones(AgrupadorDiario.filtrar(visitas, busqueda: busqueda))` y úsala en el `ForEach` y en el `overlay`. `resumenMes` usa `AgrupadorDiario.resumenMes(visitas)`. Borra `filtradas`, `secciones`, `delMes` y `Seccion` privados.
- `FichaRestauranteView`: en `body`, `let resumen = ResumenRestaurante(restaurante: restaurante)`, y pasa `resumen` a `cifras`, `filaPlato`, etc. (conviértelos en funciones que reciben `resumen`). Para los separadores usa `ForEach(Array(resumen.platos.enumerated()), id: \.element.nombre)` y pinta `Divider()` si `offset < resumen.platos.count - 1`. Borra las propiedades calculadas privadas sustituidas.

**Verify**: CI compila y todas las pruebas existentes pasan.

### Step 3: Pruebas

Crea `Tests/ResumenesTests.swift` (`@MainActor @Suite("Resúmenes")`), con visitas creadas como en `FichaRapidaTests`:

1. `agrupaPorMesManteniendoElOrden`: tres visitas en dos meses → dos secciones, en orden y con 2 y 1 visitas.
2. `buscaEnPlatosSinDistinguirMayusculas`: un plato «Pulpo á feira»; `filtrar(…, busqueda: "pulpo")` lo encuentra; `"zzz"` no.
3. `notaYGastoMedio`: dos visitas de 4 y 5 estrellas y 24,00 € y 25,00 € por persona → `notaMedia == 4.5`, `gastoMedioPorPersona?.centimos == 2450`.
4. `gastoMedioIgnoraOtraMoneda`: añade una visita en USD (pon `divisa` e `importeCentimos` a mano) → la media sigue en EUR y no cambia.
5. `platosAgrupadosConLaUltimaValoracion`: «Pulpo» dos veces (`.bien` la antigua, `.encanto` la reciente) y «pulpo» en minúscula → `veces == 3`, `ultimaValoracion == .encanto`.
6. `resumenDelMesSoloCuentaEsteMes`: una visita de este mes y otra del mes pasado (usa `ahora:` fijo) → `visitas == 1`.

**Verify**: CI en verde; `gh run view <id> --log | grep -cE "✔ .*(agrupaPorMes|buscaEnPlatos|notaYGastoMedio|gastoMedioIgnora|platosAgrupados|resumenDelMes)"` → `6`.

## Test plan

Las seis pruebas del paso 3. Patrón: `Tests/FichaRapidaTests.swift`.

## Done criteria

- [ ] `grep -n "ultima.visitas + \[visita\]" -r Packages/` → sin resultados.
- [ ] `grep -n "private var visitas: \[Visita\]" Packages/RicoKit/Sources/Visitas/Restaurante/FichaRestauranteView.swift` → sin resultados.
- [ ] CI en verde con las 6 pruebas nuevas.
- [ ] `git status` sin cambios fuera del alcance.
- [ ] Fila actualizada en `plans/README.md`.

## STOP conditions

- Pasar `Visita` (modelo de SwiftData) a tipos públicos rompe la compilación por aislamiento de actores; en ese caso, informa del error en lugar de añadir `@unchecked Sendable`.
- Las pruebas de búsqueda dependen del idioma del simulador y fallan de forma intermitente.

## Maintenance notes

- La futura pestaña «Resumen» y el mapa (pines por nota media) deben reutilizar `ResumenRestaurante` y `AgrupadorDiario.resumenMes`, no volver a calcular en la vista.
- Con miles de visitas, el siguiente paso sería mover la búsqueda a un `#Predicate` o paginar la `@Query`; no forma parte de este plan.
