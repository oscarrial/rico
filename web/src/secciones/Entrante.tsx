import { useState } from 'react'
import { SwipeableList, type SwipeableListItem } from '@/components/motion/swipeable-list'
import { CabeceraSeccion } from '@/componentes/Plato'

const NOTAS: { id: string; titulo: string; detalle: string }[] = [
  { id: 'pulpo', titulo: 'El del pulpo que dijo Marta', detalle: '¿Cangas? ¿Moaña? · hace 8 meses' },
  { id: 'japo', titulo: 'Japo de la calle esa', detalle: 'Cerca del cine · sin nombre' },
  { id: 'croquetas', titulo: 'Croquetas BRUTALES', detalle: 'Ourense, creo · hace 1 año' },
  { id: 'terraza', titulo: 'Terraza con vistas (caro?)', detalle: 'Lo vi en un story · hace 3 meses' },
]

const icono = (d: string) => (
  <svg viewBox="0 0 24 24" className="size-5" aria-hidden>
    <path fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" d={d} />
  </svg>
)

export function Entrante() {
  const [rescatadas, setRescatadas] = useState<string[]>([])

  const items: SwipeableListItem[] = NOTAS.map((nota) => {
    const rescatada = rescatadas.includes(nota.id)
    return {
      id: nota.id,
      title: <span className={rescatada ? 'text-rico-verde' : undefined}>{nota.titulo}</span>,
      description: rescatada ? 'Guardado en Rico, con su sitio en el mapa' : nota.detalle,
      leading: (
        <span className="grid size-10 place-items-center rounded-xl bg-[#F7D774] text-[#5b4a12]">
          {icono('M7 4h10v16l-5-3-5 3z')}
        </span>
      ),
      rightActions: [
        { id: 'rico', label: 'A Rico', tone: 'primary', icon: icono('M5 12.5l4.5 4.5L19 7.5') },
      ],
    }
  })

  return (
    <section className="mx-auto grid max-w-6xl items-center gap-12 px-[max(1.25rem,env(safe-area-inset-left))] py-24 lg:grid-cols-2">
      <CabeceraSeccion plato="Entrante" titulo={<>200 sitios en las notas del móvil. <span className="text-rico-tomate">¿Cuáles te gustaron?</span></>}>
        Te recomiendan un sitio, lo apuntas «para luego» y al cabo de unos meses no sabes ni dónde
        era ni qué pediste. Las apps de reseñas son de todo el mundo; Rico es solo tuyo.
      </CabeceraSeccion>

      <div className="flex flex-col gap-3">
        <div className="rounded-[1.75rem] border border-rico-linea bg-rico-superficie p-2 shadow-[0_24px_60px_-40px_rgba(60,25,10,0.5)]">
          <p className="px-4 pb-1 pt-3 text-xs font-extrabold uppercase tracking-[0.14em] text-rico-secundario">
            Notas · Sitios para ir
          </p>
          <SwipeableList
            items={items}
            onAction={({ item }) => setRescatadas((r) => (r.includes(item.id) ? r : [...r, item.id]))}
            classNames={{ surface: 'bg-rico-superficie', title: 'font-extrabold', description: 'text-rico-secundario' }}
          />
        </div>
        <p className="text-center text-sm font-bold text-rico-secundario">
          Desliza una nota a la izquierda y rescátala.
        </p>
      </div>
    </section>
  )
}
