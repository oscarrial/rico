import { memo, useEffect, useLayoutEffect, useRef, useState, type ReactNode } from 'react'
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
import { InsigniaAppStore } from '@/componentes/Piezas'
import { ENLACE_BETA } from '@/config'

const MUELLE = [0.32, 0.72, 0, 1] as const

/** Píxeles por segundo que avanza la cinta. */
const VELOCIDAD = 30

/** Alto / ancho del iPhone dibujado (ver `Iphone`). */
const PROPORCION_IPHONE = 2.087

/**
 * Cada pago tal como lo escribe el banco y el recuerdo en que lo convierte Rico. Los nombres
 * raros son del tipo que reconoce la app (RicoCore, `LimpiadorComercio`).
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
    <div className="w-full drop-shadow-[0_12px_18px_rgba(90,40,15,0.16)]">
      <div className="whitespace-nowrap bg-papel px-2.5 pb-2 pt-2.5 font-ticket text-[10px] leading-snug text-tinta sm:px-3 sm:text-[11.5px]">
        <p className="text-[8.5px] tracking-wider text-tinta-suave sm:text-[9.5px]">PAGO CON TARJETA</p>
        <p className="truncate font-bold">{pago.banco}</p>
        <p className="text-tinta-suave">21/10/26 {pago.hora}</p>
        <p className="mt-1 flex justify-between border-t border-dashed border-[#cfc3b6] pt-1 font-bold">
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
    <div className="w-full overflow-hidden rounded-[1rem] bg-superficie shadow-[0_16px_32px_-18px_rgba(90,40,15,0.45)] ring-1 ring-[#1f1a16]/5">
      <div className="relative h-9 sm:h-12" style={{ background: pago.color }}>
        <span className="absolute bottom-1 left-1.5 max-w-[92%] truncate rounded-full bg-white px-1.5 py-px text-[9px] font-black text-tinta sm:bottom-1.5 sm:left-2 sm:px-2 sm:text-[10.5px]">
          {pago.plato}
        </span>
      </div>
      <div className="flex flex-col px-2 py-1.5 sm:px-2.5 sm:py-2">
        <span className="truncate text-[11px] font-black leading-tight sm:text-[13px]">{pago.sitio}</span>
        <span className="flex items-center justify-between text-[9px] font-bold text-tinta-suave sm:text-[10.5px]">
          Volvería
          <span className="flex items-center gap-0.5 font-black text-tinta">
            <svg viewBox="0 0 24 24" className="size-2.5 sm:size-3" aria-hidden>
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
 * Un pago en la cinta. Cruza la escena de izquierda a derecha: entra como ticket, se funde al
 * llegar al iPhone y sale por el otro lado como recuerdo.
 */
function EnCinta({
  avance,
  pago,
  indice,
  total,
  anchoEscena,
  anchoPieza,
  anchoTelefono,
  inclinacion,
  alturaY,
}: {
  avance: MotionValue<number>
  pago: Pago
  indice: number
  total: number
  anchoEscena: number
  anchoPieza: number
  anchoTelefono: number
  inclinacion: number
  alturaY: number
}) {
  const recorrido = anchoEscena + anchoPieza * 2
  const x = useTransform(avance, (a) => {
    const posicion = (((a + (indice / total) * recorrido) % recorrido) + recorrido) % recorrido
    return posicion - recorrido / 2
  })
  // Se apaga al tocar el iPhone y se enciende al salir, para que el cambio no se vea.
  const borde = anchoTelefono / 2
  const visibilidad = useTransform(x, (px) => {
    const distancia = Math.abs(px) - borde
    return Math.max(0, Math.min(1, distancia / (anchoPieza * 0.55)))
  })
  const esTicket = useTransform(x, (px) => (px < 0 ? 1 : 0))
  const esRecuerdo = useTransform(x, (px) => (px < 0 ? 0 : 1))
  const giro = useTransform(x, (px) => (px < 0 ? inclinacion : -inclinacion * 0.6))

  return (
    <motion.div
      className="absolute left-1/2 top-1/2"
      style={{ x, y: alturaY, rotate: giro, opacity: visibilidad, width: anchoPieza, marginLeft: -anchoPieza / 2 }}
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

/** La Dynamic Island del iPhone central, a tamaño real sobre la captura. */
const Isla = memo(function Isla() {
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
                transition={{ delay: 0.5 + i * 0.2, type: 'spring', stiffness: 260, damping: 14 }}
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
})

// MARK: Máquina de recuerdos

/** Nota escrita a mano con su flecha, encima de cada carril. */
function NotaAMano({ children, lado, retraso }: { children: ReactNode; lado: 'izquierda' | 'derecha'; retraso: number }) {
  const reducir = useReducedMotion()
  const derecha = lado === 'derecha'
  return (
    <motion.div
      aria-hidden
      className={`pointer-events-none absolute top-[4%] flex items-end gap-0.5 font-mano text-[17px] font-bold leading-[0.95] text-tomate-texto sm:text-[23px] ${derecha ? 'right-[3%] flex-row-reverse text-right' : 'left-[3%]'}`}
      initial={reducir ? false : { opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: retraso, duration: 0.6, ease: MUELLE }}
    >
      <span className={`whitespace-pre-line ${derecha ? 'rotate-[4deg]' : '-rotate-[4deg]'}`}>{children}</span>
      <svg viewBox="0 0 40 40" className={`size-7 shrink-0 translate-y-3 sm:size-9 ${derecha ? '-scale-x-100' : ''}`} fill="none">
        <motion.path
          d="M6 6 C 18 8, 28 16, 30 32 M23 26 L 30 33 L 35 25"
          stroke="currentColor"
          strokeWidth="2.2"
          strokeLinecap="round"
          strokeLinejoin="round"
          initial={reducir ? false : { pathLength: 0 }}
          animate={{ pathLength: 1 }}
          transition={{ delay: retraso + 0.2, duration: 0.8, ease: MUELLE }}
        />
      </svg>
    </motion.div>
  )
}

/**
 * Tickets que entran por la izquierda, pasan por Rico y salen por la derecha como recuerdos.
 * Se ajusta al hueco que le deja el hero: el iPhone se dimensiona por el alto disponible.
 */
const Maquina = memo(function Maquina() {
  const reducir = useReducedMotion()
  const escena = useRef<HTMLDivElement>(null)
  const visible = useInView(escena)
  const [medidas, setMedidas] = useState({ ancho: 0, alto: 0 })
  const avance = useMotionValue(0)

  useLayoutEffect(() => {
    const nodo = escena.current
    if (!nodo) return
    const medir = () => setMedidas({ ancho: nodo.clientWidth, alto: nodo.clientHeight })
    medir()
    const observador = new ResizeObserver(medir)
    observador.observe(nodo)
    return () => observador.disconnect()
  }, [])

  useAnimationFrame((_, delta) => {
    if (reducir || !visible) return
    avance.set(avance.get() + (delta / 1000) * VELOCIDAD)
  })

  const { ancho, alto } = medidas
  const anchoTelefono = Math.round(Math.min(ancho * 0.36, (alto * 0.86) / PROPORCION_IPHONE, 250))
  const anchoPieza = Math.round(Math.max(112, Math.min(176, ((ancho - anchoTelefono) / 2) * 0.82)))
  const total = Math.max(4, Math.min(PAGOS.length, Math.round((ancho + anchoPieza * 2) / anchoPieza)))
  const escalaY = Math.min(1, alto / 480)
  const alturas = [-30, 22, -10, 30, -22, 12, -4].map((y) => y * escalaY)
  const inclinaciones = [-4, 3, -2, 4, -3, 2, -1]

  return (
    <div ref={escena} className="relative h-full min-h-[240px] w-full">
      {ancho > 0 ? (
        <>
          <div aria-hidden className="absolute inset-0 overflow-hidden [mask-image:linear-gradient(90deg,transparent,#000_8%,#000_92%,transparent)]">
            {PAGOS.slice(0, total).map((pago, i) => (
              <EnCinta
                key={pago.banco}
                avance={avance}
                pago={pago}
                indice={i}
                total={total}
                anchoEscena={ancho}
                anchoPieza={anchoPieza}
                anchoTelefono={anchoTelefono}
                inclinacion={inclinaciones[i]}
                alturaY={alturas[i]}
              />
            ))}
          </div>

          <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2" style={{ width: anchoTelefono }}>
            <div aria-hidden className="absolute -inset-[22%] rounded-full bg-[radial-gradient(circle,rgba(210,56,31,0.16),transparent_66%)] blur-2xl" />
            <div className="relative">
              <Iphone>
                <Captura nombre="diario" alt="El diario de Rico" prioridad />
                <Isla />
              </Iphone>
            </div>
          </div>

          <NotaAMano lado="izquierda" retraso={1}>
            {'lo que apunta\ntu banco'}
          </NotaAMano>
          <NotaAMano lado="derecha" retraso={1.3}>
            {'lo que\nrecuerdas tú'}
          </NotaAMano>
        </>
      ) : null}
    </div>
  )
})

// MARK: Hero

/**
 * Cabe entero en la pantalla, en el móvil y en el ordenador: texto y botones arriba (o a la
 * izquierda) y la máquina ocupa el hueco que queda.
 */
export function Hero() {
  const reducir = useReducedMotion()
  const entrada = (retraso: number) => ({
    initial: reducir ? false : { opacity: 0, y: 12 },
    animate: { opacity: 1, y: 0 },
    transition: { type: 'spring' as const, stiffness: 100, damping: 20, delay: retraso },
  })

  return (
    <section className="relative overflow-hidden">
      <div
        className="mx-auto grid h-[100svh] min-h-[600px] max-h-[980px] max-w-7xl grid-cols-1 grid-rows-[auto_minmax(0,1fr)_auto] gap-x-10 gap-y-3 px-4 pb-5 pt-[calc(env(safe-area-inset-top)+5.25rem)] sm:px-8 sm:pb-8 lg:grid-cols-[0.92fr_1.08fr] lg:grid-rows-[1fr_auto_auto_1fr] lg:gap-y-8 lg:pt-24"
      >
        <div className="flex flex-col gap-3 lg:col-start-1 lg:row-start-2 lg:gap-5">
          <motion.span
            {...entrada(0)}
            className="inline-flex w-max items-center gap-2 rounded-full bg-tomate-suave py-1 pl-1 pr-3.5 text-[12px] font-extrabold text-tomate-texto sm:text-[13px]"
          >
            <span className="rounded-full bg-tomate px-2 py-0.5 text-[10px] font-black uppercase tracking-wider text-white sm:text-[11px]">Muy pronto</span>
            En el App Store
          </motion.span>

          <motion.h1
            {...entrada(0.06)}
            className="text-[clamp(2.3rem,9.5vw,2.9rem)] font-black leading-[0.98] tracking-[-0.035em] sm:text-5xl lg:text-[clamp(3rem,4.6vw,4.4rem)]"
          >
            Paga.
            <br />
            <span className="text-tomate">Rico se acuerda.</span>
          </motion.h1>

          <motion.p {...entrada(0.12)} className="max-w-[46ch] text-[15px] leading-relaxed text-tinta-suave sm:text-lg">
            Tu banco solo apunta números. Rico convierte cada pago en un recuerdo: el sitio, lo que
            pediste y qué tal estuvo.
          </motion.p>
        </div>

        <motion.div
          initial={reducir ? false : { opacity: 0, scale: 0.97 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ type: 'spring', stiffness: 80, damping: 20, delay: 0.2 }}
          className="min-h-0 lg:col-start-2 lg:row-span-4 lg:row-start-1 lg:py-4"
        >
          <Maquina />
        </motion.div>

        <motion.div {...entrada(0.18)} className="flex flex-wrap items-center justify-between gap-x-6 gap-y-2 lg:col-start-1 lg:row-start-3 lg:justify-start">
          <InsigniaAppStore />
          <a href={ENLACE_BETA} className="group inline-flex min-h-11 items-center gap-1.5 text-[14px] font-extrabold text-tomate-texto sm:text-[15px]">
            ¿No puedes esperar? Entra en la beta
            <span aria-hidden className="transition-transform duration-500 ease-[cubic-bezier(0.32,0.72,0,1)] group-hover:translate-x-1">→</span>
          </a>
        </motion.div>
      </div>
    </section>
  )
}
