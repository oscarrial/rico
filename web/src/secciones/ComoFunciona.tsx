import { useRef, useState } from 'react'
import { AnimatePresence, motion, useMotionValueEvent, useReducedMotion, useScroll } from 'motion/react'
import { Iphone } from '@/componentes/Iphone'
import { PantallaAviso, PantallaDiario, PantallaPago, PantallaValorar } from '@/componentes/Pantallas'
import { Etiqueta } from '@/componentes/Piezas'

const PASOS = [
  {
    titulo: 'Pagas, como siempre.',
    texto: 'Con Apple Pay, Rico apunta el sitio, el día y el importe sin que toques nada.',
  },
  {
    titulo: 'Te pregunta qué tal.',
    texto: 'Un aviso un rato después, ya en la sobremesa. ¿Pagaste en efectivo? Rico nota que llevas un rato en un restaurante y te pregunta al salir.',
  },
  {
    titulo: 'Valoras en diez segundos.',
    texto: 'Estrellas, si volverías, qué pediste y una foto si quieres.',
  },
  {
    titulo: 'Y queda para siempre.',
    texto: 'En tu diario, en tu mapa y en tu resumen del mes. Nunca más un sitio olvidado.',
  },
]

/**
 * El iPhone se queda fijo en pantalla y, al bajar, va pasando por los cuatro momentos.
 * La sección mide cuatro pantallas de alto para dar recorrido al scroll.
 */
export function ComoFunciona() {
  const reducir = useReducedMotion()
  const recorrido = useRef<HTMLElement>(null)
  const { scrollYProgress } = useScroll({ target: recorrido, offset: ['start start', 'end end'] })
  const [paso, setPaso] = useState(0)

  useMotionValueEvent(scrollYProgress, 'change', (p) => {
    setPaso(Math.min(PASOS.length - 1, Math.max(0, Math.floor(p * PASOS.length))))
  })

  const pantallas = [
    <PantallaPago key="pago" />,
    <PantallaAviso key="aviso" activa={paso === 1} />,
    <PantallaValorar key="valorar" activa={paso === 2} />,
    <PantallaDiario key="diario" activa={paso === 3} />,
  ]

  return (
    <section id="como-funciona" ref={recorrido} className="relative h-[400svh] bg-mantel-hondo/60">
      <div className="sticky top-0 flex h-[100svh] flex-col items-center justify-center gap-5 overflow-hidden px-5 pt-16 sm:gap-8 lg:flex-row lg:gap-24">
        <div className="flex w-full max-w-md flex-col items-center gap-4 text-center lg:items-start lg:text-left">
          <Etiqueta>Primero · Así funciona</Etiqueta>
          <div className="relative min-h-[7.5rem] w-full sm:min-h-[10rem] lg:min-h-[13rem]">
            <AnimatePresence mode="wait" initial={false}>
              <motion.div
                key={paso}
                initial={reducir ? { opacity: 0 } : { opacity: 0, y: 24, filter: 'blur(6px)' }}
                animate={{ opacity: 1, y: 0, filter: 'blur(0px)' }}
                exit={reducir ? { opacity: 0 } : { opacity: 0, y: -24, filter: 'blur(6px)' }}
                transition={{ duration: 0.45, ease: [0.32, 0.72, 0, 1] }}
                className="flex flex-col gap-2 sm:gap-3"
              >
                <h2 className="text-[clamp(2rem,7.5vw,3.75rem)] font-black leading-[0.98] tracking-[-0.035em]">
                  <span className="text-tomate">{paso + 1}. </span>
                  {PASOS[paso].titulo}
                </h2>
                <p className="text-base text-tinta-suave sm:text-lg">{PASOS[paso].texto}</p>
              </motion.div>
            </AnimatePresence>
          </div>
          <div className="flex gap-2" aria-hidden>
            {PASOS.map((_, i) => (
              <span key={i} className="h-1.5 w-10 overflow-hidden rounded-full bg-tinta/10">
                <motion.span
                  className="block h-full rounded-full bg-tomate"
                  initial={false}
                  animate={{ width: i <= paso ? '100%' : '0%' }}
                  transition={{ duration: 0.5, ease: [0.32, 0.72, 0, 1] }}
                />
              </span>
            ))}
          </div>
        </div>

        <div className="w-[min(60vw,calc(47svh/2.087),330px)] shrink-0">
          <Iphone>
            {pantallas.map((pantalla, i) => (
              <motion.div
                key={i}
                className="absolute inset-0"
                initial={false}
                animate={{ opacity: i === paso ? 1 : 0, scale: i === paso || reducir ? 1 : 1.03 }}
                transition={{ duration: 0.5, ease: [0.32, 0.72, 0, 1] }}
                aria-hidden={i !== paso}
              >
                {pantalla}
              </motion.div>
            ))}
          </Iphone>
        </div>
      </div>
    </section>
  )
}
