import { useLayoutEffect, useRef, useState, type ReactNode } from 'react'
import { cn } from '@/lib/utils'

/** Pantalla del iPhone 16 Pro en puntos: todo lo de dentro se dibuja a este tamaño y se escala. */
export const PANTALLA = { ancho: 402, alto: 874 } as const

/** Dibuja `children` a 402 × 874 puntos y lo escala al ancho real, como un iPhone de verdad. */
function Escala({ children }: { children: ReactNode }) {
  const caja = useRef<HTMLDivElement>(null)
  const [factor, setFactor] = useState(0)

  useLayoutEffect(() => {
    const nodo = caja.current
    if (!nodo) return
    const medir = () => setFactor(nodo.clientWidth / PANTALLA.ancho)
    medir()
    const observador = new ResizeObserver(medir)
    observador.observe(nodo)
    return () => observador.disconnect()
  }, [])

  return (
    <div ref={caja} className="absolute inset-0">
      <div
        className="absolute left-0 top-0 origin-top-left"
        style={{ width: PANTALLA.ancho, height: PANTALLA.alto, transform: `scale(${factor})`, opacity: factor ? 1 : 0 }}
      >
        {children}
      </div>
    </div>
  )
}

/**
 * iPhone 16 Pro en titanio desierto: canto metálico, borde negro fino, botones laterales y un
 * brillo de cristal. Las medidas van en `cqw` para que todo escale con el ancho.
 */
export function Iphone({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className={cn('relative w-full [container-type:inline-size]', className)}>
      {/* Botón de acción y volumen, a la izquierda; lateral y Control de Cámara, a la derecha. */}
      <span aria-hidden className="titanio absolute -left-[1.1cqw] top-[17%] h-[5%] w-[1.6cqw] rounded-l-[1cqw]" />
      <span aria-hidden className="titanio absolute -left-[1.1cqw] top-[25%] h-[8.5%] w-[1.6cqw] rounded-l-[1cqw]" />
      <span aria-hidden className="titanio absolute -left-[1.1cqw] top-[35.5%] h-[8.5%] w-[1.6cqw] rounded-l-[1cqw]" />
      <span aria-hidden className="titanio absolute -right-[1.1cqw] top-[26%] h-[13%] w-[1.6cqw] rounded-r-[1cqw]" />
      <span aria-hidden className="titanio absolute -right-[0.8cqw] top-[57%] h-[8%] w-[1.2cqw] rounded-r-[0.8cqw]" />

      <div
        className="titanio relative aspect-[1000/2087] rounded-[16.5cqw] p-[1.15cqw] shadow-[0_2px_2px_rgba(80,50,30,0.12),0_30px_60px_-20px_rgba(120,60,30,0.35),0_70px_120px_-50px_rgba(210,56,31,0.35)]"
      >
        <div className="h-full rounded-[15.4cqw] bg-black p-[2.55cqw] shadow-[inset_0_0_0_0.35cqw_rgba(255,255,255,0.08)]">
          <div className="relative h-full overflow-hidden rounded-[12.9cqw] bg-white">
            <Escala>{children}</Escala>
            {/* Reflejo del cristal. */}
            <div
              aria-hidden
              className="pointer-events-none absolute inset-0 bg-[linear-gradient(115deg,rgba(255,255,255,0.22)_0%,rgba(255,255,255,0)_28%,rgba(255,255,255,0)_72%,rgba(255,255,255,0.08)_100%)]"
            />
          </div>
        </div>
      </div>
    </div>
  )
}
