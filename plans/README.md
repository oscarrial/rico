# Planes de mejora

Generados con la skill `improve` el 20 de octubre de 2026, sobre el commit `685cbe0`. Ejecuta los planes en este orden salvo que las dependencias digan otra cosa. Cada ejecutor: lee el plan entero antes de empezar, respeta sus condiciones de STOP y actualiza su fila al terminar.

Todo se compila y prueba en GitHub Actions (no hay Xcode local). Cada plan explica cómo lanzar la CI en su rama.

## Orden de ejecución y estado

| Plan | Título | Prioridad | Esfuerzo | Depende de | Estado |
|------|--------|-----------|----------|------------|--------|
| [001](001-ci-reproducible.md) | La CI compila siempre con las mismas versiones, más rápido y con permisos mínimos | P1 | S | — | DONE (fusionado en `main`) |
| [002](002-arranque-sin-conexion.md) | La app abre el diario sin conexión aunque la sesión haya caducado | P1 | S | — | DONE (fusionado en `main`) |
| [003](003-datos-por-usuario.md) | Cada cuenta tiene su propia base local en el iPhone | P1 | M | 002 | DONE (fusionado en `main`; probar el cambio de cuenta a mano en TestFlight) |
| [004](004-guardado-robusto-de-visitas.md) | Guardar una visita no deja cambios a medias, conserva los platos y no pierde fotos | P1 | S | — | DONE (fusionado en `main`) |
| [005](005-tiempos-del-servidor.md) | El servidor fija `actualizado_en` también al crear filas | P2 | S | — | IN PROGRESS (fusionado en `main` y aplicado en Supabase el 20/10/2026) |
| [006](006-importes-y-moneda.md) | Editar un importe no lo corrompe ni cambia su moneda | P2 | S | 004 | DONE (fusionado en `main`) |
| [007](007-logica-del-diario-y-restaurante.md) | La lógica del diario y del restaurante está fuera de las vistas, probada y sin recálculos | P2 | M | 006 | IN PROGRESS |
| [008](008-fechas-relativas.md) | Las fechas «Hoy / Ayer / día de la semana» son correctas y se pueden probar | P3 | S | 006, 007 | TODO |
| [009](009-recuperar-contrasena.md) | Recuperar la contraseña muestra la hoja, confirma el cambio y no deja errores pegados | P2 | S | 003 | DONE (fusionado en `main`) |
| [010](010-borrar-cuenta-robusto.md) | Borrar la cuenta lo borra todo en el servidor, limpia el iPhone y revoca Apple | P2 | L | 003, 009 | IN PROGRESS |
| [011](011-reautenticar-al-cambiar-contrasena.md) | Cambiar la contraseña desde «Tu cuenta» pide la actual | P2 | S | 010 | TODO |
| [012](012-fotos-del-selector-sin-duplicados.md) | Las fotos del selector no se duplican y conservan su fecha | P3 | S | — | DONE (fusionado en `main`) |
| [013](013-fotos-fuera-del-hilo-principal.md) | Las fotos se decodifican y reducen sin bloquear ni disparar la memoria | P3 | M | 007, 012 | TODO |
| [014](014-errores-y-registros.md) | Errores registrados con `Logger` y tratados en un solo sitio | P3 | S | 009, 010, 011 | TODO |
| [015](015-documentacion-al-dia.md) | Los comentarios y las guías ya no hablan de CloudKit | P3 | S | 001, 013 | TODO |
| [016](016-localizacion-sin-xcode-local.md) | Saber si los textos se extraen sin Xcode local; no anunciar inglés | P3 | S | 001 | DONE (fusionado en `main`; conclusión B) |

Estados: TODO | IN PROGRESS | DONE | BLOCKED (con el motivo en una línea) | REJECTED (con el motivo en una línea).

## Notas de dependencias

- **001 primero**: con la CI fijada, un fallo en cualquier plan posterior es culpa del plan y no de una dependencia que cambió sola.
- **003 después de 002**: los dos tocan cómo arranca la cuenta; 002 es pequeño y deja el estado estable.
- **003, 004 y 005 antes de construir la sincronización**: si no, la sincronización subiría datos de una cuenta a otra (003), registros duplicados o recreados (004) y filas con fechas del móvil que no se volverían a bajar (005).
- **006 → 007 → 008**: tocan `Formato.swift` y la moneda. 007 decide la «moneda principal», que necesita que 006 haya dejado de convertir todo a euros.
- **009 → 010 → 011 → 014**: tocan los mismos archivos de `Cuenta/`. 011 necesita el campo `proveedor` que añade 010, y 014 unifica los `catch` cuando el resto ya está.
- **005 y 010** terminan con un paso del operador (aplicar la migración, desplegar la función y configurar secretos). Quedan en `IN PROGRESS` hasta que lo confirme.
- **Independientes**: 004, 005 y 012 se pueden hacer en paralelo con el resto.

## Hallazgos considerados y descartados

- **Hacer explícito PKCE porque los enlaces `rico://` serían inseguros**: `supabase-swift` 2.55.4 ya usa PKCE por defecto (`AuthClient.Configuration.defaultFlowType = .pkce`); un enlace falso o interceptado no sirve sin el verificador del dispositivo. El plan 002 lo deja escrito igualmente, sin coste.
- **Unicidad global de `listas.enlace_publico`**: solo importa cuando se construyan las listas compartidas; entonces habrá que generar los enlaces en el servidor y servirlos con una función acotada.
- **Usar enlaces universales (dominio asociado) en lugar de `rico://`**: mejor a largo plazo, pero necesita dominio y cuenta de Apple Developer. Revisar al montar TestFlight.

## Aplazados (poco rendimiento ahora)

- Textos duplicados (líneas de dirección, valoración de platos, «¿Volverías?»), radios fuera de los tokens de `Medidas`, `CampoRico` y `CampoContrasena` fuera de `DesignSystem`, y logotipo reimplementado en `AccesoView`.
- Partir `FichaRapidaView.swift` (403 líneas) y `AccesoCorreoView.swift`: mejor después del plan 013 y con las pruebas del 007.
- Más pruebas: `BuscadorMapKit.lugar`, deduplicación de restaurantes por nombre y distancia, traducción de errores de Supabase y espera determinista en `CuentaTests` (sustituir el sondeo de 1 s).
- Linter o formateador (`swift format`) en la CI.

## Direcciones de producto (no son planes todavía)

- **Captura por Apple Pay (bloque 3 del MVP)**: el emparejado, el filtro de pagos y los modelos están hechos y probados, pero nada los usa. Falta la acción de Atajos, la notificación, la bandeja y el onboarding. Conviene decidir antes cómo sincronizar las visitas en borrador.
- **Pestañas y mapa personal (bloque 4)**: `DESIGN.md` ya define las cuatro pestañas y los colores de los pines; los restaurantes guardan coordenadas.
- **«Resumen del mes»**: el diario ya calcula visitas y gasto del mes; con el plan 007 queda listo para su pestaña.
- **Sincronización con Supabase**: la siguiente fase prevista en `docs/decisiones/0001-servidor-propio-supabase.md`, después de 003, 004 y 005.
