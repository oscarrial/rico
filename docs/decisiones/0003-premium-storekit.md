# 0003 · Rico Premium con StoreKit 2

- **Estado:** aceptada (21 de octubre de 2026)

## Decisión

Rico Premium es una **suscripción con renovación automática** cobrada por la App Store con StoreKit 2, sin servidor propio de recibos:

- Dos planes en un mismo grupo de suscripción, «Rico Premium»: mensual (`es.rico.app.premium.mensual`, 2,99 €) y anual (`es.rico.app.premium.anual`, 19,99 €, con 7 días de prueba gratis).
- Quién es Premium lo dice siempre la App Store: `Transaction.currentEntitlements`, contando solo transacciones **verificadas**, **no revocadas** y **no caducadas** de esos dos productos. `UserDefaults` guarda solo una copia para el arranque (no enseñar los límites del plan gratis el primer instante); se corrige en cuanto responde la tienda.
- `Transaction.updates` se escucha desde que aparece la raíz de la app (`RaizView.task`), así se notan renovaciones, reembolsos y compras hechas en otro dispositivo.
- «Restaurar compras» llama a `AppStore.sync()`.
- Todo pasa por el protocolo `TiendaPremium` (`TiendaStoreKit` en la app, una tienda falsa en `Tests/PremiumTests.swift`).
- Premium no se guarda en Supabase de momento: la suscripción va ligada a la cuenta de Apple del iPhone, no a la cuenta de Rico. Si algún día hace falta en el servidor (por ejemplo, para la web), se añadirá con las notificaciones de servidor de la App Store.

## Código

- `Packages/RicoKit/Sources/Premium/`: `EstadoPremium`, `TiendaPremium`, `TiendaStoreKit` y `PaywallView`.
- `DesignSystem/Entorno.swift`: `esPremium`, `pedirPremium` y `permitePedirPremium()`. Este último existe porque SwiftUI solo presenta una hoja por nivel: la ficha rápida y la cuenta ya son hojas, así que la de Premium tiene que salir desde ellas.
- Límite de fotos: `FichaRapidaModelo.limiteFotos` (`nil` con Premium).
- Pruebas locales: `Config/Rico.storekit`, enlazado en el esquema `Rico` solo al ejecutar en Debug (`project.yml`, `run.storeKitConfiguration`). En el simulador se compra sin cuenta real y se gestiona desde Xcode (Debug › StoreKit › Manage Transactions).

## Qué hay que crear en App Store Connect para TestFlight

Sin esto, en TestFlight el paywall dirá «Ahora mismo no podemos mostrar los precios».

1. **Acuerdos, impuestos y banca:** firmar el acuerdo de **Apps de pago** (Paid Apps Agreement) y rellenar los datos bancarios y fiscales. Sin él, StoreKit no devuelve productos ni en TestFlight.
2. **App › Monetización › Suscripciones › Crear grupo de suscripción**:
   - Nombre de referencia: `Rico Premium`.
   - Localización (español de España): nombre visible «Rico Premium».
3. **Dentro del grupo, crear dos suscripciones** (los identificadores tienen que ser exactamente estos; no se pueden cambiar ni reutilizar después):

   | Nombre de referencia | ID de producto | Duración | Precio (España) | Nivel |
   | --- | --- | --- | --- | --- |
   | Rico Premium anual | `es.rico.app.premium.anual` | 1 año | 19,99 € | 1 |
   | Rico Premium mensual | `es.rico.app.premium.mensual` | 1 mes | 2,99 € | 2 |

   En cada una: precio con la disponibilidad en todos los países (o solo España al principio), localización en español (nombre visible y descripción: «Fotos sin límite, todas tus listas, las estadísticas de tu año y exportar tu diario.») y una captura del paywall para la revisión (vale una del simulador).
4. **Oferta introductoria** en la anual: «Prueba gratis», 1 semana, para nuevos suscriptores, en todos los países.
5. **Compartir en familia:** desactivado (igual que en `Rico.storekit`). Se puede activar después, pero no desactivar.
6. Las suscripciones quedan en «Lista para enviar»: **la primera tiene que ir junto con una versión de la app** a revisión. En TestFlight funcionan antes de eso, con compras de prueba gratuitas (las renovaciones van aceleradas: un año dura una hora).
7. **Términos y privacidad:** la descripción de la app (o el campo de EULA personalizado) tiene que enlazar los términos de uso. El paywall enlaza `https://rico.app/terminos` y `https://rico.app/privacidad`; hay que publicar esas páginas (los términos pueden remitir al EULA estándar de Apple) antes de enviar a revisión.
8. Opcional, recomendado más adelante: **notificaciones de servidor de la App Store (v2)** para tener el estado en Supabase.

No hace falta tocar entitlements ni capacidades: las compras dentro de la app están activas por defecto en el App ID `es.rico.app`.
