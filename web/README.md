# Landing de Rico

La página web de Rico para quien llega desde TikTok: «Muy pronto en el App Store», en claro y
pensada primero para el móvil. Va de plato en plato, del hero con el iPhone que sale desde abajo
hasta la cuenta (los precios, en forma de ticket).

- `npm install` y `npm run dev` para verla en local; `npm run build` deja la web en `dist/`.
- Hecha con Vite, React, Tailwind 4 y Motion. Los componentes animados de `src/components/motion`
  son de [beUI](https://beui.dev), añadidos con `npx shadcn@latest add @beui/<nombre>`.
- `src/config.ts`: enlace público de TestFlight, correo de contacto y precios. Hay que rellenar
  los dos primeros antes de publicar.
- `/privacidad` y `/soporte` son las páginas que pide la App Store. El hosting tiene que servir
  `index.html` para cualquier ruta (Cloudflare Pages y Vercel lo hacen solos).
- Las capturas de `public/capturas` son las claras de `marketing/videos/public/capturas`, en WebP
  a 804 px. Dentro del iPhone todo se dibuja a 402 × 874 puntos (`componentes/Iphone.tsx`).
- La insignia `public/marca/app-store-es.svg` es la oficial de Apple (Marketing Toolbox). No se
  retoca ni se tapa; se enlaza en `ENLACE_APP_STORE` cuando Rico esté publicado.
