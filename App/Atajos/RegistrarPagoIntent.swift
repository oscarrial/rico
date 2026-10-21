import AppIntents
import Foundation
import Captura
import Modelos

/// Acción de Atajos «Registrar pago». Se usa en la automatización «Transacción» de Wallet:
/// recibe comercio, importe y tarjeta, y deja la visita lista para valorar.
/// Va en el target de la app porque los metadatos de App Intents se leen del binario de la app.
struct RegistrarPagoIntent: AppIntent {
    static var title: LocalizedStringResource { "Registrar pago" }
    static var description: IntentDescription {
        IntentDescription("Guarda un pago con tarjeta en Rico para que valores el restaurante después.")
    }
    /// Corre en segundo plano: pagar no debe abrir la app.
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Comercio", description: "Nombre del comercio tal como sale en el pago.")
    var comercio: String

    /// Texto porque Atajos pasa el importe como «48,00 €».
    @Parameter(title: "Importe", description: "Importe del pago, por ejemplo «48,00 €».")
    var importe: String

    @Parameter(title: "Tarjeta", description: "Tarjeta o pase con el que se pagó.")
    var tarjeta: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Registrar pago en \(\.$comercio) de \(\.$importe)") {
            \.$tarjeta
        }
    }

    init() {}

    init(comercio: String, importe: String, tarjeta: String? = nil) {
        self.comercio = comercio
        self.importe = importe
        self.tarjeta = tarjeta
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Nunca falla de cara al usuario: un error aquí saldría como alerta al pagar.
        // ProcesadorPagos no lanza; los fallos quedan en el registro.
        let contenedor = AlmacenApp.contenedor(usuario: AlmacenApp.usuarioGuardado)
        let procesador = ProcesadorPagos(
            contexto: contenedor.mainContext,
            buscador: BuscadorCercanoMapKit(),
            ubicacion: UbicacionCoreLocation(),
            notificador: NotificadorLocal()
        )
        let resultado = await procesador.procesar(comercio: comercio, importe: importe, tarjeta: tarjeta)
        Registro.captura.info("Atajo «Registrar pago»: \(String(describing: resultado), privacy: .public)")
        return .result()
    }
}

/// Frases de Siri y la acción en la app Atajos.
struct AtajosRico: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RegistrarPagoIntent(),
            phrases: [
                "Registrar un pago en \(.applicationName)",
                "Apuntar un pago en \(.applicationName)",
                "Guardar un pago en \(.applicationName)"
            ],
            shortTitle: "Registrar pago",
            systemImageName: "creditcard"
        )
    }
}
