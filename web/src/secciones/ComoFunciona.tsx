import { useEffect, useRef, useState } from 'react'
import { motion, useInView, useReducedMotion } from 'motion/react'
import { Iphone } from '@/componentes/Iphone'
import { PantallaAviso, PantallaDiario, PantallaPago, PantallaValorar } from '@/componentes/Pantallas'
import { Titular } from '@/componentes/Piezas'
import { cn } from '@/lib/utils'

const PASOS = [
  { titulo: 'Pagas, como siempre', texto: 'Con Apple Pay, Rico apunta el sitio, el día y el importe sin que toques nada.' },
  { titulo: 'Te pregunta qué tal', texto: 'Un aviso un rato después, ya en la sobremesa. ¿Efectivo? Rico nota que llevas un rato en un restaurante y te pregunta al salir.' },
  { titulo: 'Valoras en diez segundos', texto: 'Estrellas, si volverías, qué pediste y una foto si quieres.' },
  { titulo: 'Y queda para siempre', texto: 'En tu diario, en tu mapa y en tu resumen del mes.' },
]

/** Cuánto se queda cada paso antes de pasar al siguiente. */
const DURACION = 5000

/**
 * Los cuatro pasos a un lado y el iPhone al otro. Avanzan solos mientras se ven y se pueden
 * tocar; no se secuestra el scroll.
 */
export function ComoFunciona() {
  const reducir = useReducedMotion()
  const seccion = useRef<HTMLElement>(null)
  const visible = useInView(seccion, { amount: 0.4 })
  const [paso, setPaso] = useState(0)
  const [automatico, setAutomatico] = useState(true)
  const avanza = visible && automatico && !reducir

  useEffect(() => {
    if (!avanza) return
    const reloj = setTimeout(() => setPaso((p) => (p + 1) % PASOS.length), DURACION)
    return () => clearTimeout(reloj)
  }, [paso, avanza])

  const pantallas = [
    <PantallaPago key="pago" />,
    <PantallaAviso key="aviso" activa={paso === 1} />,
    <PantallaValorar key="valorar" activa={paso === 2} />,
    <PantallaDiario key="diario" activa={paso === 3} />,
  ]

  return (
    <section id="como-funciona" ref={seccion} className="bg-mantel-hondo/60 py-20 sm:py-28">
      {/* En el móvil: titular, iPhone y pasos debajo, para ver la pantalla al tocar cada paso. */}
      <div className="mx-auto grid max-w-6xl items-center gap-8 px-5 sm:px-8 lg:grid-cols-[1fr_auto] lg:grid-rows-[auto_auto] lg:gap-x-20 lg:gap-y-8">
        <Titular etiqueta="Primero · Así funciona" className="order-1 lg:order-none lg:col-start-1 lg:row-start-1 lg:self-end">
          Tú solo pones las estrellas.
        </Titular>

          <ol className="order-3 flex flex-col gap-2 lg:order-none lg:col-start-1 lg:row-start-2 lg:self-start">
            {PASOS.map((p, i) => {
              const activo = i === paso
              return (
                <li key={p.titulo}>
                  <button
                    type="button"
                    aria-current={activo ? 'step' : undefined}
                    onClick={() => {
                      setPaso(i)
                      setAutomatico(false)
                    }}
                    className={cn(
                      'flex w-full items-start gap-4 rounded-[1.5rem] px-4 py-4 text-left transition-colors duration-500 ease-[cubic-bezier(0.32,0.72,0,1)]',
                      activo ? 'bg-superficie shadow-[0_20px_40px_-30px_rgba(90,40,15,0.45)] ring-1 ring-hilo' : 'hover:bg-white/50',
                    )}
                  >
                    <span
                      className={cn(
                        'grid size-9 shrink-0 place-items-center rounded-full text-[15px] font-black transition-colors duration-500',
                        activo ? 'bg-tomate text-white' : 'bg-tinta/[0.06] text-tinta-suave',
                      )}
                    >
                      {i + 1}
                    </span>
                    <span className="flex min-w-0 flex-1 flex-col gap-1 pt-1">
                      <span className={cn('text-xl font-black tracking-[-0.02em]', !activo && 'text-tinta-suave')}>{p.titulo}</span>
                      <motion.span
                        initial={false}
                        animate={{ height: activo ? 'auto' : 0, opacity: activo ? 1 : 0 }}
                        transition={{ duration: 0.45, ease: [0.32, 0.72, 0, 1] }}
                        className="overflow-hidden text-tinta-suave"
                      >
                        <span className="block pb-1">{p.texto}</span>
                        {/* Barra de tiempo del paso, solo mientras avanza solo. */}
                        <span className="mt-2 block h-1 overflow-hidden rounded-full bg-tinta/[0.07]">
                          {activo && avanza ? (
                            <motion.span
                              key={`barra-${paso}`}
                              className="block h-full origin-left rounded-full bg-tomate"
                              initial={{ scaleX: 0 }}
                              animate={{ scaleX: 1 }}
                              transition={{ duration: DURACION / 1000, ease: 'linear' }}
                            />
                          ) : null}
                        </span>
                      </motion.span>
                    </span>
                  </button>
                </li>
              )
            })}
          </ol>

        <div className="order-2 mx-auto w-[min(62vw,300px)] lg:order-none lg:col-start-2 lg:row-span-2 lg:row-start-1 lg:w-[300px]">
          <Iphone>
            {pantallas.map((pantalla, i) => (
              <motion.div
                key={i}
                className="absolute inset-0"
                initial={false}
                animate={{ opacity: i === paso ? 1 : 0 }}
                transition={{ duration: 0.5, ease: [0.32, 0.72, 0, 1] }}
                aria-hidden={i !== paso}
              >
                {pantalla}
              </motion.div>
            ))}
          </Iphone>
        </div>
      </div>
    </section>
  )
}
