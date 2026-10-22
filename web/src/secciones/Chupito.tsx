import { BouncyAccordion, type BouncyAccordionItem } from '@/components/motion/bouncy-accordion'
import { CabeceraSeccion } from '@/componentes/Plato'
import { ENLACE_BETA } from '@/config'

const PREGUNTAS: BouncyAccordionItem[] = [
  {
    id: 'android',
    title: '¿Hay versión para Android?',
    description: 'De momento solo iPhone. Si la beta va bien, Android es lo siguiente.',
  },
  {
    id: 'banco',
    title: '¿Rico ve mi banco o mis tarjetas?',
    description:
      'No. Con la automatización de Atajos, el iPhone le pasa a Rico solo el nombre del comercio y el importe de cada pago. Rico no ve tu banco, tu saldo ni tus otros movimientos.',
  },
  {
    id: 'efectivo',
    title: '¿Y si pago en efectivo o invita otro?',
    description:
      'Activa «Detectar comidas por ubicación»: si pasas más de 40 minutos en un restaurante, Rico te pregunta al salir. También puedes apuntar cualquier visita a mano.',
  },
  {
    id: 'bateria',
    title: '¿Gasta mucha batería?',
    description:
      'No. Usa las visitas de iOS, el mismo sistema que «Lugares importantes»: el iPhone agrupa los datos y despierta a Rico solo cuando sales de un sitio.',
  },
  {
    id: 'reseñas',
    title: '¿Mis valoraciones son públicas?',
    description: 'No. Rico es un diario privado. Nadie ve lo que apuntas salvo que lo compartas tú.',
  },
  {
    id: 'beta',
    title: '¿Cómo entro en la beta?',
    description: 'Toca «Prueba la beta», instala TestFlight (la app de Apple para betas) y desde ahí instalas Rico. Es gratis.',
  },
]

export function Chupito() {
  return (
    <section className="mx-auto flex max-w-3xl flex-col gap-10 px-[max(1.25rem,env(safe-area-inset-left))] py-24">
      <CabeceraSeccion plato="Chupito" titulo="Lo que nos preguntáis" centrada />
      <BouncyAccordion
        items={PREGUNTAS}
        defaultValue="banco"
        classNames={{
          title: 'text-lg font-extrabold text-rico-tinta',
          description: 'text-base text-rico-secundario',
        }}
      />
      <div className="mt-8 flex flex-col items-center gap-5 rounded-[2rem] bg-rico-tomate px-6 py-12 text-center text-rico-sobre-tomate">
        <img src="/marca/icono.png" alt="" className="size-16 rounded-2xl shadow-lg" />
        <p className="text-3xl font-black leading-tight sm:text-4xl">¿Te apuntas a la sobremesa?</p>
        <p className="max-w-md text-lg opacity-90">La beta es gratis. Tu próxima cena ya puede quedar apuntada.</p>
        <a
          href={ENLACE_BETA}
          className="inline-flex min-h-14 items-center rounded-full bg-rico-sobre-tomate px-8 text-lg font-black text-rico-tomate transition-transform hover:-translate-y-0.5"
        >
          Prueba la beta
        </a>
      </div>
    </section>
  )
}
