import Foundation
import Observation
import SwiftData
import Modelos

/// Lanza las vueltas de sincronización de una cuenta: al abrir sesión, al volver a primer plano
/// y tras cada guardado (con antirrebote). Nunca bloquea la interfaz ni muestra alertas: los
/// errores se registran y se reintenta en la siguiente ocasión.
///
/// Sin servidor o sin usuario (modo solo local) no hace nada.
@MainActor
@Observable
public final class Sincronizador {
    /// Cuenta cuya base sincroniza (`nil` en modo solo local).
    public let usuario: UUID?
    /// Última vuelta completa sin errores.
    public private(set) var ultimoGuardado: Date?
    /// Hay cambios del iPhone que aún no han llegado al servidor.
    public private(set) var hayPendientes = false
    /// Hay una vuelta en curso.
    public private(set) var trabajando = false

    @ObservationIgnored private let motor: MotorSincronizacion?
    @ObservationIgnored private let preferencias: UserDefaults
    @ObservationIgnored private let antirrebote: Duration
    @ObservationIgnored private var programada: Task<Void, Never>?
    @ObservationIgnored private var enCurso: Task<Void, Never>?
    @ObservationIgnored private var otraVuelta = false
    @ObservationIgnored private var parado = false
    @ObservationIgnored private var observador: (any NSObjectProtocol)?

    public init(
        contexto: ModelContext,
        servicio: (any ServicioSincronizacion)?,
        usuario: UUID?,
        preferencias: UserDefaults = .standard,
        antirrebote: Duration = .seconds(3)
    ) {
        self.usuario = usuario
        self.preferencias = preferencias
        self.antirrebote = antirrebote
        if let servicio, let usuario {
            motor = MotorSincronizacion(contexto: contexto, servicio: servicio, usuario: usuario)
            ultimoGuardado = preferencias.object(forKey: Self.claveUltimoGuardado(usuario)) as? Date
        } else {
            motor = nil
        }
    }

    /// Si sincroniza de verdad (hay servidor y cuenta, y no se ha parado).
    public var activo: Bool { motor != nil && !parado }

    /// Empieza: primera vuelta ya y escucha los guardados de SwiftData.
    public func arrancar() {
        guard activo, observador == nil else { return }
        observador = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.alGuardar()
            }
        }
        programar(tras: .zero)
    }

    /// Para del todo (cambio de usuario o cierre de sesión). No se puede volver a arrancar.
    public func parar() {
        parado = true
        programada?.cancel()
        enCurso?.cancel()
        programada = nil
        if let observador { NotificationCenter.default.removeObserver(observador) }
        observador = nil
    }

    /// Pide una vuelta dentro de `retardo` (por defecto, el antirrebote). Las peticiones
    /// seguidas se juntan en una sola.
    public func programar(tras retardo: Duration? = nil) {
        guard activo else { return }
        programada?.cancel()
        let espera = retardo ?? antirrebote
        programada = Task { [weak self] in
            if espera > .zero {
                try? await Task.sleep(for: espera)
            }
            guard !Task.isCancelled else { return }
            await self?.sincronizarAhora()
        }
    }

    /// Hace una vuelta ahora (o la encadena a la que está en curso) y espera a que acabe.
    public func sincronizarAhora() async {
        guard activo, let motor else { return }
        if let enCurso {
            otraVuelta = true
            await enCurso.value
            return
        }
        let tarea = Task { [weak self] in
            guard let self else { return }
            self.trabajando = true
            repeat {
                self.otraVuelta = false
                await self.vuelta(motor)
            } while self.otraVuelta && !self.parado && !Task.isCancelled
            self.trabajando = false
        }
        enCurso = tarea
        await tarea.value
        enCurso = nil
    }

    /// Baja la imagen completa de una foto que vino del servidor solo con la miniatura.
    public func bajarImagenCompleta(de foto: Foto) async {
        guard activo, let motor else { return }
        do {
            try await motor.bajarImagenCompleta(de: foto)
        } catch {
            Registro.sincronizacion.notice("No se pudo bajar la imagen completa: \(String(describing: error), privacy: .private)")
        }
    }

    // MARK: Privado

    private func vuelta(_ motor: MotorSincronizacion) async {
        do {
            try await motor.sincronizar()
            guard !parado else { return }
            let ahora = Date()
            ultimoGuardado = ahora
            if let usuario { preferencias.set(ahora, forKey: Self.claveUltimoGuardado(usuario)) }
        } catch is CancellationError {
            return
        } catch {
            Registro.sincronizacion.error("Vuelta de sincronización fallida: \(String(describing: error), privacy: .private)")
        }
        guard !parado else { return }
        hayPendientes = (try? motor.hayPendientes()) ?? false
        await motor.bajarMiniaturasQueFaltan()
    }

    private func alGuardar() {
        guard activo, let motor, !motor.guardando else { return }
        hayPendientes = true
        programar()
    }

    static func claveUltimoGuardado(_ usuario: UUID) -> String {
        "RicoUltimoGuardado-\(usuario.uuidString.lowercased())"
    }
}
