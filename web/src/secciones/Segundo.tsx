import { motion, useReducedMotion } from 'motion/react'
import { CabeceraSeccion } from '@/componentes/Plato'
import { Iphone } from '@/componentes/Iphone'

/** Los colores de los pines del mapa, tal como salen en la app (DESIGN.md §3). */
const PINES = [
  { color: '#B02A17', texto: 'blanco', nota: '4,5+', nombre: 'Imprescindibles', detalle: 'Los que recomiendas sin pensar.' },
  { color: '#EE8A3C', texto: 'tinta', nota: '3,5', nombre: 'Muy bien', detalle: 'Para volver con calma.' },
  { color: '#8E8379', texto: 'tinta', nota: '2,8', nombre: 'Normalitos', detalle: 'Para acordarte de no repetir.' },
  { color: '#2F6FA8', texto: 'borde', nota: '', nombre: 'Quiero probar', detalle: 'Lo que te recomendaron, ya en su sitio.' },
]

function Pin({ color, texto, nota }: { color: string; texto: string; nota: string }) {
  if (texto === 'borde') {
    return (
      <span className="grid size-11 place-items-center rounded-full border-[3px] bg-white" style={{ borderColor: color, color }}>
        <svg viewBox="0 0 24 24" className="size-5" aria-hidden>
          <path fill="currentColor" d="M7 3.5h10v17l-5-3.2-5 3.2z" />
        </svg>
      </span>
    )
  }
  return (
    <span
      className="grid h-11 min-w-11 place-items-center rounded-full px-2 text-sm font-black tabular-nums shadow-md"
      style={{ background: color, color: texto === 'blanco' ? '#fff' : '#1F1A16' }}
    >
      {nota}
    </span>
  )
}

export function Segundo() {
  const reducir = useReducedMotion()
  return (
    <section className="mx-auto grid max-w-6xl items-center gap-14 px-[max(1.25rem,env(safe-area-inset-left))] py-24 lg:grid-cols-[0.9fr_1.1fr]">
      <div className="order-2 flex justify-center lg:order-1">
        <Iphone pantalla="mapa" alt="El mapa de Rico con los restaurantes de Vigo coloreados por nota" className="-rotate-[2deg]" />
      </div>
      <div className="order-1 flex flex-col gap-10 lg:order-2">
        <CabeceraSeccion plato="Segundo" titulo={<>Tu ciudad, <span className="text-rico-tomate">pintada con tus notas.</span></>}>
          Cada sitio que valoras cae en tu mapa con su color. De un vistazo sabes dónde llevar a
          tus padres el domingo y dónde no volver.
        </CabeceraSeccion>
        <ul className="grid gap-4 sm:grid-cols-2">
          {PINES.map((pin, i) => (
            <motion.li
              key={pin.nombre}
              className="flex items-center gap-4 rounded-2xl border border-rico-linea bg-rico-superficie p-4"
              initial={reducir ? false : { y: -36, opacity: 0 }}
              whileInView={{ y: 0, opacity: 1 }}
              viewport={{ once: true, amount: 0.6 }}
              transition={{ type: 'spring', bounce: 0.5, duration: 0.7, delay: i * 0.12 }}
            >
              <Pin color={pin.color} texto={pin.texto} nota={pin.nota} />
              <span className="flex flex-col">
                <span className="font-black">{pin.nombre}</span>
                <span className="text-sm text-rico-secundario">{pin.detalle}</span>
              </span>
            </motion.li>
          ))}
        </ul>
      </div>
    </section>
  )
}
