# Landing de Rico

La página web de Rico, con el tema «Sobremesa»: se recorre como una comida, desde el aperitivo
(el hero) hasta la cuenta (los precios, en forma de ticket).

- `npm install` y `npm run dev` para verla en local; `npm run build` deja la web en `dist/`.
- Hecha con Vite, React, Tailwind 4 y Motion. Los componentes animados de `src/components/motion`
  son de [beUI](https://beui.dev), añadidos con `npx shadcn@latest add @beui/<nombre>`.
- `src/config.ts`: enlace público de TestFlight, correo de contacto y precios. Hay que rellenar
  los dos primeros antes de publicar.
- `/privacidad` y `/soporte` son las páginas que pide la App Store. El hosting tiene que servir
  `index.html` para cualquier ruta (Cloudflare Pages y Vercel lo hacen solos).
- Las capturas de `public/capturas` salen de `marketing/videos/public/capturas`.
