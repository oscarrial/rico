const PLATOS = [
  'Pulpo á feira',
  'Zamburiñas',
  'Croquetas',
  'Tortilla poco hecha',
  'Navajas',
  'Pimientos de Padrón',
  'Filloas',
  'Tarta de Santiago',
]

/** Una fila lenta de platos que se desliza sola (y se para con «reducir movimiento»). */
export function Cinta() {
  const fila = [...PLATOS, ...PLATOS]
  return (
    <section aria-label="Platos que acabarán en tu diario" className="overflow-hidden border-y border-hilo bg-superficie/60 py-7">
      <div className="cinta flex w-max items-center gap-8" style={{ ['--duracion' as string]: '70s' }}>
        {fila.map((plato, i) => (
          <span key={i} className="flex items-center gap-8 whitespace-nowrap text-[clamp(1.6rem,4vw,2.4rem)] font-black tracking-[-0.03em]">
            <span className={i % 2 ? 'text-tomate' : 'text-tinta'}>{plato}</span>
            <svg viewBox="0 0 24 24" className="size-5 shrink-0 text-estrella" aria-hidden>
              <path d="M12 2.6l2.8 5.8 6.3.9-4.6 4.4 1.1 6.3L12 17l-5.6 3 1.1-6.3-4.6-4.4 6.3-.9z" fill="currentColor" />
            </svg>
          </span>
        ))}
      </div>
    </section>
  )
}
