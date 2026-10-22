import { useEffect, useRef, useState, type ReactNode } from 'react'
import { motion, useInView, useReducedMotion, useScroll, useTransform } from 'motion/react'
import { DynamicIsland, DynamicIslandView } from '@/components/motion/dynamic-island'
import { TextReveal } from '@/components/motion/text-reveal'
import { Iphone } from '@/componentes/Iphone'
import { Captura } from '@/componentes/Pantallas'
import { InsigniaAppStore } from '@/componentes/Piezas'
import { ENLACE_BETA } from '@/config'

const MUELLE = [0.32, 0.72, 0, 1] as const

type Vista = 'pago' | 'pregunta' | 'guardado' | null

/** Lo que pasa en el iPhone después de pagar, en bucle. */
const SECUENCIA: { vista: Vista; ms: number }[] = [
  { vista: null, ms: 1300 },
  { vista: 'pago', ms: 2600 },
  { vista: 'pregunta', ms: 3400 },
  { vista: 'guardado', ms: 2200 },
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
                initial={reducir ? false : { scale: 0.4, opacity: 0.25 }}
                animate={{ scale: 1, opacity: 1 }}
                transition={{ delay: 0.5 + i * 0.2, type: 'spring', bounce: 0.6, duration: 0.5 }}
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

/** Icono fino de 24 × 24. */
function Icono({ d, className }: { d: string; className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={className} aria-hidden>
      <path d={d} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

/** Lo que Rico junta en un solo sitio, como iconos de app que pasan por detrás del iPhone. */
const AZULEJOS: { fondo: string; color: string; icono: ReactNode }[] = [
  { fondo: '#1F1A16', color: '#FBF6F0', icono: <Icono d="M3.5 7.5A2.5 2.5 0 0 1 6 5h12a2.5 2.5 0 0 1 2.5 2.5v9A2.5 2.5 0 0 1 18 19H6a2.5 2.5 0 0 1-2.5-2.5zM3.5 10h17M7 15h3" className="size-[46%]" /> },
  { fondo: '#D2381F', color: '#FFFFFF', icono: <Icono d="M6 3v7a2 2 0 0 0 2 2v9M10 3v7a2 2 0 0 1-2 2M8 3v6M16 21V3c2.2 1.2 3 4 3 7s-1.2 4-3 4" className="size-[46%]" /> },
  { fondo: '#FFFFFF', color: '#F0A202', icono: <Icono d="M12 3.2l2.6 5.4 5.9.8-4.3 4.1 1 5.8L12 16.6l-5.2 2.7 1-5.8-4.3-4.1 5.9-.8z" className="size-[46%]" /> },
  { fondo: '#3F5A30', color: '#FBF6F0', icono: <Icono d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11zM12 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z" className="size-[46%]" /> },
  { fondo: '#F0A202', color: '#1F1A16', icono: <Icono d="M4 8.5A2.5 2.5 0 0 1 6.5 6h1.8l1.4-2h4.6l1.4 2h1.8A2.5 2.5 0 0 1 20 8.5v8a2.5 2.5 0 0 1-2.5 2.5h-11A2.5 2.5 0 0 1 4 16.5zM12 16a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7z" className="size-[46%]" /> },
  { fondo: '#FBE3DC', color: '#A8291A', icono: <Icono d="M7 3.5h10v17l-5-3.3-5 3.3z" className="size-[46%]" /> },
  { fondo: '#2F6FA8', color: '#FFFFFF', icono: <Icono d="M6 9a6 6 0 1 1 12 0c0 6 2.5 7.5 2.5 7.5h-17S6 15 6 9zM10 20a2.2 2.2 0 0 0 4 0" className="size-[46%]" /> },
  { fondo: '#FFFFFF', color: '#1F1A16', icono: <Icono d="M4 19V10M10 19V5M16 19v-7M21 19H3" className="size-[46%]" /> },
]

function FilaAzulejos() {
  const fila = [...AZULEJOS, ...AZULEJOS]
  return (
    <div aria-hidden className="pointer-events-none absolute inset-x-0 top-[30%] overflow-hidden [mask-image:linear-gradient(90deg,transparent,#000_12%,#000_88%,transparent)]">
      <div className="cinta flex w-max gap-5 sm:gap-8" style={{ ['--duracion' as string]: '45s' }}>
        {[...fila, ...fila].map((azulejo, i) => (
          <span
            key={i}
            className="grid size-[72px] place-items-center rounded-[22px] shadow-[0_18px_40px_-22px_rgba(80,40,15,0.55)] ring-1 ring-black/5 sm:size-[112px] sm:rounded-[30px]"
            style={{ background: azulejo.fondo, color: azulejo.color }}
          >
            {azulejo.icono}
          </span>
        ))}
      </div>
    </div>
  )
}

export function Hero() {
  const reducir = useReducedMotion()
  const escena = useRef<HTMLDivElement>(null)
  const { scrollYProgress } = useScroll({ target: escena, offset: ['start end', 'end start'] })
  const subeTelefono = useTransform(scrollYProgress, [0.3, 1], [0, reducir ? 0 : -70])

  return (
    <section className="relative overflow-hidden">
      {/* Luz cálida de vela sobre el mantel. */}
      <div aria-hidden className="pointer-events-none absolute inset-x-0 top-0 h-[120%] bg-[radial-gradient(60%_45%_at_50%_70%,rgba(210,56,31,0.16),transparent_70%),radial-gradient(40%_30%_at_15%_20%,rgba(240,162,2,0.12),transparent_70%)]" />

      <div className="relative mx-auto flex max-w-5xl flex-col items-center gap-7 px-5 pt-32 text-center sm:pt-40">
        <motion.span
          initial={reducir ? false : { opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, ease: MUELLE }}
          className="inline-flex items-center gap-2.5 rounded-full bg-white/85 py-1.5 pl-1.5 pr-4 text-[13px] font-extrabold shadow-[0_8px_24px_-14px_rgba(90,40,15,0.5)] ring-1 ring-hilo"
        >
          <span className="rounded-full bg-tomate px-2.5 py-0.5 text-[11px] font-black uppercase tracking-wider text-white">Muy pronto</span>
          En el App Store, para iPhone
        </motion.span>

        <h1 className="text-[clamp(3.4rem,13vw,8.5rem)] font-black leading-[0.88] tracking-[-0.045em]">
          <TextReveal text="Paga." className="block" />
          <TextReveal text="Rico se acuerda." className="block text-tomate" delay={0.2} />
        </h1>

        <motion.p
          initial={reducir ? false : { opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.9, delay: 0.45, ease: MUELLE }}
          className="max-w-xl text-[19px] leading-snug text-tinta-suave sm:text-[22px]"
        >
          Tu diario de restaurantes. Pagas la cena, Rico te pregunta qué tal y lo valoras en diez
          segundos. Se acabó el «¿cómo se llamaba aquel sitio?».
        </motion.p>

        <motion.div
          initial={reducir ? false : { opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.9, delay: 0.6, ease: MUELLE }}
          className="flex flex-col items-center gap-4"
        >
          <InsigniaAppStore grande />
          <a href={ENLACE_BETA} className="group inline-flex min-h-11 items-center gap-2 text-[15px] font-extrabold text-tomate-texto">
            ¿No puedes esperar? Entra en la beta
            <span aria-hidden className="transition-transform duration-500 ease-[cubic-bezier(0.32,0.72,0,1)] group-hover:translate-x-1">→</span>
          </a>
        </motion.div>
      </div>

      {/* El iPhone sale desde abajo y la línea del mantel lo corta, con los iconos pasando por detrás. */}
      <div ref={escena} className="relative mx-auto mt-14 h-[min(118vw,600px)] max-w-7xl overflow-hidden border-b border-hilo sm:mt-16">
        <FilaAzulejos />
        <motion.div
          initial={reducir ? false : { y: 160, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ type: 'spring', bounce: 0.22, duration: 1.5, delay: 0.35 }}
          className="relative mx-auto w-[min(76vw,360px)]"
        >
          <motion.div style={{ y: subeTelefono }}>
            {/* Halo del color del mantel para que los iconos «pasen por detrás». */}
            <div aria-hidden className="absolute -inset-x-8 inset-y-0 rounded-[4rem] bg-mantel/70 blur-2xl" />
            <Iphone>
              <Captura nombre="diario" alt="El diario de Rico con tus últimas visitas" prioridad />
              <Isla />
            </Iphone>
          </motion.div>
        </motion.div>
      </div>
    </section>
  )
}
