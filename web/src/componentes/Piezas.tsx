import type { ReactNode } from 'react'
import { motion, useReducedMotion } from 'motion/react'
import { cn } from '@/lib/utils'
import { ENLACE_APP_STORE } from '@/config'

const MUELLE = [0.32, 0.72, 0, 1] as const

/** Etiqueta en píldora encima de cada titular: «Aperitivo», «Primero»… */
export function Etiqueta({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <span
      className={cn(
        'inline-flex w-max items-center gap-2 rounded-full bg-tomate-suave px-3.5 py-1.5 text-[11px] font-extrabold uppercase tracking-[0.2em] text-tomate-texto',
        className,
      )}
    >
      {children}
    </span>
  )
}

/** Titular de sección con su etiqueta y entradilla. */
export function Titular({
  etiqueta,
  children,
  entradilla,
  centrado = false,
  className,
}: {
  etiqueta: string
  children: ReactNode
  entradilla?: ReactNode
  centrado?: boolean
  className?: string
}) {
  return (
    <Aparecer className={cn('flex max-w-3xl flex-col gap-5', centrado && 'mx-auto items-center text-center', className)}>
      <Etiqueta>{etiqueta}</Etiqueta>
      <h2 className="text-[clamp(2.2rem,6.5vw,3.75rem)] font-black leading-[1] tracking-[-0.035em]">{children}</h2>
      {entradilla ? <p className="max-w-xl text-lg text-tinta-suave sm:text-xl">{entradilla}</p> : null}
    </Aparecer>
  )
}

/** Entrada al hacer scroll: sube un poco y aparece. */
export function Aparecer({
  children,
  className,
  retraso = 0,
}: {
  children: ReactNode
  className?: string
  retraso?: number
}) {
  const reducir = useReducedMotion()
  return (
    <motion.div
      className={className}
      initial={reducir ? false : { opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, amount: 0.2 }}
      transition={{ duration: 0.7, ease: MUELLE, delay: retraso }}
    >
      {children}
    </motion.div>
  )
}

/** Flecha fina para los botones. */
export function Flecha({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" className={cn('size-4', className)} aria-hidden>
      <path d="M7 17L17 7M9 7h8v8" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  )
}

/** Botón en píldora con la flecha dentro de su propio círculo. */
export function Boton({
  href,
  children,
  variante = 'tomate',
  className,
  onClick,
}: {
  href?: string
  children: ReactNode
  variante?: 'tomate' | 'tinta' | 'claro'
  className?: string
  onClick?: () => void
}) {
  const estilos = {
    tomate: 'bg-tomate text-sobre-tomate shadow-[0_18px_40px_-16px_rgba(210,56,31,0.7)]',
    tinta: 'bg-tinta text-mantel',
    claro: 'bg-superficie text-tinta ring-1 ring-hilo shadow-[0_10px_30px_-18px_rgba(80,40,20,0.35)]',
  }[variante]
  const circulo = {
    tomate: 'bg-white/20',
    tinta: 'bg-white/15',
    claro: 'bg-tomate-suave text-tomate-texto',
  }[variante]
  const contenido = (
    <>
      <span>{children}</span>
      <span
        className={cn(
          'grid size-9 place-items-center rounded-full transition-transform duration-500 ease-[cubic-bezier(0.32,0.72,0,1)] group-hover:-translate-y-px group-hover:translate-x-0.5 group-hover:scale-105',
          circulo,
        )}
      >
        <Flecha />
      </span>
    </>
  )
  const clases = cn(
    'group inline-flex min-h-14 items-center gap-3 rounded-full py-2.5 pl-6 pr-2.5 text-[17px] font-black transition-transform duration-500 ease-[cubic-bezier(0.32,0.72,0,1)] active:scale-[0.97]',
    estilos,
    className,
  )
  if (href) {
    return (
      <a href={href} className={clases}>
        {contenido}
      </a>
    )
  }
  return (
    <button type="button" onClick={onClick} className={clases}>
      {contenido}
    </button>
  )
}

/**
 * Insignia oficial «Descárgalo en el App Store» (Apple Marketing Toolbox). Hasta que Rico esté
 * publicado va sin enlace y con «Muy pronto»: Apple solo deja enlazarla a una app disponible.
 */
export function InsigniaAppStore({ className, grande = false }: { className?: string; grande?: boolean }) {
  const insignia = (
    <img
      src="/marca/app-store-es.svg"
      alt="Descárgalo en el App Store"
      width={120}
      height={40}
      className={cn('block w-auto', grande ? 'h-[60px]' : 'h-[52px]')}
    />
  )
  return (
    // Apple pide no tapar ni retocar la insignia: «Muy pronto» va al lado, con aire alrededor.
    <div className={cn('inline-flex w-max items-center gap-4', className)}>
      {ENLACE_APP_STORE ? (
        <a href={ENLACE_APP_STORE} className="transition-transform active:scale-[0.97]">
          {insignia}
        </a>
      ) : (
        <>
          <span aria-label="Muy pronto en el App Store">{insignia}</span>
          <span className="flex flex-col leading-tight">
            <span className="flex items-center gap-1.5 text-[11px] font-black uppercase tracking-[0.18em] text-tomate-texto">
              <span className="relative flex size-2">
                <span className="absolute inline-flex size-full animate-ping rounded-full bg-tomate opacity-60 motion-reduce:animate-none" />
                <span className="relative inline-flex size-2 rounded-full bg-tomate" />
              </span>
              Muy pronto
            </span>
            <span className="text-sm font-bold text-tinta-suave">en iPhone</span>
          </span>
        </>
      )}
    </div>
  )
}

/** Estrellas finas para chips y tarjetas. */
export function Estrellas({ n = 5, className }: { n?: number; className?: string }) {
  return (
    <span className={cn('inline-flex gap-0.5', className)} aria-label={`${n} estrellas`}>
      {Array.from({ length: n }, (_, i) => (
        <svg key={i} viewBox="0 0 24 24" className="size-4" aria-hidden>
          <path d="M12 2.6l2.8 5.8 6.3.9-4.6 4.4 1.1 6.3L12 17l-5.6 3 1.1-6.3-4.6-4.4 6.3-.9z" fill="#F0A202" />
        </svg>
      ))}
    </span>
  )
}
