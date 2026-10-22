import { ScrollReveal } from '@/components/motion/scroll-reveal'
import { CabeceraSeccion } from '@/componentes/Plato'
import { Iphone } from '@/componentes/Iphone'

const PASOS = [
  {
    titulo: 'Pagas, como siempre',
    texto:
      'Con Apple Pay, Rico apunta la visita solo: sitio, día e importe. ¿Efectivo o invita otro? Rico nota que llevas un rato en un restaurante y te pregunta al salir.',
    visual: 'pago' as const,
  },
  {
    titulo: 'Te pregunta qué tal',
    texto: 'Un aviso un rato después, cuando ya estás en la sobremesa. Sin abrir la app ni buscar nada.',
    visual: 'aviso' as const,
  },
  {
    titulo: 'Valoras en diez segundos',
    texto: 'Estrellas, si volverías, qué pediste y una foto si quieres. Queda en tu diario para siempre.',
    visual: 'valorar' as const,
  },
]

function TarjetaPago() {
  return (
    <div className="mx-auto flex w-full max-w-[300px] flex-col gap-4 rounded-[2rem] bg-black p-6 text-white shadow-2xl">
      <div className="flex items-center justify-between text-sm font-bold text-white/60">
        <span>Wallet</span>
        <span>21:47</span>
      </div>
      <div className="aspect-[1.586] rounded-2xl bg-gradient-to-br from-[#2b2b2b] to-[#0f0f0f] p-4 ring-1 ring-white/10">
        <span className="text-xs font-bold text-white/50">Tarjeta</span>
      </div>
      <div className="flex flex-col items-center gap-1 py-2">
        <svg viewBox="0 0 24 24" className="size-12 text-[#7FD3A0]" aria-hidden>
          <circle cx="12" cy="12" r="10.5" fill="none" stroke="currentColor" strokeWidth="1.8" />
          <path fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round" d="M7.5 12.5l3 3 6-6.5" />
        </svg>
        <span className="text-lg font-black">Hecho</span>
        <span className="text-sm font-bold text-white/60">Taberna O Grelo · 48,00 €</span>
      </div>
    </div>
  )
}

function TarjetaAviso() {
  return (
    <div className="mx-auto w-full max-w-[340px] rounded-[1.6rem] border border-rico-linea bg-rico-superficie/90 p-4 shadow-[0_24px_60px_-30px_rgba(60,25,10,0.45)] backdrop-blur">
      <div className="flex items-start gap-3">
        <img src="/marca/icono.png" alt="" className="size-10 rounded-[0.7rem]" />
        <div className="flex min-w-0 flex-1 flex-col">
          <div className="flex items-center justify-between text-xs font-bold text-rico-secundario">
            <span className="uppercase tracking-wide">Rico</span>
            <span>hace 20 min</span>
          </div>
          <span className="font-black">¿Qué tal en Taberna O Grelo?</span>
          <span className="text-sm text-rico-secundario">Valóralo en diez segundos. 48,00 €</span>
        </div>
      </div>
    </div>
  )
}

export function Primero() {
  return (
    <section id="como-funciona" className="bg-rico-hundida/60 py-24">
      <div className="mx-auto flex max-w-6xl flex-col gap-16 px-[max(1.25rem,env(safe-area-inset-left))]">
        <CabeceraSeccion plato="Primero" titulo="Tres momentos. Tú solo pones las estrellas." />
        <ol className="grid gap-12 md:grid-cols-3 md:gap-8">
          {PASOS.map((paso, i) => (
            <li key={paso.titulo}>
              <ScrollReveal delay={i * 0.12} className="flex flex-col gap-6">
                <div className="flex min-h-[340px] items-center justify-center">
                  {paso.visual === 'pago' && <TarjetaPago />}
                  {paso.visual === 'aviso' && <TarjetaAviso />}
                  {paso.visual === 'valorar' && (
                    <Iphone pantalla="valorar" alt="La ficha de valoración de Rico con estrellas y fotos" className="max-w-[210px]" />
                  )}
                </div>
                <div className="flex gap-4">
                  <span className="grid size-10 shrink-0 place-items-center rounded-full bg-rico-tomate text-lg font-black text-rico-sobre-tomate">
                    {i + 1}
                  </span>
                  <div className="flex flex-col gap-1">
                    <h3 className="text-2xl font-black">{paso.titulo}</h3>
                    <p className="text-rico-secundario">{paso.texto}</p>
                  </div>
                </div>
              </ScrollReveal>
            </li>
          ))}
        </ol>
      </div>
    </section>
  )
}
