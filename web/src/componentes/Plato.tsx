import type { ReactNode } from 'react'
import { cn } from '@/lib/utils'

/** Etiqueta de carta que abre cada sección: «Aperitivo», «Primero», «La cuenta»… */
export function Plato({ nombre, className }: { nombre: string; className?: string }) {
  return (
    <p
      className={cn(
        'flex items-center gap-3 text-xs font-extrabold uppercase tracking-[0.18em] text-rico-tomate-texto',
        className,
      )}
    >
      <span aria-hidden className="h-px w-8 bg-rico-tomate/50" />
      {nombre}
    </p>
  )
}

/** Cabecera de sección: plato, titular y entradilla. */
export function CabeceraSeccion({
  plato,
  titulo,
  children,
  centrada = false,
}: {
  plato: string
  titulo: ReactNode
  children?: ReactNode
  centrada?: boolean
}) {
  return (
    <div className={cn('flex max-w-2xl flex-col gap-4', centrada && 'mx-auto items-center text-center')}>
      <Plato nombre={plato} />
      <h2 className="text-4xl font-black leading-[1.05] tracking-tight sm:text-5xl">{titulo}</h2>
      {children ? <p className="text-lg text-rico-secundario sm:text-xl">{children}</p> : null}
    </div>
  )
}
