import React from 'react';
import {AbsoluteFill, Sequence, useCurrentFrame} from 'remotion';
import {Aparece, C, Cierre, Telefono, TextoEntra, Voz, fuente, fv, useMuelle} from '../marca';

const V = '04-POV';
// Mínimos de cada escena (la animación) y una frase por escena.
const MINIMOS = [30, 50, 35, 55, 30, 75];
const LARGO = MINIMOS.map((m, i) => Math.max(m, fv(V, i, 2)));
const INICIO = LARGO.reduce<number[]>((acc, l, i) => [...acc, acc[i] + l], [0]);
export const DURACION_POV = INICIO[6] + Math.max(70, fv(V, 6) + 24);

// 4 · Situación de todos, para TikTok: gancho en el primer segundo y texto que se lee sin sonido.
const Linea: React.FC<{texto: string; color?: string; tamano?: number; fondo?: string}> = ({
  texto,
  color = C.tinta,
  tamano = 120,
  fondo,
}) => (
  <AbsoluteFill style={{background: fondo, alignItems: 'center', justifyContent: 'center', padding: 80}}>
    <TextoEntra texto={texto} desde={0} tamano={tamano} color={color} ancho={920} retardo={2} />
  </AbsoluteFill>
);

const Duda: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{background: C.fondoOscuro, alignItems: 'center', justifyContent: 'center', padding: 80}}>
      <TextoEntra texto="y no te acuerdas del nombre" desde={0} tamano={120} color="#F5EEE6" ancho={920} retardo={2} />
      <div style={{display: 'flex', gap: 40, marginTop: 60}}>
        {[0, 1, 2].map((i) => (
          <span
            key={i}
            style={{
              fontFamily: fuente,
              fontWeight: 900,
              fontSize: 140,
              color: '#FF6A4D',
              transform: `translateY(${Math.sin((frame + i * 6) / 4) * 18}px) rotate(${Math.sin((frame + i * 9) / 5) * 12}deg)`,
              opacity: frame > 14 + i * 4 ? 1 : 0,
            }}
          >
            ?
          </span>
        ))}
      </div>
    </AbsoluteFill>
  );
};

const ConRico: React.FC = () => {
  const s = useMuelle(0, {damping: 10});
  return (
    <AbsoluteFill style={{background: C.tomate, alignItems: 'center', justifyContent: 'center'}}>
      <div
        style={{
          fontFamily: fuente,
          fontWeight: 900,
          fontSize: 190,
          letterSpacing: -6,
          color: C.fondo,
          transform: `scale(${0.5 + 0.5 * s})`,
        }}
      >
        Con Rico, sí.
      </div>
    </AbsoluteFill>
  );
};

const Lista: React.FC = () => {
  const s = useMuelle(0);
  return (
    <AbsoluteFill style={{background: C.fondo, alignItems: 'center'}}>
      <div style={{paddingTop: 150}}>
        <TextoEntra texto="Lo guardas en «Quiero probar»" desde={2} tamano={84} ancho={900} />
      </div>
      <div style={{position: 'absolute', bottom: -420, transform: `translateY(${(1 - s) * 900}px)`}}>
        <Telefono ancho={700} captura="listas-light" />
      </div>
      <Aparece desde={26} style={{position: 'absolute', bottom: 260}}>
        <div
          style={{
            background: C.superficie,
            borderRadius: 999,
            padding: '24px 46px',
            fontFamily: fuente,
            fontWeight: 900,
            fontSize: 52,
            color: C.tinta,
            boxShadow: '0 20px 50px rgba(31,26,22,0.18)',
          }}
        >
          y aparece en tu mapa
        </div>
      </Aparece>
    </AbsoluteFill>
  );
};

export const POV: React.FC = () => (
  <AbsoluteFill style={{background: C.fondo}}>
    {INICIO.map((desde, i) => (
      <Voz key={i} video={V} i={i} desde={desde + (i === 6 ? 4 : 1)} />
    ))}
    <Sequence durationInFrames={LARGO[0]}>
      <Linea texto="POV:" color={C.tomate} tamano={260} />
    </Sequence>
    <Sequence from={INICIO[1]} durationInFrames={LARGO[1]}>
      <Linea texto="te recomendaron un sitio buenísimo" />
    </Sequence>
    <Sequence from={INICIO[2]} durationInFrames={LARGO[2]}>
      <Linea texto="hace 3 meses" tamano={150} />
    </Sequence>
    <Sequence from={INICIO[3]} durationInFrames={LARGO[3]}>
      <Duda />
    </Sequence>
    <Sequence from={INICIO[4]} durationInFrames={LARGO[4]}>
      <ConRico />
    </Sequence>
    <Sequence from={INICIO[5]} durationInFrames={LARGO[5]}>
      <Lista />
    </Sequence>
    <Sequence from={INICIO[6]}>
      <Cierre desde={0} frase="Guarda dónde comes y dónde quieres comer" />
    </Sequence>
  </AbsoluteFill>
);
