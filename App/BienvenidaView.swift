import SwiftUI
import DesignSystem

/// Primera vez que se abre la app: qué es Rico en tres páginas.
struct BienvenidaView: View {
    let alTerminar: () -> Void

    @State private var pagina = 0

    private struct Pagina {
        let simbolo: String
        let titulo: LocalizedStringKey
        let texto: LocalizedStringKey
    }

    private let paginas: [Pagina] = [
        Pagina(
            simbolo: "book",
            titulo: "Tu diario de comidas",
            texto: "Guarda cada sitio donde comes: la nota, lo que pediste, cuánto pagaste y si volverías."
        ),
        Pagina(
            simbolo: "creditcard",
            titulo: "Paga y Rico se acuerda",
            texto: "Con un atajo de Apple Pay, cada pago en un restaurante te espera para que lo valores en diez segundos."
        ),
        Pagina(
            simbolo: "map",
            titulo: "Tu mapa y tus listas",
            texto: "Mira en el mapa dónde has comido bien y apunta los sitios que quieres probar."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $pagina) {
                ForEach(paginas.indices, id: \.self) { indice in
                    contenido(paginas[indice], primera: indice == 0)
                        .tag(indice)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if pagina < paginas.count - 1 {
                    withAnimation(.snappy) { pagina += 1 }
                } else {
                    alTerminar()
                }
            } label: {
                Text(pagina < paginas.count - 1 ? "Siguiente" : "Empezar")
            }
            .buttonStyle(.ricoPrincipal)
            .padding(.horizontal, Medidas.margen)
            .padding(.bottom, 16)
        }
        .background(Color.ricoFondo.ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            if pagina < paginas.count - 1 {
                Button(action: alTerminar) {
                    Text("Saltar")
                        .font(.rico(.subheadline, peso: .bold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .padding(.trailing, Medidas.margen)
            }
        }
    }

    private func contenido(_ pagina: Pagina, primera: Bool) -> some View {
        VStack(spacing: 22) {
            Spacer()
            if primera {
                SimboloRico()
                    .frame(width: 110, height: 110)
            } else {
                Image(systemName: pagina.simbolo)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(Color.ricoTomate)
                    .frame(width: 110, height: 110)
                    .accessibilityHidden(true)
            }
            Text(pagina.titulo)
                .font(.rico(.largeTitle, peso: .heavy))
                .foregroundStyle(Color.ricoTinta)
                .multilineTextAlignment(.center)
            Text(pagina.texto)
                .font(.rico(.body, peso: .semibold))
                .foregroundStyle(Color.ricoSecundario)
                .multilineTextAlignment(.center)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
