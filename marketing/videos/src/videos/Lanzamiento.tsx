import React from 'react';
import {AbsoluteFill, Sequence, interpolate, useCurrentFrame} from 'remotion';
import {C, Cierre, Simbolo, Telefono, TextoEntra, Voz, fuente, fv, useMuelle} from '../marca';

// 6 · Lanzamiento: el gancho, un repaso por cuatro pantallas reales y «Ya en la App Store».
const PANTALLAS = [
  {captura: 'valorar-light', texto: 'Pagas y te pregunta qué tal'},
  {captura: 'mapa-light', texto: 'Cada sitio, en tu mapa'},
  {captura: 'resumen-light', texto: 'Lo que gastas, sin dramas'},
  {captura: 'listas-light', texto: 'Tus listas para salir'},
];
const V = '06-Lanzamiento';
const INTRO = Math.max(75, fv(V, 0) + 10);
// Cada pantalla dura lo que su frase; INICIOS_P son relativos al carrusel.
const LARGOS_P = PANTALLAS.map((_, i) => Math.max(60, fv(V, i + 1, 6)));
const INICIOS_P = LARGOS_P.reduce<number[]>((acc, l, i) => [...acc, acc[i] + l], [0]);
const CARRUSEL = INICIOS_P[PANTALLAS.length];

const Gancho: React.FC = () => {
  const s = useMuelle(0, {damping: 10});
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', padding: 80, gap: 40}}>
      <div style={{transform: `scale(${s})`}}>
        <Simbolo tamano={200} />
      </div>
      <div>
        <TextoEntra texto="Se acabó olvidar" desde={6} tamano={120} ancho={940} />
        <TextoEntra texto="dónde comiste." desde={16} tamano={120} color={C.tomate} ancho={940} />
      </div>
    </AbsoluteFill>
  );
};

const Carrusel: React.FC = () => {
  const frame = useCurrentFrame();
  const entra = useMuelle(0);
  const posicion = interpolate(
    frame,
    PANTALLAS.flatMap((_, i) => [INICIOS_P[i + 1] - 14, INICIOS_P[i + 1]]),
    PANTALLAS.flatMap((_, i) => [i, Math.min(i + 1, PANTALLAS.length - 1)]),
    {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
      easing: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
    },
  );
  const actual = Math.min(PANTALLAS.length - 1, Math.round(posicion));
  return (
    <AbsoluteFill style={{background: C.fondo}}>
      <AbsoluteFill style={{alignItems: 'center', paddingTop: 150}}>
        <div key={actual} style={{fontFamily: fuente}}>
          <TextoEntra texto={PANTALLAS[actual].texto} desde={0} tamano={96} ancho={920} />
        </div>
      </AbsoluteFill>
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'flex-end', transform: `translateY(${(1 - entra) * 900}px)`}}>
        {PANTALLAS.map((p, i) => {
          const d = i - posicion;
          return (
            <div
              key={p.captura}
              style={{
                position: 'absolute',
                bottom: -380,
                left: '50%',
                marginLeft: -369,
                transform: `translateX(${d * 720}px) rotate(${d * 6}deg) scale(${1 - Math.min(Math.abs(d), 1) * 0.12})`,
                opacity: 1 - Math.min(Math.abs(d), 1) * 0.5,
              }}
            >
              <Telefono ancho={690} captura={p.captura} />
            </div>
          );
        })}
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

export const Lanzamiento: React.FC = () => (
  <AbsoluteFill style={{background: C.fondo}}>
    <Voz video={V} i={0} desde={4} />
    {INICIOS_P.slice(0, PANTALLAS.length).map((desde, i) => (
      <Voz key={i} video={V} i={i + 1} desde={INTRO + desde + 3} />
    ))}
    <Voz video={V} i={5} desde={INTRO + CARRUSEL + 4} />
    <Sequence durationInFrames={INTRO}>
      <Gancho />
    </Sequence>
    <Sequence from={INTRO} durationInFrames={CARRUSEL}>
      <Carrusel />
    </Sequence>
    <Sequence from={INTRO + CARRUSEL}>
      <Cierre desde={0} />
    </Sequence>
  </AbsoluteFill>
);

export const DURACION_LANZAMIENTO = INTRO + CARRUSEL + Math.max(80, fv(V, 5) + 24);
