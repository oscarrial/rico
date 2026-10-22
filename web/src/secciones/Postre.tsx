import { NumberTicker } from '@/components/motion/number-ticker'
import { CabeceraSeccion } from '@/componentes/Plato'
import { Iphone } from '@/componentes/Iphone'

const DATOS = [
  { valor: 47, sufijo: '', etiqueta: 'restaurantes este año' },
  { valor: 312, sufijo: ' €', etiqueta: 'en croquetas (sin arrepentimientos)' },
  { valor: 4.6, decimales: 1, sufijo: '', etiqueta: 'de nota media' },
  { valor: 9, sufijo: '', etiqueta: 'veces en tu favorito' },
]

export function Postre() {
  return (
    <section className="bg-rico-tinta py-24 text-rico-fondo">
      <div className="mx-auto grid max-w-6xl items-center gap-14 px-[max(1.25rem,env(safe-area-inset-left))] lg:grid-cols-[1.2fr_0.8fr]">
        <div className="flex flex-col gap-12">
          <div className="[&_h2]:text-rico-fondo [&_p:last-child]:text-rico-fondo/70">
            <CabeceraSeccion plato="Postre" titulo={<>Tu año en Rico. <span className="text-rico-tomate">Como un Wrapped, pero de comer.</span></>}>
              Cuántos sitios, cuánto gastas, tu plato estrella y el restaurante al que siempre
              vuelves. Para presumir o para ir al gimnasio. Viene con Premium.
            </CabeceraSeccion>
          </div>
          <dl className="grid grid-cols-2 gap-x-6 gap-y-10">
            {DATOS.map((dato) => (
              <div key={dato.etiqueta} className="flex flex-col gap-1 border-t border-rico-fondo/15 pt-4">
                <dd className="order-1 text-[clamp(2.6rem,6vw,4rem)] font-black leading-none tracking-tight text-rico-fondo">
                  <NumberTicker
                    value={dato.valor}
                    decimals={dato.decimales ?? 0}
                    suffix={dato.sufijo}
                    format={(v) => v.toLocaleString('es-ES', { minimumFractionDigits: dato.decimales ?? 0, maximumFractionDigits: dato.decimales ?? 0 })}
                  />
                </dd>
                <dt className="order-2 text-rico-fondo/70">{dato.etiqueta}</dt>
              </div>
            ))}
          </dl>
        </div>
        <div className="flex justify-center">
          <Iphone pantalla="resumen" alt="El resumen del año en Rico" className="rotate-[2deg]" />
        </div>
      </div>
    </section>
  )
}
