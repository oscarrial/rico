import { motion, useReducedMotion } from 'motion/react'
import { cn } from '@/lib/utils'

/** Captura real de la app (402 × 874 puntos). Ya lleva la barra de estado y la Dynamic Island. */
export function Captura({ nombre, alt, prioridad = false }: { nombre: string; alt: string; prioridad?: boolean }) {
  return (
    <img
      src={`/capturas/${nombre}.webp`}
      alt={alt}
      width={402}
      height={874}
      loading={prioridad ? 'eager' : 'lazy'}
      decoding="async"
      className="absolute inset-0 h-full w-full object-cover"
    />
  )
}

/** Barra de estado y Dynamic Island apagada, para las pantallas dibujadas a mano. */
function BarraEstado({ hora = '21:47', clara = false }: { hora?: string; clara?: boolean }) {
  const color = clara ? '#ffffff' : '#000000'
  return (
    <div className="absolute inset-x-0 top-0 h-[54px]">
      <span className="absolute left-[54px] top-[18px] text-[17px] font-bold tracking-tight" style={{ color, fontFamily: 'system-ui, -apple-system' }}>
        {hora}
      </span>
      <span className="absolute left-[138px] top-[14px] h-[37px] w-[126px] rounded-full bg-black" />
      <svg viewBox="0 0 80 14" className="absolute right-[26px] top-[22px] h-[13px] w-[74px]" aria-hidden>
        <g fill={color}>
          <rect x="0" y="9" width="3" height="5" rx="1" />
          <rect x="5" y="6" width="3" height="8" rx="1" />
          <rect x="10" y="3" width="3" height="11" rx="1" />
          <rect x="15" y="0" width="3" height="14" rx="1" />
          <path d="M33 13.5l3-3.4a4.4 4.4 0 0 0-6 0zM27.4 7.7l1.6 1.7a6.9 6.9 0 0 1 8 0l1.6-1.7a9.3 9.3 0 0 0-11.2 0z" />
          <rect x="47" y="1.5" width="25" height="11" rx="3.4" fill="none" stroke={color} strokeOpacity="0.4" strokeWidth="1" />
          <rect x="49" y="3.5" width="18" height="7" rx="1.8" />
          <rect x="73.5" y="5" width="1.6" height="4" rx="0.8" fillOpacity="0.4" />
        </g>
      </svg>
    </div>
  )
}

/** Paso 1: el pago con Apple Pay acaba de salir bien. */
export function PantallaPago() {
  return (
    <div className="absolute inset-0 bg-[#f2f2f7]">
      <BarraEstado />
      <div className="absolute inset-x-0 top-[120px] flex flex-col items-center gap-10 px-8">
        <div className="relative aspect-[1.586] w-full overflow-hidden rounded-[18px] bg-[linear-gradient(135deg,#2a2622,#0f0d0b)] p-5 shadow-[0_20px_40px_-20px_rgba(0,0,0,0.6)]">
          <span className="text-[15px] font-bold text-white/60">Mi tarjeta</span>
          <span className="absolute bottom-5 right-5 text-[15px] font-bold text-white/60">•••• 4021</span>
          <span className="absolute -right-10 -top-16 size-48 rounded-full bg-[#d2381f]/30 blur-2xl" />
        </div>
        <div className="flex flex-col items-center gap-3">
          <svg viewBox="0 0 64 64" className="size-[86px]" aria-hidden>
            <circle cx="32" cy="32" r="29" fill="none" stroke="#34c759" strokeWidth="3.5" />
            <path d="M19 33l9 9 17-19" fill="none" stroke="#34c759" strokeWidth="4.5" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
          <span className="text-[30px] font-black">Hecho</span>
        </div>
        <div className="flex w-full flex-col items-center gap-1 rounded-[20px] bg-white py-5">
          <span className="text-[17px] font-bold text-[#6b6158]">Taberna O Grelo</span>
          <span className="text-[40px] font-black tracking-tight tabular-nums">48,00 €</span>
        </div>
      </div>
    </div>
  )
}

/** Paso 2: el aviso de Rico en la pantalla de bloqueo, un rato después. */
export function PantallaAviso({ activa }: { activa: boolean }) {
  const reducir = useReducedMotion()
  return (
    <div className="absolute inset-0 overflow-hidden bg-[radial-gradient(120%_70%_at_20%_10%,#ffb48f_0%,#e2603f_38%,#8f2c18_75%,#4a160b_100%)]">
      <BarraEstado hora="22:07" clara />
      <div className="absolute inset-x-0 top-[92px] flex flex-col items-center text-white">
        <span className="text-[21px] font-bold opacity-90">miércoles, 21 de octubre</span>
        <span className="text-[104px] font-black leading-[1.05] tracking-[-0.04em]">22:07</span>
      </div>
      <motion.div
        className="absolute inset-x-[12px] top-[330px] rounded-[26px] bg-white/75 p-[14px] shadow-[0_10px_30px_-10px_rgba(0,0,0,0.35)] backdrop-blur-xl"
        initial={false}
        animate={activa || reducir ? { y: 0, opacity: 1, scale: 1 } : { y: -40, opacity: 0, scale: 0.94 }}
        transition={{ type: 'spring', bounce: 0.35, duration: 0.7, delay: activa ? 0.35 : 0 }}
      >
        <div className="flex gap-[12px]">
          <img src="/marca/icono.png" alt="" className="size-[40px] rounded-[10px]" />
          <div className="flex min-w-0 flex-1 flex-col">
            <div className="flex justify-between text-[15px]">
              <span className="font-black text-black">¿Qué tal en Taberna O Grelo?</span>
            </div>
            <span className="text-[15px] font-semibold text-black/70">Valóralo en diez segundos. 48,00 €</span>
          </div>
          <span className="text-[13px] font-semibold text-black/50">ahora</span>
        </div>
      </motion.div>
      <div className="absolute bottom-[10px] left-1/2 h-[5px] w-[140px] -translate-x-1/2 rounded-full bg-white/80" />
    </div>
  )
}

/** Paso 3: la ficha de valorar, con las estrellas rellenándose una a una. */
export function PantallaValorar({ activa }: { activa: boolean }) {
  const reducir = useReducedMotion()
  // Centros de las cinco estrellas de la captura, en puntos.
  const centros = [80, 140.5, 201, 261.5, 321.5]
  return (
    <div className="absolute inset-0">
      <Captura nombre="valorar" alt="La ficha para valorar Taberna O Grelo" />
      {centros.map((x, i) => (
        <motion.svg
          key={x}
          viewBox="0 0 24 24"
          className="absolute size-[50px]"
          style={{ left: x - 25, top: 203 }}
          initial={false}
          animate={activa || reducir ? { scale: 1, opacity: 1 } : { scale: 0.3, opacity: 0 }}
          transition={{ type: 'spring', bounce: 0.6, duration: 0.55, delay: activa ? 0.4 + i * 0.18 : 0 }}
          aria-hidden
        >
          <path d="M12 2.6l2.8 5.8 6.3.9-4.6 4.4 1.1 6.3L12 17l-5.6 3 1.1-6.3-4.6-4.4 6.3-.9z" fill="#F0A202" />
        </motion.svg>
      ))}
      <motion.span
        className="absolute left-0 right-0 top-[254px] bg-[#fcf6f1] py-[2px] text-center text-[18px] font-extrabold text-[#a8291a]"
        initial={false}
        animate={activa || reducir ? { opacity: 1 } : { opacity: 0 }}
        transition={{ delay: activa ? 1.4 : 0 }}
      >
        ¡Me encantó!
      </motion.span>
    </div>
  )
}

/** Paso 4: queda en el diario, arriba del todo. */
export function PantallaDiario({ activa }: { activa: boolean }) {
  return (
    <div className="absolute inset-0">
      <Captura nombre="diario" alt="El diario de Rico con Taberna O Grelo arriba del todo" />
      <motion.span
        aria-hidden
        className={cn('absolute left-[19px] right-[19px] top-[324px] h-[186px] rounded-[24px] ring-[3px] ring-[#d2381f]')}
        initial={false}
        animate={activa ? { opacity: [0, 1, 0.6], scale: [1.04, 1, 1] } : { opacity: 0 }}
        transition={{ duration: 1.2, delay: activa ? 0.3 : 0 }}
      />
    </div>
  )
}
