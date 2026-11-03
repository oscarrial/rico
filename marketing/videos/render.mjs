// Renderiza todos los vídeos, portadas y estáticos en salida/. Uso: npm run render
import {execSync} from 'node:child_process';
import {mkdirSync} from 'node:fs';

const videos = ['01-ApplePay', '02-TuAno', '03-Mapa', '04-POV', '05-EnPublico', '06-Lanzamiento', 'X-ApplePay', 'X-TuAno', 'X-Lanzamiento'];
// Fotograma de portada de cada vídeo (el más fuerte, no el primero).
const portadas = {'01-ApplePay': 270, '02-TuAno': 120, '03-Mapa': 240, '04-POV': 140, '05-EnPublico': 160, '06-Lanzamiento': 30};

mkdirSync('salida/portadas', {recursive: true});
const correr = (c) => execSync(`npx remotion ${c} --log=error`, {stdio: 'inherit'});

for (const id of videos) {
  correr(`render src/index.ts ${id} salida/${id}.mp4 --codec=h264 --crf=18`);
}
for (const [id, frame] of Object.entries(portadas)) {
  correr(`still src/index.ts ${id} salida/portadas/${id}.png --frame=${frame}`);
}
correr('still src/index.ts Perfil salida/perfil.png');
correr('still src/index.ts BannerX salida/banner-x.png');
correr('still src/index.ts PostLanzamiento salida/post-lanzamiento.png');
correr('still src/index.ts HistoriaLanzamiento salida/historia-lanzamiento.png');
