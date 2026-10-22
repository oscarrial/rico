import { useEffect, useRef, useState } from 'react'
import { useInView } from 'motion/react'
import { Aparecer, Titular } from '@/componentes/Piezas'

/** El vídeo de 12 segundos, en formato TikTok: se reproduce sin sonido al verlo y se puede activar. */
export function Video() {
  const video = useRef<HTMLVideoElement>(null)
  const visible = useInView(video, { amount: 0.5 })
  const [conSonido, setConSonido] = useState(false)

  useEffect(() => {
    const v = video.current
    if (!v) return
    if (visible) v.play().catch(() => {})
    else v.pause()
  }, [visible])

  return (
    <section className="bg-mantel-hondo/60 py-20 sm:py-28">
      <div className="mx-auto flex max-w-6xl flex-col items-center gap-14 px-5 sm:px-8 lg:flex-row lg:justify-center lg:gap-24">
        <Titular etiqueta="Café · En 12 segundos" entradilla="Así se ve Rico de verdad. Sube el volumen.">
          Pagas. <span className="text-tomate">Valoras.</span> Te acuerdas.
        </Titular>

        <Aparecer className="w-[min(78vw,340px)] shrink-0 rounded-[2.4rem] bg-white/55 p-1.5 ring-1 ring-hilo">
          <div className="relative overflow-hidden rounded-[calc(2.4rem-0.375rem)] bg-tinta shadow-[0_40px_80px_-40px_rgba(90,40,15,0.6)]">
            <video
              ref={video}
              src="/video/rico.mp4"
              poster="/video/portada.webp"
              muted={!conSonido}
              loop
              playsInline
              preload="none"
              className="block aspect-[9/16] w-full object-cover"
              aria-label="Vídeo de Rico: pagas la cena y Rico te pregunta qué tal"
            />
            <button
              type="button"
              onClick={() => {
                setConSonido((s) => !s)
                video.current?.play().catch(() => {})
              }}
              className="absolute bottom-4 left-1/2 inline-flex min-h-11 -translate-x-1/2 items-center gap-2 whitespace-nowrap rounded-full bg-white/90 px-4 text-sm font-black text-tinta shadow-lg backdrop-blur"
            >
              <svg viewBox="0 0 24 24" className="size-4" aria-hidden>
                <path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z" fill="currentColor" />
                {conSonido ? (
                  <path d="M15.5 9a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
                ) : (
                  <path d="M16 9.5l5 5M21 9.5l-5 5" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
                )}
              </svg>
              {conSonido ? 'Quitar sonido' : 'Activar sonido'}
            </button>
          </div>
        </Aparecer>
      </div>
    </section>
  )
}
