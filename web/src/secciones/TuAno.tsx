import { NumberTicker } from '@/components/motion/number-ticker'
import { Aparecer, Etiqueta } from '@/componentes/Piezas'
import { Iphone } from '@/componentes/Iphone'
import { Captura } from '@/componentes/Pantallas'

const CIFRAS = [
  { valor: 47, unidad: '', titulo: 'restaurantes', texto: 'Los que has probado este año, con su nota y lo que pediste.' },
  { valor: 312, unidad: '€', titulo: 'en croquetas', texto: 'Rico sabe cuánto gastas en cada cosa. Tú decides si te arrepientes.' },
  { valor: 4.6, decimales: 1, unidad: '★', titulo: 'de nota media', texto: 'Exigente, pero justo. Y comparada mes a mes.' },
  { valor: 9, unidad: '', titulo: 'veces en O Grelo', texto: 'Tu sitio de siempre, tu plato estrella y con quién vas más.' },
]

const formato = (decimales: number) => (v: number) =>
  v.toLocaleString('es-ES', { minimumFractionDigits: decimales, maximumFractionDigits: decimales })

export function TuAno() {
  return (
    <section className="mx-auto grid max-w-6xl gap-16 px-5 py-28 sm:px-8 sm:py-36 lg:grid-cols-2 lg:gap-24">
      <div className="lg:sticky lg:top-28 lg:h-max">
        <Aparecer className="flex flex-col gap-6">
          <Etiqueta>Postre · Con Premium</Etiqueta>
          <h2 className="text-[clamp(2.75rem,9vw,5.25rem)] font-black leading-[0.92] tracking-[-0.04em]">
            Tu año en Rico.{' '}
            <span className="text-tomate">Como un Wrapped, pero de comer.</span>
          </h2>
          <p className="max-w-md text-lg text-tinta-suave sm:text-xl">
            Para presumir en el grupo de las cenas o para apuntarte al gimnasio. Tú eliges.
          </p>
          <div className="mt-4 hidden w-[230px] lg:block">
            <Iphone>
              <Captura nombre="resumen" alt="El resumen de tu año en Rico" />
            </Iphone>
          </div>
        </Aparecer>
      </div>

      <dl className="flex flex-col">
        {CIFRAS.map((cifra, i) => (
          <Aparecer key={cifra.titulo} retraso={i * 0.05} className="flex flex-col gap-3 border-t border-hilo py-10 first:border-t-0 first:pt-0 lg:py-14">
            <dd className="order-1 flex items-baseline gap-3">
              <span className="text-[clamp(4.5rem,18vw,8rem)] font-black leading-[0.85] tracking-[-0.05em] text-tinta">
                <NumberTicker value={cifra.valor} decimals={cifra.decimales ?? 0} format={formato(cifra.decimales ?? 0)} />
              </span>
              {cifra.unidad ? (
                <span className="text-[clamp(2rem,7vw,3.5rem)] font-black text-tomate">{cifra.unidad}</span>
              ) : null}
            </dd>
            <dt className="order-2 text-2xl font-black tracking-[-0.02em] sm:text-3xl">{cifra.titulo}</dt>
            <p className="order-3 max-w-sm text-tinta-suave">{cifra.texto}</p>
          </Aparecer>
        ))}
      </dl>
    </section>
  )
}
