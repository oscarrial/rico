import type { ReactNode } from 'react'
import { cn } from '@/lib/utils'

/**
 * iPhone dibujado con CSS alrededor de una captura real de la app. La captura cambia con el
 * modo claro u oscuro del sistema, como la app.
 */
export function Iphone({
  pantalla,
  alt,
  className,
  children,
  prioridad = false,
}: {
  /** Nombre de la captura en /public/capturas, sin «-light.png». */
  pantalla: string
  alt: string
  className?: string
  /** Lo que va encima de la pantalla (la Dynamic Island, avisos…). */
  children?: ReactNode
  prioridad?: boolean
}) {
  return (
    <div
      className={cn(
        'relative aspect-[1206/2622] w-full max-w-[300px] rounded-[3.2rem] bg-[#0d0b09] p-[3.5%] shadow-[0_40px_80px_-30px_rgba(60,25,10,0.45)] ring-1 ring-black/10',
        className,
      )}
    >
      <div className="relative h-full w-full overflow-hidden rounded-[2.75rem] bg-rico-fondo">
        <picture>
          <source srcSet={`/capturas/${pantalla}-dark.png`} media="(prefers-color-scheme: dark)" />
          <img
            src={`/capturas/${pantalla}-light.png`}
            alt={alt}
            width={1206}
            height={2622}
            loading={prioridad ? 'eager' : 'lazy'}
            decoding="async"
            className="h-full w-full object-cover"
          />
        </picture>
        {children}
      </div>
    </div>
  )
}
