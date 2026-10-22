import type { ReactNode } from 'react'
import { motion, useReducedMotion } from 'motion/react'
import { Aparecer, Titular } from '@/componentes/Piezas'
import { cn } from '@/lib/utils'

/** Tarjeta de doble bisel: bandeja exterior y núcleo interior con radios concéntricos. */
function Tarjeta({ children, className, retraso = 0 }: { children: ReactNode; className?: string; retraso?: number }) {
  return (
    <Aparecer retraso={retraso} className={cn('rounded-[2.25rem] bg-white/55 p-1.5 ring-1 ring-hilo', className)}>
      <div className="relative flex h-full flex-col overflow-hidden rounded-[calc(2.25rem-0.375rem)] bg-superficie shadow-[inset_0_1px_1px_rgba(255,255,255,0.9),0_30px_60px_-45px_rgba(90,40,15,0.45)]">
        {children}
      </div>
    </Aparecer>
  )
}

/** Trozo de una captura de la app, fundido por abajo. */
function Recorte({ nombre, alt, posicion = 'top', className }: { nombre: string; alt: string; posicion?: string; className?: string }) {
  return (
    <div className={cn('relative overflow-hidden', className)}>
      <img
        src={`/capturas/${nombre}.webp`}
        alt={alt}
        loading="lazy"
        decoding="async"
        className="absolute inset-0 h-full w-full object-cover"
        style={{ objectPosition: posicion }}
      />
      <div aria-hidden className="absolute inset-x-0 bottom-0 h-1/2 bg-gradient-to-t from-superficie to-transparent" />
    </div>
  )
}

function Texto({ titulo, children }: { titulo: string; children: ReactNode }) {
  return (
    <div className="relative flex flex-col gap-2 px-7 pb-8 text-center">
      <h3 className="text-[1.65rem] font-black leading-tight tracking-[-0.02em]">{titulo}</h3>
      <p className="mx-auto max-w-sm text-tinta-suave">{children}</p>
    </div>
  )
}

const PINES = [
  { fondo: '#B02A17', texto: '#fff', nota: '4,8', nombre: 'Imprescindible' },
  { fondo: '#EE8A3C', texto: '#1F1A16', nota: '3,9', nombre: 'Muy bien' },
  { fondo: '#8E8379', texto: '#1F1A16', nota: '2,5', nombre: 'Normalito' },
]

function Ondas() {
  const reducir = useReducedMotion()
  return (
    <div aria-hidden className="relative grid h-56 place-items-center">
      {[0, 1, 2].map((i) => (
        <motion.span
          key={i}
          className="absolute size-24 rounded-full border-2 border-albahaca/40"
          animate={reducir ? undefined : { scale: [1, 2.4], opacity: [0.7, 0] }}
          transition={{ duration: 2.8, repeat: Infinity, delay: i * 0.9, ease: [0.22, 1, 0.36, 1] }}
        />
      ))}
      <span className="relative grid size-20 place-items-center rounded-full bg-albahaca text-mantel shadow-[0_18px_40px_-14px_rgba(63,90,48,0.7)]">
        <svg viewBox="0 0 24 24" className="size-9" aria-hidden>
          <path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11zM12 12.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5z" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" />
        </svg>
      </span>
      <span className="absolute right-[18%] top-[18%] rounded-full bg-tinta px-3 py-1 text-sm font-black text-mantel">+40 min</span>
    </div>
  )
}

const PENDIENTES = [
  { nombre: 'Mesón A Lareira', detalle: 'Te lo dijo Marta · Cangas' },
  { nombre: 'O Fogón de Rosa', detalle: 'Lo viste en TikTok · Vigo' },
  { nombre: 'Casa Pepe', detalle: 'Croquetas · Ourense' },
]

/** Mini lista «Quiero probar», dibujada como en la app. */
function QuieroProbar() {
  return (
    <div aria-hidden className="flex flex-col gap-2 px-5 pb-2 pt-6">
      {PENDIENTES.map((sitio, i) => (
        <div
          key={sitio.nombre}
          className="flex items-center gap-3 rounded-2xl bg-mantel px-3 py-2.5 ring-1 ring-hilo"
          style={{ transform: `translateX(${i * 10}px)`, opacity: 1 - i * 0.18 }}
        >
          <span className="grid size-9 shrink-0 place-items-center rounded-full border-[2.5px] border-[#2F6FA8] bg-white text-[#2F6FA8]">
            <svg viewBox="0 0 24 24" className="size-4">
              <path d="M7 3.5h10v17l-5-3.3-5 3.3z" fill="currentColor" />
            </svg>
          </span>
          <span className="flex min-w-0 flex-col leading-tight">
            <span className="truncate text-[15px] font-black">{sitio.nombre}</span>
            <span className="truncate text-xs font-bold text-tinta-suave">{sitio.detalle}</span>
          </span>
        </div>
      ))}
    </div>
  )
}

export function Bento() {
  return (
    <section className="mx-auto flex max-w-6xl flex-col gap-14 px-4 py-20 sm:px-8 sm:py-28">
      <Titular etiqueta="Segundo · Todo en un sitio" centrado entradilla="Lo que antes estaba repartido entre notas, capturas y fotos, en una app que es solo tuya.">
        Tu vida comiendo fuera, <span className="text-tomate">ordenada.</span>
      </Titular>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-6 md:gap-5">
        <Tarjeta className="md:col-span-4 md:row-span-2">
          <Recorte nombre="mapa" alt="El mapa de Rico con tus sitios en Vigo" posicion="50% 30%" className="h-[300px] md:h-auto md:min-h-[320px] md:flex-1" />
          <div className="relative -mt-14 flex flex-col items-center gap-5 pb-8">
            <div className="flex flex-wrap justify-center gap-2" aria-hidden>
              {PINES.map((pin) => (
                <span key={pin.nombre} className="flex items-center gap-2 rounded-full bg-white py-1 pl-1 pr-3 text-sm font-extrabold shadow-[0_8px_20px_-12px_rgba(90,40,15,0.5)] ring-1 ring-hilo">
                  <span className="grid size-7 place-items-center rounded-full text-xs font-black" style={{ background: pin.fondo, color: pin.texto }}>
                    {pin.nota}
                  </span>
                  {pin.nombre}
                </span>
              ))}
            </div>
            <Texto titulo="Tu ciudad, pintada con tus notas">
              Cada sitio cae en el mapa con su color. De un vistazo sabes dónde llevar a tus padres el
              domingo y dónde no volver.
            </Texto>
          </div>
        </Tarjeta>

        <Tarjeta className="md:col-span-2" retraso={0.1}>
          <QuieroProbar />
          <Texto titulo="«Quiero probar»">Lo que te recomiendan, guardado con su sitio en el mapa.</Texto>
        </Tarjeta>

        <Tarjeta className="md:col-span-2" retraso={0.15}>
          <Ondas />
          <Texto titulo="Sin Apple Pay, también">
            Si pasas 40 minutos en un restaurante, Rico te pregunta al salir. Para el efectivo y cuando invita otro.
          </Texto>
        </Tarjeta>

        <Tarjeta className="md:col-span-3" retraso={0.1}>
          <Recorte nombre="ficha" alt="La ficha de un restaurante con sus visitas y platos" posicion="50% 45%" className="h-72" />
          <Texto titulo="Qué pediste y cuánto costó">
            Platos, fotos, con quién fuiste y el gasto por persona. Para repetir lo bueno.
          </Texto>
        </Tarjeta>

        <Tarjeta className="md:col-span-3" retraso={0.15}>
          <div className="grid h-64 place-items-center">
            <div className="flex flex-col items-center gap-3">
              <span className="grid size-20 place-items-center rounded-[1.6rem] bg-tinta text-mantel shadow-[0_20px_40px_-18px_rgba(31,26,22,0.7)]">
                <svg viewBox="0 0 24 24" className="size-9" aria-hidden>
                  <path d="M7 10.5V8a5 5 0 0 1 10 0v2.5M6 10.5h12a1.5 1.5 0 0 1 1.5 1.5v7A1.5 1.5 0 0 1 18 20.5H6A1.5 1.5 0 0 1 4.5 19v-7A1.5 1.5 0 0 1 6 10.5z" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" />
                </svg>
              </span>
              <span className="flex flex-wrap justify-center gap-2 px-4 text-sm font-extrabold">
                <span className="rounded-full bg-mantel-hondo px-3 py-1">Sin anuncios</span>
                <span className="rounded-full bg-mantel-hondo px-3 py-1">Servidores en la UE</span>
                <span className="rounded-full bg-mantel-hondo px-3 py-1">Privado</span>
              </span>
            </div>
          </div>
          <Texto titulo="Tu diario es solo tuyo">
            Primero en tu iPhone y sin conexión. Tus valoraciones no son públicas y tu ubicación no sale del móvil.
          </Texto>
        </Tarjeta>
      </div>
    </section>
  )
}
