import { useState } from 'react'
import { AnimatePresence, motion } from 'motion/react'
import { CORREO_CONTACTO, ENLACE_BETA } from '@/config'

const ENLACES = [
  { href: '/#como-funciona', texto: 'Cómo funciona' },
  { href: '/#precios', texto: 'Precios' },
  { href: '/#preguntas', texto: 'Preguntas' },
]

/** Isla de navegación flotante, despegada del borde. En el móvil se abre a pantalla completa. */
export function Navegacion() {
  const [abierta, setAbierta] = useState(false)

  return (
    <>
      <header className="fixed inset-x-0 top-0 z-30 flex justify-center px-4 pt-[max(1rem,env(safe-area-inset-top))]">
        <nav className="flex w-full max-w-3xl items-center justify-between gap-2 rounded-full bg-white/75 py-2 pl-4 pr-2 shadow-[0_12px_40px_-20px_rgba(90,40,15,0.45)] ring-1 ring-hilo backdrop-blur-xl">
          <a href="/" className="flex min-h-11 items-center gap-2" aria-label="Rico, inicio">
            <img src="/marca/simbolo.svg" alt="" className="size-7" />
            <span className="text-xl font-black tracking-tight">Rico</span>
          </a>
          <div className="hidden items-center gap-7 md:flex">
            {ENLACES.map((enlace) => (
              <a key={enlace.href} href={enlace.href} className="text-sm font-extrabold text-tinta-suave transition-colors hover:text-tinta">
                {enlace.texto}
              </a>
            ))}
          </div>
          <div className="flex items-center gap-1">
            <a href={ENLACE_BETA} className="inline-flex min-h-11 items-center rounded-full bg-tinta px-5 text-sm font-black text-mantel transition-transform active:scale-[0.97]">
              Prueba la beta
            </a>
            <button
              type="button"
              onClick={() => setAbierta((a) => !a)}
              aria-expanded={abierta}
              aria-label={abierta ? 'Cerrar menú' : 'Abrir menú'}
              className="relative grid size-11 place-items-center rounded-full md:hidden"
            >
              <span className={`absolute h-[2px] w-5 rounded-full bg-tinta transition-transform duration-500 ease-[cubic-bezier(0.32,0.72,0,1)] ${abierta ? 'rotate-45' : '-translate-y-[4px]'}`} />
              <span className={`absolute h-[2px] w-5 rounded-full bg-tinta transition-transform duration-500 ease-[cubic-bezier(0.32,0.72,0,1)] ${abierta ? '-rotate-45' : 'translate-y-[4px]'}`} />
            </button>
          </div>
        </nav>
      </header>

      <AnimatePresence>
        {abierta ? (
          <motion.div
            className="fixed inset-0 z-20 flex flex-col justify-center gap-2 bg-mantel/90 px-8 backdrop-blur-3xl md:hidden"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.4, ease: [0.32, 0.72, 0, 1] }}
          >
            {ENLACES.map((enlace, i) => (
              <motion.a
                key={enlace.href}
                href={enlace.href}
                onClick={() => setAbierta(false)}
                className="py-2 text-5xl font-black tracking-[-0.03em]"
                initial={{ opacity: 0, y: 40 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.6, delay: 0.08 + i * 0.06, ease: [0.32, 0.72, 0, 1] }}
              >
                {enlace.texto}
              </motion.a>
            ))}
          </motion.div>
        ) : null}
      </AnimatePresence>
    </>
  )
}

export function Pie() {
  return (
    <footer className="border-t border-hilo">
      <div className="mx-auto flex max-w-6xl flex-col gap-6 px-5 py-10 pb-[max(2.5rem,env(safe-area-inset-bottom))] sm:flex-row sm:items-center sm:justify-between sm:px-8">
        <div className="flex items-center gap-2">
          <img src="/marca/simbolo.svg" alt="" className="size-6" />
          <span className="font-black">Rico</span>
          <span className="text-sm text-tinta-suave">· Hecho en Galicia con hambre</span>
        </div>
        <nav className="flex flex-wrap gap-x-6 gap-y-2 text-sm font-bold text-tinta-suave">
          <a href="/privacidad" className="min-h-11 content-center hover:text-tinta">Privacidad</a>
          <a href="/soporte" className="min-h-11 content-center hover:text-tinta">Soporte</a>
          <a href={`mailto:${CORREO_CONTACTO}`} className="min-h-11 content-center hover:text-tinta">{CORREO_CONTACTO}</a>
        </nav>
      </div>
      <p className="px-5 pb-8 text-center text-xs text-tinta-suave/80">
        Apple, el logotipo de Apple, iPhone y Apple Pay son marcas de Apple Inc. App Store es una marca de servicio de Apple Inc.
      </p>
    </footer>
  )
}
