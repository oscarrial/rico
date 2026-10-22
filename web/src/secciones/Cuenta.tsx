import { useRef } from 'react'
import { motion, useInView, useReducedMotion } from 'motion/react'
import { CabeceraSeccion } from '@/componentes/Plato'
import { ENLACE_BETA, PRECIOS } from '@/config'

type Linea = { concepto: string; gratis: string; premium: string }

/** Lo mismo que separa la app (RicoCore `LimitesGratis` y el paywall). */
const LINEAS: Linea[] = [
  { concepto: 'Visitas y valoraciones', gratis: 'Sin límite', premium: 'Sin límite' },
  { concepto: 'Mapa y «Quiero probar»', gratis: 'Sí', premium: 'Sí' },
  { concepto: 'Detectar comidas por ubicación', gratis: 'Sí', premium: 'Sí' },
  { concepto: 'Captura con Apple Pay', gratis: '1 al mes', premium: 'Todas' },
  { concepto: 'Fotos por visita', gratis: '3', premium: 'Sin límite' },
  { concepto: 'Listas propias', gratis: '3', premium: 'Todas' },
  { concepto: 'Resumen del mes', gratis: 'Sí', premium: 'Sí' },
  { concepto: '«Tu año en Rico»', gratis: '—', premium: 'Sí' },
  { concepto: 'Exportar tu diario', gratis: '—', premium: 'Pronto' },
]

/** Borde de papel rasgado del ticket. */
function Dientes({ abajo = false }: { abajo?: boolean }) {
  return (
    <svg
      viewBox="0 0 120 6"
      preserveAspectRatio="none"
      className={`block h-3 w-full text-rico-papel ${abajo ? '' : 'rotate-180'}`}
      aria-hidden
    >
      <path fill="currentColor" d="M0 0h120v1L115 6l-5-5-5 5-5-5-5 5-5-5-5 5-5-5-5 5-5-5-5 5-5-5-5 5-5-5-5 5-5-5-5 5-5-5-5 5-5-5-5 5-5-5-5 5-5-5-5 5L0 1z" />
    </svg>
  )
}

export function Cuenta() {
  const reducir = useReducedMotion()
  // El aviso va en el contenedor: el ticket recortado del todo no cuenta como visible.
  const impresora = useRef<HTMLDivElement>(null)
  const impreso = useInView(impresora, { once: true, amount: 0.15 })
  const fecha = new Date().toLocaleDateString('es-ES', { day: '2-digit', month: '2-digit', year: 'numeric' })

  return (
    <section id="precios" className="bg-rico-hundida/60 py-24">
      <div className="mx-auto grid max-w-6xl items-start gap-14 px-[max(1.25rem,env(safe-area-inset-left))] lg:grid-cols-[0.9fr_1.1fr]">
        <CabeceraSeccion plato="La cuenta" titulo={<>Gratis para siempre. <span className="text-rico-tomate">Premium, si te enganchas.</span></>}>
          Lo de cada día es gratis y sin anuncios. Premium es para quien sale mucho a comer y lo
          quiere todo automático.
        </CabeceraSeccion>

        {/* El ticket sale de la impresora al llegar con el scroll. */}
        <div ref={impresora} className="mx-auto w-full max-w-md">
        <motion.div
          className="drop-shadow-[0_30px_40px_rgba(60,25,10,0.25)]"
          initial={reducir ? false : { clipPath: 'inset(0 0 100% 0)' }}
          animate={impreso || reducir ? { clipPath: 'inset(0 0 0% 0)' } : undefined}
          transition={{ duration: 1.6, ease: [0.22, 1, 0.36, 1] }}
        >
          <Dientes />
          <div className="bg-rico-papel px-6 py-6 font-ticket text-[15px] leading-relaxed text-[#2a2420] sm:px-8">
            <div className="flex flex-col items-center gap-1 text-center">
              <img src="/marca/simbolo.svg" alt="" className="size-10" />
              <p className="font-rico text-2xl font-black">RICO</p>
              <p>Diario de restaurantes</p>
              <p>Mesa: tú · {fecha}</p>
            </div>
            <p className="my-4 overflow-hidden whitespace-nowrap text-[#8e8379]" aria-hidden>
              - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            </p>
            <table className="w-full table-fixed">
              <caption className="sr-only">Qué incluye el plan gratis y qué incluye Premium</caption>
              <thead>
                <tr className="text-left">
                  <th scope="col" className="w-[46%] pb-2 font-bold">CONCEPTO</th>
                  <th scope="col" className="pb-2 text-right font-bold">GRATIS</th>
                  <th scope="col" className="pb-2 text-right font-bold">PREMIUM</th>
                </tr>
              </thead>
              <tbody>
                {LINEAS.map((linea) => (
                  <tr key={linea.concepto} className="align-top">
                    <th scope="row" className="py-1 pr-2 text-left font-normal">{linea.concepto}</th>
                    <td className="py-1 text-right">{linea.gratis}</td>
                    <td className="py-1 text-right font-bold">{linea.premium}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            <p className="my-4 overflow-hidden whitespace-nowrap text-[#8e8379]" aria-hidden>
              - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
            </p>
            <dl className="flex flex-col gap-1">
              <div className="flex justify-between">
                <dt>GRATIS</dt>
                <dd>0,00 €</dd>
              </div>
              <div className="flex justify-between">
                <dt>PREMIUM MENSUAL</dt>
                <dd>{PRECIOS.mensual}</dd>
              </div>
              <div className="flex justify-between text-lg font-bold">
                <dt>PREMIUM ANUAL</dt>
                <dd>{PRECIOS.anual}</dd>
              </div>
              <div className="flex justify-between text-[#1F5A37]">
                <dt>Prueba</dt>
                <dd>{PRECIOS.prueba}</dd>
              </div>
            </dl>
            <p className="mt-5 text-center">IVA incluido · Sin propina</p>
            <p className="text-center">¡Gracias por su visita!</p>
            <a
              href={ENLACE_BETA}
              className="mt-6 flex min-h-12 items-center justify-center rounded-full bg-[#D2381F] font-rico text-lg font-black text-white"
            >
              Prueba la beta gratis
            </a>
          </div>
          <Dientes abajo />
        </motion.div>
        </div>
      </div>
    </section>
  )
}
