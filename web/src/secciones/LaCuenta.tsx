import { useRef } from 'react'
import { motion, useInView, useReducedMotion } from 'motion/react'
import { Titular } from '@/componentes/Piezas'
import { PRECIOS } from '@/config'

/** Lo mismo que separa la app (RicoCore `LimitesGratis` y el paywall). */
const GRATIS = ['Diario, mapa y listas', 'Detectar comidas por ubicación', '1 captura con Apple Pay al mes', 'Resumen del mes']
const PREMIUM = ['Captura con Apple Pay sin límite', 'Fotos sin límite en cada visita', 'Todas las listas que quieras', '«Tu año en Rico»']

function Raya() {
  return <hr aria-hidden className="my-4 border-0 border-t-2 border-dashed border-[#cfc3b6]" />
}

export function LaCuenta() {
  const reducir = useReducedMotion()
  // El aviso va en el contenedor: el ticket recortado del todo no cuenta como visible.
  const impresora = useRef<HTMLDivElement>(null)
  const impreso = useInView(impresora, { once: true, amount: 0.15 })

  return (
    <section id="precios" className="mx-auto grid max-w-6xl items-center gap-14 px-5 py-28 sm:px-8 sm:py-36 lg:grid-cols-2 lg:gap-24">
      <Titular className="min-w-0" etiqueta="La cuenta" entradilla="Lo de cada día es gratis y sin anuncios. Premium es para quien sale mucho a comer y lo quiere todo automático.">
        Gratis para siempre. <span className="text-tomate">Premium, si te enganchas.</span>
      </Titular>

      <div ref={impresora} className="mx-auto w-full min-w-0 max-w-[420px]">
        <motion.div
          className="drop-shadow-[0_30px_40px_rgba(90,40,15,0.22)]"
          initial={reducir ? false : { clipPath: 'inset(0 0 100% 0)' }}
          animate={impreso || reducir ? { clipPath: 'inset(0 0 0% 0)' } : undefined}
          transition={{ duration: 1.6, ease: [0.22, 1, 0.36, 1] }}
        >
          <div className="dientes-arriba h-3 bg-papel" />
          <div className="bg-papel px-7 py-6 font-ticket text-[15px] leading-relaxed text-tinta">
            <div className="flex flex-col items-center gap-1 text-center">
              <img src="/marca/simbolo.svg" alt="" className="size-10" />
              <p className="font-rico text-2xl font-black">RICO</p>
              <p>Diario de restaurantes</p>
              <p>Mesa: tú · Comensales: 1</p>
            </div>
            <Raya />
            <p className="font-bold">PLAN GRATIS</p>
            <ul>
              {GRATIS.map((linea) => (
                <li key={linea} className="flex justify-between gap-4">
                  <span>{linea}</span>
                  <span className="shrink-0">0,00</span>
                </li>
              ))}
            </ul>
            <Raya />
            <p className="font-bold">PREMIUM</p>
            <ul>
              {PREMIUM.map((linea) => (
                <li key={linea}>+ {linea}</li>
              ))}
            </ul>
            <Raya />
            <dl className="flex flex-col gap-1">
              <div className="flex justify-between">
                <dt>Premium al mes</dt>
                <dd>{PRECIOS.mensual}</dd>
              </div>
              <div className="flex justify-between text-lg font-bold">
                <dt>Premium al año</dt>
                <dd>{PRECIOS.anual}</dd>
              </div>
              <div className="flex justify-between text-[#1f5a37]">
                <dt>Primera semana</dt>
                <dd>Invita la casa</dd>
              </div>
            </dl>
            <Raya />
            <p className="text-center">IVA incluido · Sin propina</p>
            <p className="text-center">¡Gracias por su visita!</p>
          </div>
          <div className="dientes h-3 bg-papel" />
        </motion.div>
      </div>
    </section>
  )
}
