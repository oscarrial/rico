import { useRef } from 'react'
import { motion, useReducedMotion, useScroll, useTransform } from 'motion/react'

const PLATOS_1 = ['Pulpo á feira', 'Zamburiñas', 'Croquetas', 'Tortilla poco hecha', 'Navajas', 'Raxo']
const PLATOS_2 = ['Empanada de xoubas', 'Pimientos de Padrón', 'Filloas', 'Tarta de Santiago', 'Vieiras', 'Lacón']

function Fila({ platos, x, degradado = false }: { platos: string[]; x: ReturnType<typeof useTransform<number, string>>; degradado?: boolean }) {
  return (
    <motion.p
      style={{ x }}
      className="flex w-max items-center gap-6 whitespace-nowrap text-[clamp(3.4rem,11vw,9rem)] font-black leading-[1.02] tracking-[-0.04em] sm:gap-10"
    >
      {[...platos, ...platos].map((plato, i) => (
        <span key={i} className="flex items-center gap-6 sm:gap-10">
          <span
            className={
              degradado
                ? 'bg-gradient-to-r from-tomate via-[#e8642f] to-estrella bg-clip-text pb-2 text-transparent'
                : 'text-tinta'
            }
          >
            {plato}
          </span>
          <svg viewBox="0 0 24 24" className="size-[0.45em] shrink-0 text-estrella" aria-hidden>
            <path d="M12 2.6l2.8 5.8 6.3.9-4.6 4.4 1.1 6.3L12 17l-5.6 3 1.1-6.3-4.6-4.4 6.3-.9z" fill="currentColor" />
          </svg>
        </span>
      ))}
    </motion.p>
  )
}

/** Platos gigantes que se deslizan con el scroll, en sentidos contrarios. */
export function Cinta() {
  const reducir = useReducedMotion()
  const ref = useRef<HTMLElement>(null)
  const { scrollYProgress } = useScroll({ target: ref, offset: ['start end', 'end start'] })
  const izquierda = useTransform(scrollYProgress, [0, 1], reducir ? ['0%', '0%'] : ['0%', '-38%'])
  const derecha = useTransform(scrollYProgress, [0, 1], reducir ? ['-30%', '-30%'] : ['-45%', '-8%'])

  return (
    <section ref={ref} aria-label="Platos que acabarán en tu diario" className="flex flex-col gap-2 overflow-hidden py-24 sm:py-32">
      <p className="mb-6 px-5 text-center text-lg font-bold text-tinta-suave sm:text-xl">
        Todo lo que pides, apuntado y con nota.
      </p>
      <Fila platos={PLATOS_1} x={izquierda} />
      <Fila platos={PLATOS_2} x={derecha} degradado />
    </section>
  )
}
