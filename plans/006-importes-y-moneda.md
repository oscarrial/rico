# Plan 006: Editar un importe no lo corrompe ni cambia su moneda

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- Packages/RicoCore/Sources/RicoCore/Importe.swift Packages/RicoCore/Tests/RicoCoreTests/ImporteYEstrellasTests.swift Packages/RicoKit/Sources/Visitas/Formato.swift Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaModelo.swift Tests/FichaRapidaTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. Changes from
> `plans/004-guardado-robusto-de-visitas.md` in `FichaRapidaModelo.swift` and
> `Tests/FichaRapidaTests.swift` are expected.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/004-guardado-robusto-de-visitas.md
- **Category**: bug
- **Planned at**: commit `685cbe0`, 2026-10-20

## Why this matters

Al editar una visita, el campo de importe se rellena con el formato del idioma del usuario, incluidos los separadores de miles. En francés el separador de miles es un espacio estrecho (U+202F) y en suizo un apóstrofo; el lector de importes no los quita y `Decimal(string:)` se queda con lo que entiende del principio, así que «1 234,50» puede guardarse como **1,00**. Además, el campo siempre se interpreta en euros y el modelo sobrescribe la moneda de la visita: una visita en dólares pasa a euros al editarla.

## Current state

- `Packages/RicoCore/Sources/RicoCore/Importe.swift:13-38`, lector de texto:

```swift
13	    /// Lee lo que escribe el usuario: «48», «48,5», «48,50», «48.50», «1.234,56», «12 €».
14	    public init?(texto: String, divisa: String = "EUR") {
15	        var limpio = texto
16	            .replacingOccurrences(of: "€", with: "")
17	            .replacingOccurrences(of: " ", with: "")
18	            .replacingOccurrences(of: "\u{00A0}", with: "")
19	        guard !limpio.isEmpty else { return nil }
...
32	        guard let valor = Decimal(string: limpio, locale: Locale(identifier: "en_US_POSIX")),
33	              valor >= 0 else { return nil }
```

- `Packages/RicoKit/Sources/Visitas/Formato.swift:10-13`:

```swift
10	    /// «48,00» para rellenar el campo de importe.
11	    var textoEditable: String {
12	        decimal.formatted(.number.precision(.fractionLength(2)))
13	    }
```

- `Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaModelo.swift`: línea 98 `importeTexto = visita.importe?.textoEditable ?? ""`; línea 117 `public var importe: Importe? { Importe(texto: importeTexto) }` (siempre EUR); en `guardar`, `visita.importe = importe`.
- `Packages/RicoKit/Sources/Modelos/Modelos.swift:89-95`: el setter de `Visita.importe` copia la `divisa` del `Importe` a la visita.
- Pruebas actuales del lector: `Packages/RicoCore/Tests/RicoCoreTests/ImporteYEstrellasTests.swift`, suite `ImporteTests`, con `@Test(arguments:)` parametrizado (`leeLoQueEscribeElUsuario`, `rechazaTextoNoValido` con `["", "abc", "-5"]`). Sigue ese patrón.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Pruebas del núcleo (Linux, macOS o Windows con Swift 6.1) | `swift test --package-path Packages/RicoCore` | todas pasan |
| Pruebas de la app en macOS con Xcode 26 | `xcodegen generate && xcodebuild test -project Rico.xcodeproj -scheme Rico -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Sin Mac: CI en tu rama | `git push -u origin <rama>` → `gh workflow run ci.yml --ref <rama>` → `gh run list --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId'` → `gh run watch <id> --exit-status` | exit 0 |

Empujar tu rama está permitido (única forma de compilar sin Mac). Nunca a `main` ni PR sin permiso del operador.

## Scope

**In scope**:
- `Packages/RicoCore/Sources/RicoCore/Importe.swift`
- `Packages/RicoCore/Tests/RicoCoreTests/ImporteYEstrellasTests.swift`
- `Packages/RicoKit/Sources/Visitas/Formato.swift` (solo `textoEditable`)
- `Packages/RicoKit/Sources/Visitas/FichaRapida/FichaRapidaModelo.swift` (solo moneda)
- `Tests/FichaRapidaTests.swift`

**Out of scope**:
- `FormatoFecha` en `Formato.swift` (lo cubre `plans/008-fechas-relativas.md`).
- Totales y medias que mezclan monedas (los cubre `plans/007-logica-del-diario-y-restaurante.md`).
- Cambiar el símbolo `€` fijo de la vista `FichaRapidaView` (fuera de este plan).

## Git workflow

- Rama: `advisor/006-importes-y-moneda`. Commits en castellano, estilo del repo.

## Steps

### Step 1: Lector de importes estricto

En `Importe.init?(texto:divisa:)`:

1. Quita todos los espacios en blanco (`texto.filter { !$0.isWhitespace }`; cubre U+00A0 y U+202F), los apóstrofos `'` y `’` y los símbolos `€`, `$` y `£`.
2. Si queda algún carácter que no sea dígito, `,` o `.`, devuelve `nil` (así «12abc» y «-5» se rechazan).
3. Deja igual el resto: la regla del último separador con 1 o 2 cifras y el redondeo.

**Verify**: `swift test --package-path Packages/RicoCore` (o el trabajo Linux de la CI) → todas pasan, incluidas las existentes.

### Step 2: Pruebas del lector

En `ImporteTests`, añade casos a `leeLoQueEscribeElUsuario`: `("1\u{202F}234,50", 123450)`, `("1’234.50", 123450)`, `("1 234,50 €", 123450)`, `("$12.00", 1200)`. Añade a `rechazaTextoNoValido`: `"12abc"`, `"1,2,x"`.

**Verify**: `swift test --package-path Packages/RicoCore --filter ImporteTests` → todas pasan.

### Step 3: Campo de edición sin separador de miles

En `Formato.swift`, `textoEditable` → `decimal.formatted(.number.precision(.fractionLength(2)).grouping(.never))`.

**Verify**: CI compila.

### Step 4: Conservar la moneda de la visita

En `FichaRapidaModelo`:

1. Añade `private let divisa: String`. En `init(lugar:fecha:)` y `init(restaurante:fecha:)` asigna `"EUR"`; en `init(visita:)`, `visita.divisa`.
2. `importe` pasa a ser `Importe(texto: importeTexto, divisa: divisa)`.

**Verify**: CI compila.

### Step 5: Prueba de la moneda

En `Tests/FichaRapidaTests.swift`, prueba nueva `editarConservaLaMoneda`: guarda una visita, pon a mano `visita.divisa = "USD"` y `visita.importeCentimos = 2500` y guarda el contexto; abre `FichaRapidaModelo(visita:)`, cambia las estrellas, guarda → `visita.divisa == "USD"` y `visita.importeCentimos == 2500`.

**Verify**: CI en verde y `gh run view <id> --log | grep editarConservaLaMoneda` → ✔.

## Test plan

- 4 casos nuevos aceptados y 2 rechazados en `ImporteTests` (Linux).
- `editarConservaLaMoneda` en la app.

## Done criteria

- [ ] `swift test --package-path Packages/RicoCore` en verde (trabajo Linux de la CI).
- [ ] `grep -n "grouping(.never)" Packages/RicoKit/Sources/Visitas/Formato.swift` → una línea.
- [ ] CI completa en verde con `editarConservaLaMoneda`.
- [ ] `git status` sin cambios fuera del alcance.
- [ ] Fila actualizada en `plans/README.md`.

## STOP conditions

- Alguna prueba existente de `leeLoQueEscribeElUsuario` deja de pasar con el lector estricto.
- `.grouping(.never)` no compila con el estilo de número usado.

## Maintenance notes

- Si algún día la vista deja elegir moneda, el modelo ya guarda `divisa`; habrá que exponerla.
- El símbolo `€` de la ficha es fijo; con visitas en otra moneda, la vista mostrará un símbolo incorrecto aunque el dato sea correcto.
