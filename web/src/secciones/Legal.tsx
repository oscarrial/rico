import type { ReactNode } from 'react'
import { CORREO_CONTACTO } from '@/config'

function Pagina({ titulo, actualizado, children }: { titulo: string; actualizado: string; children: ReactNode }) {
  return (
    <main className="mx-auto flex max-w-2xl flex-col gap-8 px-5 pb-24 pt-36">
      <div className="flex flex-col gap-2">
        <h1 className="text-5xl font-black tracking-[-0.035em] sm:text-6xl">{titulo}</h1>
        <p className="text-sm font-bold text-tinta-suave">Actualizado el {actualizado}</p>
      </div>
      <div className="flex flex-col gap-5 text-lg leading-relaxed [&_a]:font-extrabold [&_a]:text-tomate-texto [&_h2]:mt-4 [&_h2]:text-2xl [&_h2]:font-black [&_li]:ml-5 [&_li]:list-disc [&_li]:text-tinta-suave [&_p]:text-tinta-suave">
        {children}
      </div>
    </main>
  )
}

export function Privacidad() {
  return (
    <Pagina titulo="Privacidad" actualizado="22 de octubre de 2026">
      <p>Rico es un diario privado de restaurantes. Esta página explica qué datos usa la app, dónde se guardan y cómo borrarlos.</p>

      <h2>Qué guarda Rico</h2>
      <ul>
        <li>Tus visitas: restaurante, fecha, estrellas, notas, platos, importe y las fotos que añadas.</li>
        <li>Tus listas, como «Quiero probar».</li>
        <li>Si creas cuenta: tu correo o tu identificador de «Iniciar sesión con Apple».</li>
      </ul>

      <h2>Dónde se guarda</h2>
      <p>
        Todo se guarda primero en tu iPhone. Si inicias sesión, se hace una copia en nuestros servidores de Supabase en
        Frankfurt (Unión Europea) para que no la pierdas y puedas usar Rico en otro iPhone. Cada cuenta solo puede leer sus
        propios datos.
      </p>

      <h2>Pagos con Apple Pay</h2>
      <p>
        Si creas la automatización de Atajos, tu iPhone envía a Rico el nombre del comercio, el importe y la tarjeta de cada
        pago. Rico no tiene acceso a tu banco, a tu saldo ni a otros movimientos. Los pagos que no son de restaurantes se
        descartan.
      </p>

      <h2>Ubicación</h2>
      <p>
        Rico usa la ubicación para reconocer el restaurante en el que estás: al pagar o, si activas «Detectar comidas por
        ubicación», cuando pasas un rato en uno. Tu ubicación no se envía a nuestros servidores ni se guarda tu recorrido:
        solo se guarda el restaurante de cada visita. Para buscar sitios se usa Apple Maps.
      </p>

      <h2>Lo que no hacemos</h2>
      <ul>
        <li>No vendemos ni compartimos tus datos con terceros.</li>
        <li>No hay anuncios ni rastreadores publicitarios.</li>
        <li>Tus valoraciones no son públicas.</li>
      </ul>

      <h2>Borrar tus datos</h2>
      <p>
        Desde la app, en Cuenta → «Borrar cuenta», se borran tu cuenta y todos tus datos del servidor y del iPhone. Si no
        usas cuenta, basta con borrar la app.
      </p>

      <h2>Contacto</h2>
      <p>
        Para cualquier duda sobre tus datos, escríbenos a <a href={`mailto:${CORREO_CONTACTO}`}>{CORREO_CONTACTO}</a>.
      </p>
    </Pagina>
  )
}

export function Soporte() {
  return (
    <Pagina titulo="Soporte" actualizado="22 de octubre de 2026">
      <p>
        ¿Algo no funciona o tienes una idea? Escríbenos a <a href={`mailto:${CORREO_CONTACTO}`}>{CORREO_CONTACTO}</a> y te
        contestamos lo antes posible.
      </p>

      <h2>No me llegan los avisos</h2>
      <p>
        En Rico, abre tu cuenta → «Pagos con Apple Pay» y comprueba que los avisos están activados. Pulsa «Enviar un aviso de
        prueba»: debería llegarte en unos segundos.
      </p>

      <h2>Pagué y no se apuntó la visita</h2>
      <p>
        Revisa en Atajos que la automatización «Transacción» está en «Ejecutar inmediatamente» y que la acción «Registrar
        pago» tiene conectados el comercio y el importe. En la app tienes la guía paso a paso.
      </p>

      <h2>Restaurar Premium</h2>
      <p>En la pantalla de Premium, toca «Restaurar compras» con el mismo Apple ID con el que pagaste.</p>

      <h2>Cancelar Premium</h2>
      <p>Se gestiona desde Ajustes del iPhone → tu nombre → Suscripciones → Rico.</p>
    </Pagina>
  )
}
