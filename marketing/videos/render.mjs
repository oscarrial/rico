// Renderiza todos los vídeos, portadas y estáticos en salida/. Uso: npm run render
import {execSync} from 'node:child_process';
import {mkdirSync} from 'node:fs';

const videos = ['01-ApplePay', '02-TuAno', '03-Mapa', '04-POV', '05-EnPublico', 'X-ApplePay', 'X-TuAno'];
// Fotograma de portada de cada vídeo (el más fuerte, no el primero).
const portadas = {'01-ApplePay': 270, '02-TuAno': 120, '03-Mapa': 240, '04-POV': 140, '05-EnPublico': 160};

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
