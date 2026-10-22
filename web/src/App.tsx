import { Aperitivo } from '@/secciones/Aperitivo'
import { Entrante } from '@/secciones/Entrante'
import { Primero } from '@/secciones/Primero'
import { Segundo } from '@/secciones/Segundo'
import { Postre } from '@/secciones/Postre'
import { Cafe } from '@/secciones/Cafe'
import { Cuenta } from '@/secciones/Cuenta'
import { Chupito } from '@/secciones/Chupito'
import { Cabecera, Pie } from '@/secciones/Marco'
import { Privacidad, Soporte } from '@/secciones/Legal'

/** La carta de la sobremesa, plato a plato. */
function Inicio() {
  return (
    <main>
      <Aperitivo />
      <Entrante />
      <Primero />
      <Segundo />
      <Postre />
      <Cafe />
      <Cuenta />
      <Chupito />
    </main>
  )
}

export default function App() {
  const ruta = window.location.pathname.replace(/\/+$/, '')
  const pagina = ruta === '/privacidad' ? <Privacidad /> : ruta === '/soporte' ? <Soporte /> : <Inicio />

  return (
    <>
      <Cabecera />
      {pagina}
      <Pie />
    </>
  )
}
