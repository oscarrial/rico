import SwiftUI
import DesignSystem
import Modelos
import RicoCore
import Visitas

/// Tarjeta inferior de un sitio tuyo: nombre, nota, ciudad, visitas y gasto medio.
struct TarjetaSitioMapa: View {
    let restaurante: Restaurante
    let alGuardarVisita: () -> Void
    let alCerrar: () -> Void

    var body: some View {
        let resumen = ResumenRestaurante(restaurante: restaurante)
        return Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(restaurante.nombre)
                                .font(.rico(.headline, peso: .heavy))
                                .foregroundStyle(Color.ricoTinta)
                                .accessibilityAddTraits(.isHeader)
                            Spacer(minLength: 0)
                            if let nota = resumen.notaMedia {
                                NotaCompacta(nota: nota)
                                    .foregroundStyle(Color.ricoTinta)
                            }
                        }
                        Text(detalle(resumen))
                            .font(.rico(.footnote, peso: .semibold))
                            .foregroundStyle(Color.ricoSecundario)
                    }
                    BotonCerrarTarjeta(accion: alCerrar)
                }

                if resumen.visitas.isEmpty {
                    Button(action: alGuardarVisita) {
                        Text("Guardar visita", bundle: .module)
                    }
                    .buttonStyle(.ricoPrincipal)
                } else {
                    NavigationLink(value: restaurante) {
                        Text("Ver ficha", bundle: .module)
                    }
                    .buttonStyle(.ricoPrincipal)
                }
            }
        }
    }

    private func detalle(_ resumen: ResumenRestaurante) -> String {
        var partes: [String] = []
        if let ciudad = restaurante.ciudad { partes.append(ciudad) }
        let visitas = resumen.visitas.count
        if visitas == 0 {
            partes.append(String(localized: "En Quiero probar", bundle: .module))
        } else if visitas == 1 {
            partes.append(String(localized: "1 visita", bundle: .module))
        } else {
            partes.append(String(localized: "\(visitas) visitas", bundle: .module))
        }
        if let gasto = resumen.gastoMedioPorPersona {
            let texto = gasto.decimal.formatted(.currency(code: gasto.divisa))
            partes.append(String(localized: "\(texto) por persona", bundle: .module))
        }
        return partes.joined(separator: " · ")
    }
}

/// Tarjeta inferior de un sitio encontrado con «Explorar zona».
struct TarjetaExploradoMapa: View {
    let lugar: LugarEncontrado
    let alGuardarVisita: () -> Void
    let alQuererProbar: () -> Void
    let alCerrar: () -> Void

    var body: some View {
        Tarjeta {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lugar.nombre)
                            .font(.rico(.headline, peso: .heavy))
                            .foregroundStyle(Color.ricoTinta)
                            .accessibilityAddTraits(.isHeader)
                        if let donde = [lugar.direccion, lugar.ciudad].compactMap({ $0 }).joined(separator: " · ").nilSiVacia {
                            Text(donde)
                                .font(.rico(.footnote, peso: .semibold))
                                .foregroundStyle(Color.ricoSecundario)
                        }
                    }
                    Spacer(minLength: 0)
                    BotonCerrarTarjeta(accion: alCerrar)
                }

                Button(action: alGuardarVisita) {
                    Text("Guardar visita", bundle: .module)
                }
                .buttonStyle(.ricoPrincipal)

                Button(action: alQuererProbar) {
                    Label {
                        Text("Quiero probarlo", bundle: .module)
                    } icon: {
                        Image(systemName: "bookmark")
                    }
                }
                .buttonStyle(.ricoSecundario)
            }
        }
    }
}

private struct BotonCerrarTarjeta: View {
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.ricoSecundario)
                .frame(width: 30, height: 30)
                .background(Color.ricoSuperficieHundida, in: Circle())
                .frame(width: Medidas.toqueMinimo, height: Medidas.toqueMinimo)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, -10)
        .padding(.trailing, -10)
        .accessibilityLabel(Text("Cerrar", bundle: .module))
    }
}

private extension String {
    var nilSiVacia: String? { isEmpty ? nil : self }
}
