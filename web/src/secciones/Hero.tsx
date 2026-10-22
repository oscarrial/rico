import { useEffect, useRef, useState, type ReactNode } from 'react'
import { motion, useInView, useReducedMotion } from 'motion/react'
import { DynamicIsland, DynamicIslandView } from '@/components/motion/dynamic-island'
import { Iphone } from '@/componentes/Iphone'
import { Captura } from '@/componentes/Pantallas'
import { Estrellas, InsigniaAppStore } from '@/componentes/Piezas'
import { ENLACE_BETA } from '@/config'

const MUELLE = [0.32, 0.72, 0, 1] as const

type Vista = 'pago' | 'pregunta' | 'guardado' | null

/** Lo que pasa en el iPhone después de pagar, en bucle y sin prisa. */
const SECUENCIA: { vista: Vista; ms: number }[] = [
  { vista: null, ms: 2200 },
  { vista: 'pago', ms: 3000 },
  { vista: 'pregunta', ms: 3800 },
  { vista: 'guardado', ms: 2600 },
]

/** La Dynamic Island, a tamaño real sobre la captura (que ya dibuja la isla apagada). */
function Isla() {
  const reducir = useReducedMotion()
  const ref = useRef<HTMLDivElement>(null)
  const visible = useInView(ref, { amount: 0.3 })
  const [paso, setPaso] = useState(reducir ? 2 : 0)

  useEffect(() => {
    if (reducir || !visible) return
    const reloj = setTimeout(() => setPaso((p) => (p + 1) % SECUENCIA.length), SECUENCIA[paso].ms)
    return () => clearTimeout(reloj)
  }, [paso, reducir, visible])

  return (
    <div ref={ref} className="absolute inset-x-0 top-[14px] flex justify-center">
      <DynamicIsland view={SECUENCIA[paso].vista} className="bg-black text-white shadow-none">
        <DynamicIslandView id="pago" className="gap-3 whitespace-nowrap px-4 py-3">
          <span className="grid size-10 place-items-center rounded-full bg-white text-black">
            <svg viewBox="0 0 24 24" className="size-5" aria-hidden>
              <rect x="3" y="5.5" width="18" height="13" rx="2.5" fill="none" stroke="currentColor" strokeWidth="1.8" />
              <path d="M3 10h18" stroke="currentColor" strokeWidth="1.8" />
            </svg>
          </span>
          <span className="flex flex-col text-left leading-tight">
            <span className="text-[12px] font-bold text-white/55">Apple Pay</span>
            <span className="text-[16px] font-extrabold">Taberna O Grelo</span>
          </span>
          <span className="ml-3 text-[18px] font-black tabular-nums">48,00 €</span>
        </DynamicIslandView>

        <DynamicIslandView id="pregunta" className="flex-col items-start gap-2 whitespace-nowrap px-5 py-4">
          <span className="flex items-center gap-2">
            <img src="/marca/icono.png" alt="" className="size-5 rounded-[5px]" />
            <span className="text-[12px] font-bold text-white/55">Rico · ahora</span>
          </span>
          <span className="text-[19px] font-black">¿Qué tal en O Grelo?</span>
          <span className="flex gap-1">
            {[0, 1, 2, 3, 4].map((i) => (
              <motion.svg
                key={i}
                viewBox="0 0 24 24"
                className="size-6"
                initial={reducir ? false : { scale: 0.5, opacity: 0.25 }}
                animate={{ scale: 1, opacity: 1 }}
                transition={{ delay: 0.6 + i * 0.22, type: 'spring', bounce: 0.45, duration: 0.6 }}
                aria-hidden
              >
                <path d="M12 2.6l2.8 5.8 6.3.9-4.6 4.4 1.1 6.3L12 17l-5.6 3 1.1-6.3-4.6-4.4 6.3-.9z" fill="#F5B331" />
              </motion.svg>
            ))}
          </span>
        </DynamicIslandView>

        <DynamicIslandView id="guardado" className="gap-2 whitespace-nowrap px-5 py-2.5">
          <svg viewBox="0 0 24 24" className="size-5 text-[#7FD3A0]" aria-hidden>
            <path fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" d="M5 12.5l4.5 4.5L19 7.5" />
          </svg>
          <span className="text-[15px] font-extrabold">Guardado en tu diario</span>
        </DynamicIslandView>
      </DynamicIsland>
    </div>
  )
}

/** Tarjeta pequeña de la app que flota al lado del iPhone. Decorativa: no se puede tocar. */
function Flotante({ children, className, retraso }: { children: ReactNode; className: string; retraso: string }) {
  return (
    <div aria-hidden className={`pointer-events-none absolute z-10 ${className}`}>
      <div className="flotar rounded-[1.35rem] bg-white/70 p-1 shadow-[0_24px_50px_-24px_rgba(90,40,15,0.5)] ring-1 ring-black/5 backdrop-blur-sm" style={{ animationDelay: retraso }}>
        <div className="rounded-[calc(1.35rem-0.25rem)] bg-white px-3.5 py-2.5 shadow-[inset_0_1px_1px_rgba(255,255,255,0.9)]">{children}</div>
      </div>
    </div>
  )
}

export function Hero() {
  const reducir = useReducedMotion()
  const entrada = (retraso: number) => ({
    initial: reducir ? false : { opacity: 0, y: 14 },
    animate: { opacity: 1, y: 0 },
    transition: { duration: 0.8, delay: retraso, ease: MUELLE },
  })

  return (
    <section className="relative overflow-hidden">
      <div className="mx-auto grid max-w-6xl items-center gap-12 px-5 pb-20 pt-28 sm:px-8 sm:pt-32 lg:min-h-[min(100dvh,920px)] lg:grid-cols-[1.1fr_0.9fr] lg:gap-16 lg:pb-16 lg:pt-24">
        <div className="flex flex-col items-center gap-6 text-center lg:items-start lg:text-left">
          <motion.span
            {...entrada(0)}
            className="inline-flex items-center gap-2.5 rounded-full bg-white/85 py-1.5 pl-1.5 pr-4 text-[13px] font-extrabold ring-1 ring-hilo"
          >
            <span className="rounded-full bg-tomate px-2.5 py-0.5 text-[11px] font-black uppercase tracking-wider text-white">Muy pronto</span>
            En el App Store
          </motion.span>

          <motion.h1
            {...entrada(0.08)}
            className="text-[clamp(2.9rem,10vw,5.5rem)] font-black leading-[0.95] tracking-[-0.04em]"
          >
            Paga.
            <br />
            <span className="text-tomate">Rico se acuerda.</span>
          </motion.h1>

          <motion.p {...entrada(0.16)} className="max-w-md text-lg leading-relaxed text-tinta-suave sm:text-xl">
            Tu diario de restaurantes para iPhone. Pagas la cena, Rico te pregunta qué tal y lo valoras
            en diez segundos.
          </motion.p>

          <motion.div {...entrada(0.24)} className="mt-2 flex flex-col items-center gap-4 lg:items-start">
            <InsigniaAppStore />
            <a href={ENLACE_BETA} className="group inline-flex min-h-11 items-center gap-2 text-[15px] font-extrabold text-tomate-texto">
              ¿No puedes esperar? Entra en la beta
              <span aria-hidden className="transition-transform duration-500 ease-[cubic-bezier(0.32,0.72,0,1)] group-hover:translate-x-1">→</span>
            </a>
          </motion.div>
        </div>

        {/* El iPhone sobre un mantel de cuadros, con tarjetas de la app flotando alrededor. */}
        <motion.div
          initial={reducir ? false : { opacity: 0, y: 30 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 1.1, delay: 0.2, ease: MUELLE }}
          className="relative mx-auto grid w-full max-w-[480px] place-items-center"
        >
          <div aria-hidden className="vichy absolute -inset-x-[15%] -inset-y-[8%] [mask-image:radial-gradient(closest-side,#000_35%,transparent_100%)]" />
          <div aria-hidden className="absolute aspect-square w-[75%] rounded-full bg-[radial-gradient(circle,rgba(210,56,31,0.22),rgba(240,162,2,0.12)_50%,transparent_72%)] blur-2xl" />

          <div className="relative w-[min(62vw,290px)] py-4">
            <Iphone>
              <Captura nombre="diario" alt="El diario de Rico con tus últimas visitas" prioridad />
              <Isla />
            </Iphone>
          </div>

          <Flotante className="left-0 top-[22%] sm:-left-[4%]" retraso="0s">
            <span className="flex flex-col gap-1">
              <Estrellas />
              <span className="text-[15px] font-black leading-tight">Pulpo á feira</span>
              <span className="text-xs font-bold text-tinta-suave">Volvería · 32 €</span>
            </span>
          </Flotante>

          <Flotante className="right-0 top-[48%] sm:-right-[2%]" retraso="-2.5s">
            <span className="flex items-center gap-2.5">
              <span className="grid size-9 place-items-center rounded-full bg-[#B02A17] text-[13px] font-black text-white">4,5</span>
              <span className="flex flex-col leading-tight">
                <span className="text-[14px] font-black">+1 en tu mapa</span>
                <span className="text-xs font-bold text-tinta-suave">Taberna O Grelo</span>
              </span>
            </span>
          </Flotante>

          <Flotante className="bottom-[10%] left-[2%] hidden sm:block" retraso="-5s">
            <span className="flex flex-col leading-tight">
              <span className="text-[11px] font-extrabold uppercase tracking-wider text-tinta-suave">Este mes</span>
              <span className="text-[17px] font-black">6 sitios · 334 €</span>
            </span>
          </Flotante>
        </motion.div>
      </div>
    </section>
  )
}
