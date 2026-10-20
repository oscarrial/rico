# Plan 008: Las fechas «Hoy / Ayer / día de la semana» son correctas y se pueden probar

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- Packages/RicoKit/Sources/Visitas/Formato.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition. Expected changes from plans 006
> (`textoEditable`) and 007 (`FormatoFecha.mes` may be public) are fine.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/006-importes-y-moneda.md, plans/007-logica-del-diario-y-restaurante.md
- **Category**: bug
- **Planned at**: commit `685cbe0`, 2026-10-20

## Why this matters

`DESIGN.md` fija el formato de fechas de las tarjetas: «Hoy», «Ayer», el día de la semana dentro de los últimos 7 días y después «11 oct». La función actual cuenta periodos de 24 horas en lugar de días de calendario: una visita del lunes pasado a las 21:00 vista este lunes a las 10:00 sale como «lunes», igual que si fuera de hoy. Además, «Hoy» y «Ayer» usan el reloj real aunque la función recibe `ahora`, así que no se puede probar.

## Current state

`Packages/RicoKit/Sources/Visitas/Formato.swift:16-28`:

```swift
16	enum FormatoFecha {
17	    /// «Hoy», «Ayer», «jueves» o «11 oct».
18	    static func corta(_ fecha: Date, ahora: Date = .now, calendario: Calendar = .current) -> String {
19	        if calendario.isDateInToday(fecha) { return String(localized: "Hoy", bundle: .module) }
20	        if calendario.isDateInYesterday(fecha) { return String(localized: "Ayer", bundle: .module) }
21	        if let dias = calendario.dateComponents([.day], from: fecha, to: ahora).day, dias < 7, dias >= 0 {
22	            return fecha.formatted(.dateTime.weekday(.wide))
23	        }
24	        if calendario.isDate(fecha, equalTo: ahora, toGranularity: .year) {
25	            return fecha.formatted(.dateTime.day().month(.abbreviated))
26	        }
27	        return fecha.formatted(.dateTime.day().month(.abbreviated).year())
28	    }
```

Se usa en `DiarioView.swift` (tarjeta) y `FichaRestauranteView.swift` (lista de visitas). `DESIGN.md` §9: «Fechas: "Hoy", "Ayer", día de la semana dentro de los últimos 7 días y después "11 oct".» Los textos visibles se localizan con `String(localized:bundle: .module)`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Pruebas de la app en macOS con Xcode 26 | `xcodegen generate && xcodebuild test -project Rico.xcodeproj -scheme Rico -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO` | `** TEST SUCCEEDED **` |
| Sin Mac: CI en tu rama | `git push -u origin <rama>` → `gh workflow run ci.yml --ref <rama>` → `gh run list --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId'` → `gh run watch <id> --exit-status` | exit 0 |

Empujar tu rama está permitido (única forma de compilar sin Mac). Nunca a `main` ni PR sin permiso del operador.

## Scope

**In scope**:
- `Packages/RicoKit/Sources/Visitas/Formato.swift` (solo `FormatoFecha.corta`)
- `Tests/FormatoFechaTests.swift` (crear)

**Out of scope**: `Importe` y `textoEditable`; `FormatoFecha.mes`; las vistas que llaman a `corta` (su firma con valores por defecto no cambia para ellas).

## Git workflow

- Rama: `advisor/008-fechas-relativas`. Commits en castellano, estilo del repo.

## Steps

### Step 1: Comparar días de calendario

1. Haz `FormatoFecha` y `corta` `public` (para las pruebas).
2. Añade el parámetro `locale: Locale = .current`.
3. Calcula `let dias = calendario.dateComponents([.day], from: calendario.startOfDay(for: fecha), to: calendario.startOfDay(for: ahora)).day ?? 0`.
4. `dias == 0` → «Hoy»; `dias == 1` → «Ayer»; `2...6` → día de la semana; si no, «día mes» (con año si no es el año de `ahora`). Fechas futuras (`dias < 0`) → «día mes».
5. Aplica `locale` a los formatos (`.dateTime.weekday(.wide).locale(locale)`, etc.) y fija el calendario: `var estilo = Date.FormatStyle(date: …, locale: locale, calendar: calendario, timeZone: calendario.timeZone)` o el equivalente con `.locale(locale)`; lo importante es que el resultado no dependa del dispositivo.

**Verify**: CI compila.

### Step 2: Pruebas

Crea `Tests/FormatoFechaTests.swift` con un calendario gregoriano en `Europe/Madrid`, `Locale(identifier: "es_ES")` y `ahora` fijo (por ejemplo el lunes 19 de octubre de 2026 a las 10:00). Casos:

| fecha | esperado |
|---|---|
| mismo día a las 08:00 | «Hoy» |
| domingo 18 a las 23:30 | «Ayer» |
| miércoles 14 a las 12:00 | «miércoles» |
| lunes 12 a las 21:00 | «12 oct» |
| 3 de marzo de 2025 | «3 mar 2025» (comprueba solo que contiene «2025») |

**Verify**: CI en verde; `gh run view <id> --log | grep -c "FormatoFecha"` muestra la suite con ✔.

## Test plan

Las cinco comprobaciones del paso 2. Si el texto exacto de «12 oct» varía según la versión de Foundation (punto final, mayúsculas), comprueba que contiene «12» y que no es un nombre de día de la semana.

## Done criteria

- [ ] `grep -n "isDateInToday\|isDateInYesterday" Packages/RicoKit/Sources/Visitas/Formato.swift` → sin resultados.
- [ ] CI en verde con `FormatoFechaTests`.
- [ ] `git status` sin cambios fuera del alcance.
- [ ] Fila actualizada en `plans/README.md`.

## STOP conditions

- Las cadenas formateadas en el simulador de la CI no coinciden con el idioma pedido (la CI ignora `locale`): informa del texto obtenido.

## Maintenance notes

- Cualquier fecha relativa nueva debe pasar por `FormatoFecha` para mantener la regla de `DESIGN.md`.
