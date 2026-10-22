import { CabeceraSeccion } from '@/componentes/Plato'

const PUNTOS = [
  {
    titulo: 'Primero en tu iPhone',
    texto: 'Todo se guarda en el móvil y funciona sin conexión. La cuenta solo sirve para tener copia y usarlo en otro iPhone.',
  },
  {
    titulo: 'Servidores en Europa',
    texto: 'La copia vive en Frankfurt y cada persona solo puede leer lo suyo. Nada de vender datos ni de anuncios.',
  },
  {
    titulo: 'La ubicación no sale del iPhone',
    texto: 'Se usa para reconocer el restaurante en ese momento. No guardamos por dónde te mueves.',
  },
  {
    titulo: 'Te vas cuando quieras',
    texto: 'Borras la cuenta desde la app y se borra todo, también la copia del servidor.',
  },
]

export function Cafe() {
  return (
    <section className="mx-auto flex max-w-6xl flex-col gap-12 px-[max(1.25rem,env(safe-area-inset-left))] py-24">
      <CabeceraSeccion plato="Café" titulo="Tu diario es tuyo. Y punto.">
        Lo que comes, con quién y cuánto gastas es cosa tuya.
      </CabeceraSeccion>
      <dl className="grid gap-x-10 gap-y-8 sm:grid-cols-2">
        {PUNTOS.map((punto) => (
          <div key={punto.titulo} className="flex flex-col gap-2 border-l-[3px] border-rico-albahaca pl-5">
            <dt className="text-xl font-black">{punto.titulo}</dt>
            <dd className="text-rico-secundario">{punto.texto}</dd>
          </div>
        ))}
      </dl>
    </section>
  )
}
