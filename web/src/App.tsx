import { Hero } from '@/secciones/Hero'
import { Cinta } from '@/secciones/Cinta'
import { ComoFunciona } from '@/secciones/ComoFunciona'
import { Bento } from '@/secciones/Bento'
import { TuAno } from '@/secciones/TuAno'
import { Video } from '@/secciones/Video'
import { LaCuenta } from '@/secciones/LaCuenta'
import { Preguntas } from '@/secciones/Preguntas'
import { Final } from '@/secciones/Final'
import { Navegacion, Pie } from '@/secciones/Marco'
import { Privacidad, Soporte } from '@/secciones/Legal'

/** La sobremesa, plato a plato. */
function Inicio() {
  return (
    <main>
      <Hero />
      <Cinta />
      <ComoFunciona />
      <Bento />
      <TuAno />
      <Video />
      <LaCuenta />
      <Preguntas />
      <Final />
    </main>
  )
}

export default function App() {
  const ruta = window.location.pathname.replace(/\/+$/, '')
  const pagina = ruta === '/privacidad' ? <Privacidad /> : ruta === '/soporte' ? <Soporte /> : <Inicio />

  return (
    <div className="grano">
      <Navegacion />
      {pagina}
      <Pie />
    </div>
  )
}
