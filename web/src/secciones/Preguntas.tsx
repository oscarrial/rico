import { BouncyAccordion, type BouncyAccordionItem } from '@/components/motion/bouncy-accordion'
import { Aparecer, Titular } from '@/componentes/Piezas'

const PREGUNTAS: BouncyAccordionItem[] = [
  {
    id: 'cuando',
    title: '¿Cuándo sale?',
    description: 'Muy pronto en el App Store. Mientras tanto puedes probar la beta gratis con TestFlight, la app de Apple para betas.',
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
    description: 'No. Usa las visitas de iOS: el iPhone agrupa los datos y despierta a Rico solo cuando sales de un sitio.',
  },
  {
    id: 'android',
    title: '¿Hay versión para Android?',
    description: 'De momento solo iPhone, con iOS 17 o posterior.',
  },
  {
    id: 'publico',
    title: '¿Mis valoraciones son públicas?',
    description: 'No. Rico es un diario privado: nadie ve lo que apuntas.',
  },
]

export function Preguntas() {
  return (
    <section id="preguntas" className="mx-auto flex max-w-3xl flex-col gap-12 px-5 py-28 sm:px-8 sm:py-36">
      <Titular etiqueta="Chupito" centrado>
        Lo que nos preguntáis
      </Titular>
      <Aparecer className="rounded-[2.25rem] bg-white/55 p-1.5 ring-1 ring-hilo">
        <div className="rounded-[calc(2.25rem-0.375rem)] bg-superficie px-2 py-2 sm:px-4">
          <BouncyAccordion
            items={PREGUNTAS}
            defaultValue="cuando"
            classNames={{
              title: 'text-lg font-extrabold text-tinta',
              description: 'text-base font-semibold text-tinta-suave',
            }}
          />
        </div>
      </Aparecer>
    </section>
  )
}
