import React from 'react';
import {AbsoluteFill, Sequence, interpolate, random, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {Aparece, C, Cierre, TextoEntra, Voz, fuente, fv, tramo} from '../marca';

// 3 · «Mi año comiendo en Vigo»: los pines van apareciendo con su nota y su color.
const CIUDAD = 'Vigo';
const N = 23;
const V = '03-Mapa';
const L1 = 3 + fv(V, 0);
const L2 = L1 + fv(V, 1);
const CIERRE = Math.max(270, L2 + fv(V, 2) + 10);
export const DURACION_MAPA = CIERRE + Math.max(70, fv(V, 3) + 24);
// Los pines salen mientras suenan las dos primeras frases.
const PASO = (L2 - 30) / N;

type Pin = {x: number; y: number; nota: number; cuando: number};

// Rejilla de 5 × 5 con un poco de ruido para que los pines no se monten unos sobre otros.
const pines: Pin[] = Array.from({length: N}, (_, i) => {
  const nota = Math.round((3 + random(`nota-${i}`) * 2) * 10) / 10;
  return {
    x: 150 + (i % 5) * 195 + (random(`x-${i}`) - 0.5) * 90,
    y: 560 + Math.floor(i / 5) * 230 + (random(`y-${i}`) - 0.5) * 110,
    nota: Math.min(nota, 5),
    cuando: 0,
  };
});
// Aparecen en orden aleatorio (pero fijo), no fila a fila.
[...pines.keys()]
  .sort((a, b) => random(`orden-${a}`) - random(`orden-${b}`))
  .forEach((indice, puesto) => {
    pines[indice].cuando = Math.round(30 + puesto * PASO);
  });

const colorPin = (nota: number) => (nota >= 4.5 ? C.pinTop : nota >= 3.5 ? C.pinBien : C.pinNormal);

const Calles: React.FC = () => {
  // Trazado inventado: calles en diagonal, avenidas y una ría. No es un mapa real.
  const lineas = Array.from({length: 18}, (_, i) => i);
  return (
    <svg width={1080} height={1920} style={{position: 'absolute'}}>
      <rect width="1080" height="1920" fill="#F6EFE6" />
      <path d="M-50 380 C 300 300, 700 460, 1130 330 L1130 -10 L-50 -10 Z" fill="#DCE7EA" />
      {lineas.map((i) => (
        <line key={`a${i}`} x1={-100 + i * 80} y1={300} x2={300 + i * 80} y2={2000} stroke="#FFFFFF" strokeWidth={i % 4 === 0 ? 22 : 10} />
      ))}
      {lineas.map((i) => (
        <line key={`b${i}`} x1={-100} y1={420 + i * 95} x2={1200} y2={300 + i * 95} stroke="#FFFFFF" strokeWidth={i % 5 === 0 ? 22 : 10} />
      ))}
      <circle cx="760" cy="1180" r="120" fill="#E3EBD9" />
      <circle cx="260" cy="1520" r="90" fill="#E3EBD9" />
    </svg>
  );
};

const PinMapa: React.FC<{pin: Pin}> = ({pin}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const s = spring({frame: frame - pin.cuando, fps, config: {damping: 9, stiffness: 180}});
  if (frame < pin.cuando) return null;
  const fondo = colorPin(pin.nota);
  const texto = fondo === C.pinTop ? '#FFFFFF' : C.tinta;
  return (
    <div
      style={{
        position: 'absolute',
        left: pin.x,
        top: pin.y,
        transform: `translate(-50%, -100%) scale(${s})`,
        transformOrigin: '50% 100%',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
      }}
    >
      <div
        style={{
          background: fondo,
          color: texto,
          border: '5px solid #fff',
          borderRadius: 999,
          padding: '8px 20px',
          fontFamily: fuente,
          fontWeight: 900,
          fontSize: 36,
          boxShadow: '0 8px 18px rgba(31,26,22,0.22)',
        }}
      >
        {pin.nota.toLocaleString('es-ES', {minimumFractionDigits: 1})}
      </div>
      <div style={{width: 0, height: 0, borderLeft: '12px solid transparent', borderRight: '12px solid transparent', borderTop: '16px solid #fff', marginTop: -2}} />
    </div>
  );
};

export const Mapa: React.FC = () => {
  const frame = useCurrentFrame();
  const zoom = interpolate(frame, [0, L2 + 30], [1.18, 1], {extrapolateRight: 'clamp'});
  const visibles = pines.filter((p) => frame >= p.cuando).length;
  return (
    <AbsoluteFill style={{background: C.fondo}}>
      <Voz video={V} i={0} desde={3} />
      <Voz video={V} i={1} desde={L1} />
      <Voz video={V} i={2} desde={L2} />
      <Voz video={V} i={3} desde={CIERRE + 4} />
      <AbsoluteFill style={{transform: `scale(${zoom})`}}>
        <Calles />
        {pines.map((p, i) => (
          <PinMapa key={i} pin={p} />
        ))}
      </AbsoluteFill>

      <AbsoluteFill style={{alignItems: 'center', paddingTop: 140}}>
        <div style={{background: C.fondo, borderRadius: 48, padding: '34px 50px', boxShadow: '0 20px 50px rgba(31,26,22,0.12)'}}>
          <TextoEntra texto={`Mi año comiendo en ${CIUDAD}`} desde={4} tamano={78} ancho={820} />
        </div>
      </AbsoluteFill>

      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'flex-end', paddingBottom: 200}}>
        <Aparece desde={40}>
          <div
            style={{
              background: C.superficie,
              borderRadius: 999,
              padding: '26px 54px',
              fontFamily: fuente,
              fontWeight: 900,
              fontSize: 62,
              color: C.tinta,
              boxShadow: '0 20px 50px rgba(31,26,22,0.14)',
              fontVariantNumeric: 'tabular-nums',
            }}
          >
            <span style={{color: C.tomate}}>{visibles}</span> sitios · <span style={{opacity: tramo(frame, L2 + 50, L2 + 60)}}>{pines.filter((p) => p.nota >= 4.5).length} imprescindibles</span>
          </div>
        </Aparece>
      </AbsoluteFill>

      <Sequence from={CIERRE}>
        <Cierre desde={0} frase="Tu mapa, tus sitios" />
      </Sequence>
    </AbsoluteFill>
  );
};
