import { ENLACE_BETA, CORREO_CONTACTO } from '@/config'

export function Cabecera() {
  return (
    <header className="sticky top-0 z-30 border-b border-rico-linea/70 bg-rico-fondo/85 pt-[env(safe-area-inset-top)] backdrop-blur-md">
      <div className="mx-auto flex h-16 max-w-6xl items-center justify-between px-[max(1.25rem,env(safe-area-inset-left))]">
        <a href="/" className="flex items-center gap-2" aria-label="Rico, inicio">
          <img src="/marca/simbolo.svg" alt="" className="size-8" />
          <span className="text-2xl font-black tracking-tight">Rico</span>
        </a>
        <nav className="flex items-center gap-2 sm:gap-6">
          <a href="/#como-funciona" className="hidden text-sm font-extrabold text-rico-secundario hover:text-rico-tinta sm:inline">
            Cómo funciona
          </a>
          <a href="/#precios" className="hidden text-sm font-extrabold text-rico-secundario hover:text-rico-tinta sm:inline">
            Precios
          </a>
          <a
            href={ENLACE_BETA}
            className="inline-flex min-h-11 items-center rounded-full bg-rico-tinta px-5 text-sm font-black text-rico-fondo"
          >
            Prueba la beta
          </a>
        </nav>
      </div>
    </header>
  )
}

export function Pie() {
  return (
    <footer className="border-t border-rico-linea">
      <div className="mx-auto flex max-w-6xl flex-col gap-6 px-[max(1.25rem,env(safe-area-inset-left))] py-10 pb-[max(2.5rem,env(safe-area-inset-bottom))] sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-center gap-2">
          <img src="/marca/simbolo.svg" alt="" className="size-6" />
          <span className="font-black">Rico</span>
          <span className="text-sm text-rico-secundario">· Hecho en Galicia con hambre</span>
        </div>
        <nav className="flex flex-wrap gap-x-6 gap-y-2 text-sm font-bold text-rico-secundario">
          <a href="/privacidad" className="hover:text-rico-tinta">Privacidad</a>
          <a href="/soporte" className="hover:text-rico-tinta">Soporte</a>
          <a href={`mailto:${CORREO_CONTACTO}`} className="hover:text-rico-tinta">{CORREO_CONTACTO}</a>
        </nav>
      </div>
    </footer>
  )
}
