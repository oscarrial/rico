import { useLayoutEffect, useRef, useState, type ReactNode } from 'react'
import {
  motion,
  useAnimationFrame,
  useInView,
  useMotionValue,
  useReducedMotion,
  useTransform,
  type MotionValue,
} from 'motion/react'
import { Estrellas, InsigniaAppStore } from '@/componentes/Piezas'
import { ENLACE_BETA } from '@/config'

const MUELLE = [0.32, 0.72, 0, 1] as const

/** Tarjetas por segundo que avanza el arco. */
const VELOCIDAD = 0.22

// MARK: Tarjetas del arco

/** Pantalla real de la app, recortada por arriba. */
function TarjetaPantalla({ nombre, alt }: { nombre: string; alt: string }) {
  return (
    <div className="h-full w-full overflow-hidden rounded-[1.5rem] bg-superficie shadow-[0_24px_50px_-28px_rgba(90,40,15,0.55)] ring-1 ring-black/5">
      <img src={`/capturas/${nombre}.webp`} alt={alt} loading="eager" decoding="async" className="h-full w-full object-cover object-[50%_8%]" />
    </div>
  )
}

/** Visita del diario, como las tarjetas de la app: color del sitio, plato, nombre y nota. */
function TarjetaVisita({ color, plato, sitio, ciudad, nota }: { color: string; plato: string; sitio: string; ciudad: string; nota: string }) {
  return (
    <div className="flex h-full w-full flex-col overflow-hidden rounded-[1.5rem] bg-superficie shadow-[0_24px_50px_-28px_rgba(90,40,15,0.55)] ring-1 ring-black/5">
      <div className="relative flex-[1.6]" style={{ background: color }}>
        <svg viewBox="0 0 24 24" className="absolute left-1/2 top-1/2 size-[22%] -translate-x-1/2 -translate-y-1/2 text-white/45" aria-hidden>
          <path d="M6 3v7a2 2 0 0 0 2 2v9M10 3v7a2 2 0 0 1-2 2M8 3v6M16 21V3c2.2 1.2 3 4 3 7s-1.2 4-3 4" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
        <span className="absolute bottom-[8%] left-[7%] max-w-[86%] truncate rounded-full bg-white px-[0.6em] py-[0.2em] text-[clamp(9px,0.78vw,12px)] font-black text-tinta">
          {plato}
        </span>
      </div>
      <div className="flex flex-1 flex-col justify-center gap-[3%] px-[8%]">
        <span className="truncate text-[clamp(11px,0.95vw,15px)] font-black leading-tight">{sitio}</span>
        <span className="flex items-center justify-between gap-1 text-[clamp(9px,0.75vw,12px)] font-bold text-tinta-suave">
          {ciudad}
          <span className="flex items-center gap-0.5 font-black text-tinta">
            <svg viewBox="0 0 24 24" className="size-[1.1em]" aria-hidden>
              <path d="M12 2.6l2.8 5.8 6.3.9-4.6 4.4 1.1 6.3L12 17l-5.6 3 1.1-6.3-4.6-4.4 6.3-.9z" fill="#F0A202" />
            </svg>
            {nota}
          </span>
        </span>
      </div>
    </div>
  )
}

const TARJETAS: ReactNode[] = [
  <TarjetaVisita color="#B98A55" plato="Pulpo á feira" sitio="Taberna O Grelo" ciudad="Vigo" nota="4,5" />,
  <TarjetaPantalla nombre="valorar" alt="Valorar una visita en Rico" />,
  <TarjetaVisita color="#C9573A" plato="Vieira con tupinambo" sitio="Maruja Limón" ciudad="Vigo" nota="5" />,
  <TarjetaPantalla nombre="mapa" alt="El mapa de Rico" />,
  <TarjetaVisita color="#7B5A8C" plato="Croquetas de jamón" sitio="Casa Pepe" ciudad="Ourense" nota="4" />,
  <TarjetaPantalla nombre="diario" alt="El diario de Rico" />,
  <TarjetaVisita color="#5F7F4E" plato="Zamburiñas" sitio="Mesón A Lareira" ciudad="Cangas" nota="4,8" />,
  <TarjetaPantalla nombre="resumen" alt="El resumen del mes en Rico" />,
  <TarjetaVisita color="#4F7CA8" plato="Tortilla poco hecha" sitio="Bar Ramón" ciudad="Santiago" nota="4,2" />,
  <TarjetaPantalla nombre="ficha" alt="La ficha de un restaurante en Rico" />,
  <TarjetaVisita color="#D08A2E" plato="Tarta de Santiago" sitio="O Fogón de Rosa" ciudad="Vigo" nota="4,6" />,
  <TarjetaPantalla nombre="listas" alt="Las listas de Rico" />,
]

// MARK: Arco

/** Una tarjeta en la pared interior de un cilindro: las del borde, más grandes y giradas hacia dentro. */
function EnArco({
  avance,
  indice,
  total,
  ancho,
  alto,
  paso,
  children,
}: {
  avance: MotionValue<number>
  indice: number
  total: number
  ancho: number
  alto: number
  paso: number
  children: ReactNode
}) {
  // Desplazamiento más cercano, para que el arco dé la vuelta sin saltos.
  const desfase = useTransform(avance, (a) => {
    let o = indice - a
    o -= Math.round(o / total) * total
    return o
  })
  const x = useTransform(desfase, (o) => o * paso)
  const giro = useTransform(desfase, (o) => Math.max(-55, Math.min(55, -o * 12)))
  const escala = useTransform(desfase, (o) => 1 + Math.min(Math.abs(o), 4.5) * 0.075)

  return (
    <motion.div
      className="absolute left-1/2 top-1/2"
      style={{ x, rotateY: giro, scale: escala, width: ancho, height: alto, marginLeft: -ancho / 2, marginTop: -alto / 2 }}
    >
      {children}
    </motion.div>
  )
}

/** Arco de tarjetas que pasa solo, como las paredes de un cilindro. No captura el dedo: la página sigue bajando. */
function Arco() {
  const reducir = useReducedMotion()
  const caja = useRef<HTMLDivElement>(null)
  const visible = useInView(caja)
  const [anchoCaja, setAnchoCaja] = useState(0)
  const avance = useMotionValue(0.5)

  useLayoutEffect(() => {
    const nodo = caja.current
    if (!nodo) return
    const medir = () => setAnchoCaja(nodo.clientWidth)
    medir()
    const observador = new ResizeObserver(medir)
    observador.observe(nodo)
    return () => observador.disconnect()
  }, [])

  useAnimationFrame((_, delta) => {
    if (reducir || !visible) return
    avance.set(avance.get() + (delta / 1000) * VELOCIDAD)
  })

  const ancho = Math.round(Math.max(118, Math.min(200, anchoCaja / 6.4)))
  const alto = Math.round(ancho * 1.38)
  const paso = ancho * 1.12

  return (
    <div
      ref={caja}
      aria-hidden
      className="pointer-events-none relative w-full overflow-hidden [perspective:1100px]"
      style={{ height: alto * 1.45 }}
    >
      {anchoCaja > 0
        ? TARJETAS.map((tarjeta, i) => (
            <EnArco key={i} avance={avance} indice={i} total={TARJETAS.length} ancho={ancho} alto={alto} paso={paso}>
              {tarjeta}
            </EnArco>
          ))
        : null}
    </div>
  )
}

// MARK: Notas a mano

function NotaAMano({ children, className, flecha, retraso }: { children: ReactNode; className: string; flecha: string; retraso: number }) {
  const reducir = useReducedMotion()
  return (
    <motion.div
      aria-hidden
      className={`pointer-events-none absolute flex flex-col items-center font-mano text-[26px] font-bold leading-[0.95] text-tomate-texto ${className}`}
      initial={reducir ? false : { opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ delay: retraso, duration: 0.6 }}
    >
      <span className="-rotate-6 whitespace-pre text-center">{children}</span>
      <svg viewBox="0 0 80 60" className="h-[52px] w-[70px]" fill="none">
        <motion.path
          d={flecha}
          stroke="currentColor"
          strokeWidth="2.2"
          strokeLinecap="round"
          strokeLinejoin="round"
          initial={reducir ? false : { pathLength: 0 }}
          animate={{ pathLength: 1 }}
          transition={{ delay: retraso + 0.2, duration: 0.9, ease: MUELLE }}
        />
      </svg>
    </motion.div>
  )
}

// MARK: Hero

export function Hero() {
  const reducir = useReducedMotion()
  const entrada = (retraso: number) => ({
    initial: reducir ? false : { opacity: 0, y: 14 },
    animate: { opacity: 1, y: 0 },
    transition: { duration: 0.8, delay: retraso, ease: MUELLE },
  })

  return (
    <section className="relative overflow-hidden pb-16 pt-28 sm:pt-36">
      <div className="relative mx-auto flex max-w-4xl flex-col items-center gap-6 px-5 text-center">
        <motion.span
          {...entrada(0)}
          className="inline-flex items-center gap-2.5 rounded-full bg-tomate-suave py-1.5 pl-1.5 pr-4 text-[13px] font-extrabold text-tomate-texto"
        >
          <span className="rounded-full bg-tomate px-2.5 py-0.5 text-[11px] font-black uppercase tracking-wider text-white">Muy pronto</span>
          En el App Store, para iPhone
        </motion.span>

        <motion.h1 {...entrada(0.08)} className="text-[clamp(2.75rem,7.5vw,5.25rem)] font-black leading-[0.98] tracking-[-0.04em]">
          Paga. <span className="text-tomate">Rico se acuerda.</span>
        </motion.h1>

        <motion.p {...entrada(0.16)} className="max-w-xl text-lg leading-relaxed text-tinta-suave sm:text-xl">
          Tu diario de restaurantes. Pagas la cena, Rico te pregunta qué tal y lo valoras en diez
          segundos. Nunca más un sitio olvidado.
        </motion.p>

        <NotaAMano className="-right-32 top-[44%] hidden xl:flex" flecha="M62 6 C 70 26, 58 44, 22 50 M30 42 L 20 50 L 31 56" retraso={0.9}>
          {'en diez\nsegundos'}
        </NotaAMano>
      </div>

      <motion.div {...entrada(0.3)} className="mt-6 sm:mt-10">
        <Arco />
      </motion.div>

      <motion.div {...entrada(0.4)} className="relative mx-auto mt-4 flex max-w-4xl flex-col items-center gap-4 px-5">
        <InsigniaAppStore />
        <a href={ENLACE_BETA} className="group inline-flex min-h-11 items-center gap-2 text-[15px] font-extrabold text-tomate-texto">
          ¿No puedes esperar? Entra en la beta
          <span aria-hidden className="transition-transform duration-500 ease-[cubic-bezier(0.32,0.72,0,1)] group-hover:translate-x-1">→</span>
        </a>
        <span className="flex items-center gap-2 text-sm font-bold text-tinta-suave">
          <Estrellas />
          Sin anuncios · Tus datos en la UE
        </span>

        <NotaAMano className="left-[6%] -top-2 hidden md:flex" flecha="M10 8 C 6 30, 24 46, 62 44 M52 36 L 63 44 L 52 51" retraso={1.2}>
          {'¡y gratis!'}
        </NotaAMano>
      </motion.div>
    </section>
  )
}
