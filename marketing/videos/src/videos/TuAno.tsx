import React from 'react';
import {AbsoluteFill, Sequence, interpolate, useCurrentFrame} from 'remotion';
import {Aparece, C, Cierre, Estrellas, Simbolo, TextoEntra, Voz, fuente, fv, tramo, useMuelle} from '../marca';

const V = '02-TuAno';
// Cada escena dura lo que su frase (mínimo 2,5 s, un compás a 96 BPM).
const LARGO = [Math.max(60, fv(V, 0)), ...[1, 2, 3, 4].map((i) => Math.max(75, fv(V, i)))];
const INICIO = LARGO.reduce<number[]>((acc, l, i) => [...acc, (acc[i] ?? 0) + l], [0]);
export const DURACION_TUANO = INICIO[5] + Math.max(75, fv(V, 5) + 30);

// 2 · «Tu año en Rico», al estilo Wrapped: cifras grandes que se guardan y se comparten.
export const DATOS_ANO = {
  ano: '2026',
  restaurantes: 47,
  gasto: 312,
  categoria: 'en croquetas',
  top: 'Taberna O Grelo',
  notaTop: '4,8',
  plato: 'Pulpo á feira',
  veces: 6,
};

const Escena: React.FC<{fondo: string; children: React.ReactNode}> = ({fondo, children}) => {
  const frame = useCurrentFrame();
  const entra = useMuelle(0, {damping: 20});
  return (
    <AbsoluteFill
      style={{
        background: fondo,
        alignItems: 'center',
        justifyContent: 'center',
        clipPath: `circle(${interpolate(entra, [0, 1], [0, 150])}% at 50% 50%)`,
        opacity: frame < 0 ? 0 : 1,
      }}
    >
      {children}
    </AbsoluteFill>
  );
};

const Contador: React.FC<{hasta: number; desde: number; sufijo?: string; tamano: number; color: string}> = ({
  hasta,
  desde,
  sufijo = '',
  tamano,
  color,
}) => {
  const frame = useCurrentFrame();
  const t = tramo(frame, desde, desde + 30);
  const suave = 1 - Math.pow(1 - t, 3);
  const valor = Math.round(hasta * suave);
  const golpe = useMuelle(desde + 30, {damping: 7});
  return (
    <div
      style={{
        fontFamily: fuente,
        fontWeight: 900,
        fontSize: tamano,
        lineHeight: 0.9,
        letterSpacing: -tamano * 0.04,
        color,
        fontVariantNumeric: 'tabular-nums',
        transform: `scale(${1 + 0.08 * Math.sin(golpe * Math.PI)})`,
      }}
    >
      {valor.toLocaleString('es-ES')}
      {sufijo}
    </div>
  );
};

export const TuAno: React.FC<{datos?: typeof DATOS_ANO}> = ({datos = DATOS_ANO}) => {
  return (
    <AbsoluteFill style={{background: C.fondoOscuro}}>
      {INICIO.map((desde, i) => (
        <Voz key={i} video={V} i={i} desde={desde + (i === 5 ? 6 : 3)} />
      ))}
      <Sequence durationInFrames={LARGO[0]}>
        <Escena fondo={C.fondoOscuro}>
          <TextoEntra texto={`Tu ${datos.ano}`} desde={2} tamano={210} color="#F5EEE6" />
          <div style={{height: 30}} />
          <TextoEntra texto="en Rico" desde={10} tamano={120} color="#FF6A4D" />
        </Escena>
      </Sequence>

      <Sequence from={INICIO[1]} durationInFrames={LARGO[1]}>
        <Escena fondo={C.tomate}>
          <Contador hasta={datos.restaurantes} desde={6} tamano={420} color={C.fondo} />
          <TextoEntra texto="restaurantes" desde={14} tamano={110} color={C.fondo} />
          <div style={{position: 'absolute', bottom: 160}}>
            <Simbolo tamano={110} monocromo={C.fondo} />
          </div>
        </Escena>
      </Sequence>

      <Sequence from={INICIO[2]} durationInFrames={LARGO[2]}>
        <Escena fondo={C.fondo}>
          <Contador hasta={datos.gasto} desde={6} sufijo=" €" tamano={330} color={C.tinta} />
          <TextoEntra texto={datos.categoria} desde={16} tamano={110} color={C.tomate} />
          <div style={{marginTop: 50}}>
            <TextoEntra texto="y no nos arrepentimos" desde={36} tamano={56} color={C.secundario} peso={800} />
          </div>
        </Escena>
      </Sequence>

      <Sequence from={INICIO[3]} durationInFrames={LARGO[3]}>
        <Escena fondo={C.tomateSuave}>
          <TextoEntra texto="Tu sitio top" desde={4} tamano={80} color={C.tomateTexto} peso={800} />
          <div style={{height: 30}} />
          <TextoEntra texto={datos.top} desde={10} tamano={140} color={C.tinta} ancho={900} />
          <div style={{height: 50}} />
          <Estrellas nota={5} desde={24} tamano={110} />
          <Aparece desde={44}>
            <div style={{marginTop: 30, fontFamily: fuente, fontWeight: 900, fontSize: 90, color: C.tinta}}>★ {datos.notaTop}</div>
          </Aparece>
        </Escena>
      </Sequence>

      <Sequence from={INICIO[4]} durationInFrames={LARGO[4]}>
        <Escena fondo={C.fondoOscuro}>
          <TextoEntra texto="Lo que más repetiste" desde={4} tamano={76} color="#B5A99D" peso={800} />
          <div style={{height: 30}} />
          <TextoEntra texto={datos.plato} desde={10} tamano={150} color="#F5EEE6" ancho={950} />
          <div style={{height: 40}} />
          <Contador hasta={datos.veces} desde={24} sufijo=" veces" tamano={130} color="#FF6A4D" />
        </Escena>
      </Sequence>

      <Sequence from={INICIO[5]}>
        <Cierre desde={0} frase="¿Cómo será tu año?" oscuro />
      </Sequence>
    </AbsoluteFill>
  );
};
