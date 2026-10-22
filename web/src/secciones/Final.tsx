import { useState } from 'react'
import { motion, useReducedMotion } from 'motion/react'
import { Aparecer, Boton, InsigniaAppStore } from '@/componentes/Piezas'
import { ENLACE_BETA } from '@/config'

/** Comparte la web con el sistema del móvil; si no se puede, copia el enlace. */
function useCompartir() {
  const [estado, setEstado] = useState<'listo' | 'copiado'>('listo')
  const compartir = async () => {
    const datos = {
      title: 'Rico',
      text: 'Mira esta app para apuntar los restaurantes: pagas y te pregunta qué tal 🍽️',
      url: window.location.origin,
    }
    try {
      if (navigator.share) {
        await navigator.share(datos)
        return
      }
      await navigator.clipboard.writeText(datos.url)
      setEstado('copiado')
      setTimeout(() => setEstado('listo'), 2200)
    } catch {
      // Cancelado por el usuario o sin permiso: no hace falta avisar.
    }
  }
  return { estado, compartir }
}

export function Final() {
  const reducir = useReducedMotion()
  const { estado, compartir } = useCompartir()

  return (
    <section className="relative overflow-hidden px-5 pb-28 pt-12 sm:pb-36">
      <div aria-hidden className="pointer-events-none absolute inset-0 bg-[radial-gradient(50%_45%_at_50%_45%,rgba(210,56,31,0.16),transparent_70%)]" />
      <Aparecer className="relative mx-auto flex max-w-3xl flex-col items-center gap-8 text-center">
        <motion.img
          src="/marca/icono.png"
          alt="Icono de Rico"
          width={1024}
          height={1024}
          className="size-28 rounded-[1.9rem] shadow-[0_30px_60px_-20px_rgba(210,56,31,0.55)] sm:size-36 sm:rounded-[2.4rem]"
          animate={reducir ? undefined : { y: [0, -10, 0], rotate: [0, -2, 0] }}
          transition={{ duration: 5, repeat: Infinity, ease: [0.45, 0, 0.55, 1] }}
        />
        <h2 className="text-[clamp(3rem,11vw,6.5rem)] font-black leading-[0.9] tracking-[-0.045em]">
          Muy pronto en <span className="text-tomate">tu iPhone.</span>
        </h2>
        <p className="max-w-md text-lg text-tinta-suave sm:text-xl">Tu próxima cena ya puede quedar apuntada.</p>
        <InsigniaAppStore grande />
        <div className="flex flex-col items-center gap-3 sm:flex-row">
          <Boton href={ENLACE_BETA}>Entra en la beta</Boton>
          <Boton variante="claro" onClick={compartir}>
            {estado === 'copiado' ? 'Enlace copiado' : 'Pásaselo al grupo'}
          </Boton>
        </div>
      </Aparecer>
    </section>
  )
}
