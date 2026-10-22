import { useEffect, useLayoutEffect, useRef, useState, type ReactNode } from 'react'
import {
  motion,
  useAnimationFrame,
  useInView,
  useMotionValue,
  useReducedMotion,
  useTransform,
  type MotionValue,
} from 'motion/react'
import { DynamicIsland, DynamicIslandView } from '@/components/motion/dynamic-island'
import { Iphone } from '@/componentes/Iphone'
import { Captura } from '@/componentes/Pantallas'
import { Estrellas, InsigniaAppStore } from '@/componentes/Piezas'
import { ENLACE_BETA } from '@/config'

const MUELLE = [0.32, 0.72, 0, 1] as const

/** Píxeles por segundo que avanza la cinta. */
const VELOCIDAD = 34

/**
 * Cada pago tal como lo escribe el banco y el recuerdo en que lo convierte Rico. Los nombres
 * raros son los mismos que reconoce la app (RicoCore, `LimpiadorComercio`).
 */
const PAGOS = [
  { banco: 'SUMUP *CAFE ALAMEDA', importe: '12,50', hora: '10:42', sitio: 'Café Alameda', plato: 'Tostada con tomate', nota: '4', color: '#D08A2E' },
  { banco: 'TABERNA O GRELO S.L.', importe: '52,00', hora: '22:07', sitio: 'Taberna O Grelo', plato: 'Pulpo á feira', nota: '4,5', color: '#B98A55' },
  { banco: 'TPV 0042 LA TRASTIENDA', importe: '35,00', hora: '14:31', sitio: 'La Trastienda', plato: 'Raxo con patatas', nota: '5', color: '#C9573A' },
  { banco: 'ZTL*MESON A LAREIRA', importe: '29,90', hora: '21:15', sitio: 'Mesón A Lareira', plato: 'Zamburiñas', nota: '4,8', color: '#5F7F4E' },
  { banco: 'REST CASA PEPE SL', importe: '48,00', hora: '15:02', sitio: 'Casa Pepe', plato: 'Croquetas', nota: '4,5', color: '#7B5A8C' },
  { banco: 'SQ *BAR RAMON 1987', importe: '18,40', hora: '13:20', sitio: 'Bar Ramón', plato: 'Tortilla poco hecha', nota: '4,2', color: '#4F7CA8' },
  { banco: 'PAYPAL *OFOGONROSA', importe: '41,20', hora: '21:48', sitio: 'O Fogón de Rosa', plato: 'Tarta de Santiago', nota: '4,6', color: '#A0524A' },
]

type Pago = (typeof PAGOS)[number]

// MARK: Ticket y recuerdo

/** El pago como sale del banco: ticket de papel térmico. */
function Ticket({ pago }: { pago: Pago }) {
  return (
    <div className="w-full drop-shadow-[0_14px_20px_rgba(90,40,15,0.18)]">
      <div className="whitespace-nowrap bg-papel px-3 pb-2.5 pt-3 font-ticket text-[10.5px] leading-snug text-tinta sm:text-[12px]">
        <p className="text-[9px] tracking-wider text-tinta-suave sm:text-[10px]">PAGO CON TARJETA</p>
        <p className="truncate font-bold">{pago.banco}</p>
        <p className="text-tinta-suave">21/10/26 {pago.hora}</p>
        <p className="mt-1.5 flex justify-between border-t border-dashed border-[#cfc3b6] pt-1.5 font-bold">
          <span>TOTAL</span>
          <span>{pago.importe} €</span>
        </p>
      </div>
      <div className="dientes h-2 bg-papel" />
    </div>
  )
}

/** Lo que queda en Rico: el sitio de verdad, el plato y la nota. */
function Recuerdo({ pago }: { pago: Pago }) {
  return (
    <div className="w-full overflow-hidden rounded-[1.1rem] bg-superficie shadow-[0_18px_36px_-20px_rgba(90,40,15,0.5)] ring-1 ring-black/5">
      <div className="relative h-11 sm:h-14" style={{ background: pago.color }}>
        <span className="absolute bottom-1.5 left-2 max-w-[90%] truncate rounded-full bg-white px-2 py-0.5 text-[10px] font-black text-tinta sm:text-[11px]">
          {pago.plato}
        </span>
      </div>
      <div className="flex flex-col gap-0.5 px-2.5 py-2">
        <span className="truncate text-[12px] font-black leading-tight sm:text-[14px]">{pago.sitio}</span>
        <span className="flex items-center justify-between text-[10px] font-bold text-tinta-suave sm:text-[11px]">
          Volvería
          <span className="flex items-center gap-0.5 font-black text-tinta">
            <svg viewBox="0 0 24 24" className="size-3" aria-hidden>
              <path d="M12 2.6l2.8 5.8 6.3.9-4.6 4.4 1.1 6.3L12 17l-5.6 3 1.1-6.3-4.6-4.4 6.3-.9z" fill="#F0A202" />
            </svg>
            {pago.nota}
          </span>
        </span>
      </div>
    </div>
  )
}

/**
 * Un pago en la cinta. Recorre la escena de izquierda a derecha: entra como ticket, pasa por
 * detrás del iPhone y sale como recuerdo. El cambio ocurre tapado por el iPhone.
 */
function EnCinta({
  avance,
  pago,
  indice,
  total,
  anchoEscena,
  anchoPieza,
  inclinacion,
  alturaY,
}: {
  avance: MotionValue<number>
  pago: Pago
  indice: number
  total: number
  anchoEscena: number
  anchoPieza: number
  inclinacion: number
  alturaY: number
}) {
  // Recorrido total: de un borde al otro, más una pieza a cada lado para entrar y salir sin verse.
  const recorrido = anchoEscena + anchoPieza * 2
  const x = useTransform(avance, (a) => {
    const posicion = (((a + (indice / total) * recorrido) % recorrido) + recorrido) % recorrido
    return posicion - recorrido / 2
  })
  const esTicket = useTransform(x, (px) => (px < 0 ? 1 : 0))
  const esRecuerdo = useTransform(x, (px) => (px < 0 ? 0 : 1))
  const giro = useTransform(x, (px) => (px < 0 ? inclinacion : -inclinacion * 0.6))

  return (
    <motion.div
      className="absolute left-1/2 top-1/2"
      style={{ x, y: alturaY, rotate: giro, width: anchoPieza, marginLeft: -anchoPieza / 2 }}
    >
      <motion.div style={{ opacity: esTicket }} className="absolute inset-x-0 top-0 -translate-y-1/2">
        <Ticket pago={pago} />
      </motion.div>
      <motion.div style={{ opacity: esRecuerdo }} className="absolute inset-x-0 top-0 -translate-y-1/2">
        <Recuerdo pago={pago} />
      </motion.div>
    </motion.div>
  )
}

// MARK: Dynamic Island

type Vista = 'pago' | 'pregunta' | null

const SECUENCIA: { vista: Vista; ms: number }[] = [
  { vista: null, ms: 1800 },
  { vista: 'pago', ms: 2600 },
  { vista: 'pregunta', ms: 3400 },
]

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
          <span className="ml-3 text-[18px] font-black tabular-nums">52,00 €</span>
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
                transition={{ delay: 0.5 + i * 0.2, type: 'spring', bounce: 0.45, duration: 0.6 }}
                aria-hidden
              >
                <path d="M12 2.6l2.8 5.8 6.3.9-4.6 4.4 1.1 6.3L12 17l-5.6 3 1.1-6.3-4.6-4.4 6.3-.9z" fill="#F5B331" />
              </motion.svg>
            ))}
          </span>
        </DynamicIslandView>
      </DynamicIsland>
    </div>
  )
}

// MARK: Escena

/** Tickets que entran por la izquierda, pasan por Rico y salen por la derecha como recuerdos. */
function Maquina() {
  const reducir = useReducedMotion()
  const escena = useRef<HTMLDivElement>(null)
  const visible = useInView(escena)
  const [ancho, setAncho] = useState(0)
  const avance = useMotionValue(0)

  useLayoutEffect(() => {
    const nodo = escena.current
    if (!nodo) return
    const medir = () => setAncho(nodo.clientWidth)
    medir()
    const observador = new ResizeObserver(medir)
    observador.observe(nodo)
    return () => observador.disconnect()
  }, [])

  useAnimationFrame((_, delta) => {
    if (reducir || !visible) return
    avance.set(avance.get() + (delta / 1000) * VELOCIDAD)
  })

  const movil = ancho < 640
  const anchoPieza = movil ? 128 : 178
  const anchoTelefono = movil ? 150 : 220
  // Tantos pagos como quepan con aire entre ellos.
  const total = Math.max(4, Math.min(PAGOS.length, Math.round((ancho + anchoPieza * 2) / (anchoPieza * 1.45))))
  const alturas = movil ? [-18, 14, -6, 20, -14, 8, -2] : [-26, 18, -8, 26, -20, 10, -4]
  const inclinaciones = [-4, 3, -2, 4, -3, 2, -1]

  return (
    <div ref={escena} className="relative w-full" style={{ height: movil ? 330 : 470 }}>
      <div aria-hidden className="absolute inset-0 overflow-hidden [mask-image:linear-gradient(90deg,transparent,#000_9%,#000_91%,transparent)]">
        {ancho > 0
          ? PAGOS.slice(0, total).map((pago, i) => (
              <EnCinta
                key={pago.banco}
                avance={avance}
                pago={pago}
                indice={i}
                total={total}
                anchoEscena={ancho}
                anchoPieza={anchoPieza}
                inclinacion={inclinaciones[i]}
                alturaY={alturas[i]}
              />
            ))
          : null}
      </div>

      {/* Rico en el centro: por detrás pasa todo. */}
      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2" style={{ width: anchoTelefono }}>
        <div aria-hidden className="absolute -inset-[30%] rounded-full bg-[radial-gradient(circle,rgba(251,246,240,1)_38%,rgba(251,246,240,0)_70%)]" />
        <div aria-hidden className="absolute -inset-[18%] rounded-full bg-[radial-gradient(circle,rgba(210,56,31,0.18),transparent_68%)] blur-xl" />
        <div className="relative">
          <Iphone>
            <Captura nombre="diario" alt="El diario de Rico" prioridad />
            <Isla />
          </Iphone>
        </div>
      </div>
    </div>
  )
}

// MARK: Notas a mano

function NotaAMano({ children, className, flecha, retraso, girada = -6 }: { children: ReactNode; className: string; flecha: string; retraso: number; girada?: number }) {
  const reducir = useReducedMotion()
  return (
    <motion.div
      aria-hidden
      className={`pointer-events-none flex gap-1 font-mano text-[21px] font-bold leading-[0.95] text-tomate-texto sm:text-[26px] ${className}`}
      initial={reducir ? false : { opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ delay: retraso, duration: 0.6 }}
    >
      <span className="max-w-[9.5rem] sm:max-w-none">{children}</span>
      <svg viewBox="0 0 80 60" className="h-[40px] w-[54px] shrink-0 sm:h-[48px] sm:w-[64px]" fill="none" style={{ rotate: `${girada}deg` }}>
        <motion.path
          d={flecha}
          stroke="currentColor"
          strokeWidth="2.4"
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
      <div className="mx-auto flex max-w-4xl flex-col items-center gap-6 px-5 text-center">
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
          Tu banco solo apunta números. Rico convierte cada pago en un recuerdo: el sitio, lo que
          pediste y qué tal estuvo, en diez segundos.
        </motion.p>
      </div>

      <motion.div {...entrada(0.3)} className="mt-2 sm:mt-4">
        <Maquina />
        <div className="mx-auto -mt-4 flex max-w-5xl justify-between px-4 sm:-mt-8 sm:px-10">
          <NotaAMano className="flex-col items-start sm:flex-row-reverse sm:items-center" flecha="M70 50 C 60 30, 40 18, 12 14 M22 6 L 11 14 L 22 22" retraso={1} girada={-10}>
            lo que dice tu banco
          </NotaAMano>
          <NotaAMano className="flex-col items-end sm:flex-row sm:items-center" flecha="M10 50 C 20 30, 40 18, 68 14 M58 6 L 69 14 L 58 22" retraso={1.3} girada={10}>
            lo que recuerdas tú
          </NotaAMano>
        </div>
      </motion.div>

      <motion.div {...entrada(0.4)} className="mx-auto mt-10 flex max-w-4xl flex-col items-center gap-4 px-5">
        <InsigniaAppStore />
        <a href={ENLACE_BETA} className="group inline-flex min-h-11 items-center gap-2 text-[15px] font-extrabold text-tomate-texto">
          ¿No puedes esperar? Entra en la beta
          <span aria-hidden className="transition-transform duration-500 ease-[cubic-bezier(0.32,0.72,0,1)] group-hover:translate-x-1">→</span>
        </a>
        <span className="flex items-center gap-2 text-sm font-bold text-tinta-suave">
          <Estrellas />
          Sin anuncios · Tus datos en la UE
        </span>
      </motion.div>
    </section>
  )
}
