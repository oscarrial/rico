import SwiftUI
import SwiftData
import DesignSystem
import Modelos
import Visitas

@main
struct RicoApp: App {
    let contenedor: ModelContainer
    @State private var mostrarInicio = true

    init() {
        do {
            contenedor = try ContenedorRico.crear()
        } catch {
            #if DEBUG
            // Sin firma (simulador de CI) no hay iCloud ni App Group: se usa una base local.
            print("Rico: sin iCloud (\(error)); se usa almacenamiento local.")
            contenedor = (try? ContenedorRico.crear(enMemoria: false, sinNube: true))
                ?? (try! ContenedorRico.crear(enMemoria: true))
            #else
            fatalError("No se pudo abrir la base de datos: \(error)")
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            DiarioView()
                .tint(.ricoTomate)
                .overlay {
                    if mostrarInicio {
                        PantallaInicio(visible: $mostrarInicio)
                            .transition(.opacity)
                    }
                }
        }
        .modelContainer(contenedor)
    }
}
