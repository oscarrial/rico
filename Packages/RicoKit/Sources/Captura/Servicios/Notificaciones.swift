import Foundation
import Observation
import UserNotifications
import Modelos
import RicoCore

/// Enlaces `rico://visita/<uuid>`: abren la ficha para valorar esa visita.
public enum EnlaceVisita {
    public static func url(_ id: UUID) -> URL {
        URL(string: "rico://visita/\(id.uuidString.lowercased())")!
    }

    /// El id de la visita si el enlace es `rico://visita/<uuid>`; `nil` para cualquier otro.
    public static func visita(de url: URL) -> UUID? {
        guard url.scheme?.lowercased() == "rico", url.host()?.lowercased() == "visita" else { return nil }
        let partes = url.pathComponents.filter { $0 != "/" }
        guard partes.count == 1 else { return nil }
        return UUID(uuidString: partes[0])
    }
}

/// Visita que hay que abrir porque se tocó un aviso o un enlace. La raíz de la app la observa.
@MainActor
@Observable
public final class AperturaVisita {
    public static let compartida = AperturaVisita()

    public var pendiente: UUID?

    public init() {}

    /// Atiende el enlace si es de una visita. Devuelve `false` si es de otra cosa.
    @discardableResult
    public func abrir(_ url: URL) -> Bool {
        guard let id = EnlaceVisita.visita(de: url) else { return false }
        pendiente = id
        return true
    }
}

/// Avisos locales con `UNUserNotificationCenter`.
@MainActor
public final class NotificadorLocal: Notificador {
    nonisolated static let categoria = "RICO_VALORAR"
    nonisolated static let accionValorar = "RICO_VALORAR_ACCION"
    nonisolated static let claveEnlace = "enlace"

    public init() {}

    /// Registra la acción «Valorar» de los avisos. Se llama al arrancar la app.
    public static func registrarCategorias() {
        let valorar = UNNotificationAction(
            identifier: Self.accionValorar,
            title: String(localized: "Valorar", bundle: .module),
            options: [.foreground]
        )
        let grupo = UNNotificationCategory(identifier: Self.categoria, actions: [valorar], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([grupo])
    }

    public func programarValoracion(visitaID: UUID, sitio: String?, importe: Importe, retraso: TimeInterval) async {
        guard await PermisoNotificaciones.estadoActual().permiteAvisos else {
            Registro.captura.notice("Sin permiso de notificaciones: no se programa el aviso")
            return
        }
        let contenido = UNMutableNotificationContent()
        if let sitio {
            contenido.title = String(localized: "¿Qué tal en \(sitio)?", bundle: .module)
            contenido.body = String(localized: "Valora tu visita", bundle: .module)
        } else {
            contenido.title = String(localized: "¿Qué tal estuvo?", bundle: .module)
            contenido.body = String(localized: "Dinos dónde pagaste \(importe.textoMoneda) y valora tu visita", bundle: .module)
        }
        contenido.sound = .default
        contenido.categoryIdentifier = Self.categoria
        contenido.threadIdentifier = "rico.valorar"
        contenido.userInfo = [Self.claveEnlace: EnlaceVisita.url(visitaID).absoluteString]

        let disparador = UNTimeIntervalNotificationTrigger(timeInterval: max(1, retraso), repeats: false)
        let peticion = UNNotificationRequest(identifier: visitaID.uuidString, content: contenido, trigger: disparador)
        do {
            try await UNUserNotificationCenter.current().add(peticion)
        } catch {
            Registro.captura.error("No se pudo programar el aviso: \(String(describing: error), privacy: .public)")
        }
    }

    public func programarEstancia(visitaID: UUID, sitio: String) async {
        guard await PermisoNotificaciones.estadoActual().permiteAvisos else { return }
        let contenido = UNMutableNotificationContent()
        contenido.title = String(localized: "¿Has comido en \(sitio)?", bundle: .module)
        contenido.body = String(localized: "Valóralo en diez segundos. Si no, descártalo en la bandeja.", bundle: .module)
        contenido.sound = .default
        contenido.categoryIdentifier = Self.categoria
        contenido.threadIdentifier = "rico.valorar"
        contenido.userInfo = [Self.claveEnlace: EnlaceVisita.url(visitaID).absoluteString]
        // iOS entrega la estancia al salir del sitio: se avisa casi enseguida.
        let peticion = UNNotificationRequest(
            identifier: visitaID.uuidString,
            content: contenido,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5 * 60, repeats: false)
        )
        do {
            try await UNUserNotificationCenter.current().add(peticion)
        } catch {
            Registro.captura.error("No se pudo programar el aviso de estancia: \(String(describing: error), privacy: .public)")
        }
    }

    /// Un pago en un restaurante llegó cuando el plan gratis ya había usado su captura del mes.
    /// Solo se avisa una vez al mes, para invitar a Premium sin agobiar.
    public func avisarLimiteGratis(fecha: Date = .now, preferencias: UserDefaults = .standard) async {
        let mes = fecha.formatted(.iso8601.year().month())
        let clave = "captura.avisoLimite"
        guard preferencias.string(forKey: clave) != mes else { return }
        guard await PermisoNotificaciones.estadoActual().permiteAvisos else { return }
        preferencias.set(mes, forKey: clave)

        let contenido = UNMutableNotificationContent()
        contenido.title = String(localized: "Ya has usado tu captura gratis del mes", bundle: .module)
        contenido.body = String(localized: "Con Rico Premium, cada pago en un restaurante se guarda solo. Puedes apuntar esta visita a mano.", bundle: .module)
        contenido.sound = .default
        contenido.threadIdentifier = "rico.premium"
        let peticion = UNNotificationRequest(
            identifier: "rico.limite.\(mes)",
            content: contenido,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(peticion)
    }

    public func cancelar(visitaID: UUID) {
        let centro = UNUserNotificationCenter.current()
        centro.removePendingNotificationRequests(withIdentifiers: [visitaID.uuidString])
        centro.removeDeliveredNotifications(withIdentifiers: [visitaID.uuidString])
    }
}

/// Recibe los toques en los avisos y abre la visita.
@MainActor
public final class DelegadoNotificaciones: NSObject, UNUserNotificationCenterDelegate {
    public static let compartido = DelegadoNotificaciones()

    /// Pone el delegado y registra las acciones. Llamar al arrancar la app.
    public static func activar() {
        UNUserNotificationCenter.current().delegate = compartido
        NotificadorLocal.registrarCategorias()
    }

    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let texto = response.notification.request.content.userInfo[NotificadorLocal.claveEnlace] as? String
        if let texto, let url = URL(string: texto) {
            Task { @MainActor in
                AperturaVisita.compartida.abrir(url)
            }
        }
        completionHandler()
    }

    public nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

/// Estado del permiso de notificaciones.
public enum EstadoPermiso: Sendable, Equatable {
    case sinPreguntar
    case concedido
    case denegado

    public var permiteAvisos: Bool { self == .concedido }
}

/// Permiso de notificaciones, para la guía del atajo.
@MainActor
@Observable
public final class PermisoNotificaciones {
    public private(set) var estado: EstadoPermiso = .sinPreguntar

    public init() {}

    public func actualizar() async {
        estado = await Self.estadoActual()
    }

    public func pedir() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Registro.captura.error("No se pudo pedir permiso de notificaciones: \(String(describing: error), privacy: .public)")
        }
        await actualizar()
    }

    nonisolated static func estadoActual() async -> EstadoPermiso {
        await withCheckedContinuation { continuacion in
            UNUserNotificationCenter.current().getNotificationSettings { ajustes in
                let estado: EstadoPermiso = switch ajustes.authorizationStatus {
                case .authorized, .provisional, .ephemeral: .concedido
                case .denied: .denegado
                case .notDetermined: .sinPreguntar
                @unknown default: .sinPreguntar
                }
                continuacion.resume(returning: estado)
            }
        }
    }
}

extension Importe {
    /// «48,00 €» según el idioma del usuario.
    var textoMoneda: String {
        decimal.formatted(.currency(code: divisa))
    }
}
