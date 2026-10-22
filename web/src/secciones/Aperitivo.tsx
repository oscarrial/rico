import { useEffect, useRef, useState } from 'react'
import { motion, useInView, useReducedMotion } from 'motion/react'
import { DynamicIsland, DynamicIslandView } from '@/components/motion/dynamic-island'
import { TextReveal } from '@/components/motion/text-reveal'
import { Iphone } from '@/componentes/Iphone'
import { Plato } from '@/componentes/Plato'
import { ENLACE_BETA } from '@/config'

type Vista = 'pago' | 'pregunta' | 'guardado' | null

/** Lo que pasa en el iPhone después de pagar, en bucle: cuánto dura cada momento. */
const SECUENCIA: { vista: Vista; ms: number }[] = [
  { vista: null, ms: 1400 },
  { vista: 'pago', ms: 2600 },
  { vista: 'pregunta', ms: 3400 },
  { vista: 'guardado', ms: 2200 },
]

function Estrellas({ llenas, animar }: { llenas: number; animar: boolean }) {
  return (
    <span className="flex gap-1" aria-label={`${llenas} de 5 estrellas`}>
      {[0, 1, 2, 3, 4].map((i) => (
        <motion.svg
          key={i}
          viewBox="0 0 24 24"
          className="size-5"
          initial={animar ? { scale: 0.6, opacity: 0.3 } : false}
          animate={{ scale: 1, opacity: 1 }}
          transition={{ delay: animar ? 0.5 + i * 0.22 : 0, type: 'spring', bounce: 0.55, duration: 0.5 }}
          aria-hidden
        >
          <path
            d="M12 2.8l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 16.8l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"
            fill={i < llenas ? '#F5B331' : '#4A4038'}
          />
        </motion.svg>
      ))}
    </span>
  )
}

function IslaPago() {
  const reducir = useReducedMotion()
  const ref = useRef<HTMLDivElement>(null)
  const visible = useInView(ref, { amount: 0.4 })
  const [paso, setPaso] = useState(reducir ? 2 : 0)

  useEffect(() => {
    if (reducir || !visible) return
    const reloj = setTimeout(() => setPaso((p) => (p + 1) % SECUENCIA.length), SECUENCIA[paso].ms)
    return () => clearTimeout(reloj)
  }, [paso, reducir, visible])

  return (
    <div ref={ref} className="absolute inset-x-0 top-[1.6%] flex justify-center">
      <DynamicIsland
        view={SECUENCIA[paso].vista}
        className="bg-black text-white"
        compact={<span className="block h-[22px] w-[90px]" aria-hidden />}
      >
        <DynamicIslandView id="pago" className="gap-3 whitespace-nowrap px-5 py-3">
          <span className="grid size-9 place-items-center rounded-full bg-white text-black">
            <svg viewBox="0 0 24 24" className="size-5" aria-hidden>
              <path fill="currentColor" d="M3 6.5A2.5 2.5 0 0 1 5.5 4h13A2.5 2.5 0 0 1 21 6.5v11a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 17.5zM3 9h18v2.5H3z" />
            </svg>
          </span>
          <span className="flex flex-col text-left leading-tight">
            <span className="text-[11px] font-bold text-white/60">Apple Pay</span>
            <span className="text-sm font-extrabold">Taberna O Grelo</span>
          </span>
          <span className="ml-2 text-base font-black tabular-nums">48,00 €</span>
        </DynamicIslandView>

        <DynamicIslandView id="pregunta" className="flex-col items-start gap-2 whitespace-nowrap px-5 py-4">
          <span className="flex items-center gap-2">
            <img src="/marca/simbolo.svg" alt="" className="size-5" />
            <span className="text-[11px] font-bold text-white/60">Rico · ahora</span>
          </span>
          <span className="text-base font-black">¿Qué tal en O Grelo?</span>
          <Estrellas llenas={5} animar={!reducir} />
        </DynamicIslandView>

        <DynamicIslandView id="guardado" className="gap-2 whitespace-nowrap px-5 py-2.5">
          <svg viewBox="0 0 24 24" className="size-5 text-[#7FD3A0]" aria-hidden>
            <path fill="none" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" d="M5 12.5l4.5 4.5L19 7.5" />
          </svg>
          <span className="text-sm font-extrabold">Guardado en tu diario</span>
        </DynamicIslandView>
      </DynamicIsland>
    </div>
  )
}

export function Aperitivo() {
  return (
    <section className="relative overflow-hidden">
      {/* Mantel: un círculo de luz cálida detrás del iPhone. */}
      <div
        aria-hidden
        className="pointer-events-none absolute -right-40 top-10 size-[42rem] rounded-full bg-rico-tomate/10 blur-3xl"
      />
      <div className="relative mx-auto grid max-w-6xl items-center gap-14 px-[max(1.25rem,env(safe-area-inset-left))] pb-24 pt-10 sm:pt-16 lg:grid-cols-[1.1fr_0.9fr]">
        <div className="flex flex-col gap-7">
          <Plato nombre="Aperitivo" />
          <h1 className="text-[clamp(3.2rem,9vw,6.5rem)] font-black leading-[0.92] tracking-[-0.035em]">
            <TextReveal text="Paga." className="block" />
            <TextReveal text="Rico se acuerda." className="block text-rico-tomate" delay={0.25} />
          </h1>
          <p className="max-w-md text-xl text-rico-secundario">
            Tu diario de restaurantes para iPhone. Pagas la cena, Rico te pregunta qué tal y lo
            valoras en diez segundos. Nunca más «¿cómo se llamaba aquel sitio?».
          </p>
          <div className="flex flex-wrap items-center gap-4">
            <a
              href={ENLACE_BETA}
              className="inline-flex min-h-14 items-center gap-2 rounded-full bg-rico-tomate px-7 text-lg font-black text-rico-sobre-tomate shadow-[0_12px_30px_-12px_var(--rico-tomate)] transition-transform hover:-translate-y-0.5 active:translate-y-0"
            >
              Prueba la beta
              <span aria-hidden>→</span>
            </a>
            <span className="text-sm font-bold text-rico-secundario">Gratis · iPhone con iOS 17 o posterior</span>
          </div>
        </div>

        <div className="flex justify-center lg:justify-end">
          <Iphone pantalla="diario" alt="El diario de Rico con tus últimas visitas" prioridad className="max-w-[320px] rotate-[2deg]">
            <IslaPago />
          </Iphone>
        </div>
      </div>
    </section>
  )
}
