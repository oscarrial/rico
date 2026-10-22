import React from 'react';
import {AbsoluteFill} from 'remotion';
import {C, Palabra, Simbolo, Telefono, fuente} from './marca';

/** Foto de perfil: el tomate centrado sobre crema, con el espacio libre de DESIGN.md. */
export const Perfil: React.FC = () => (
  <AbsoluteFill style={{background: C.fondo, alignItems: 'center', justifyContent: 'center'}}>
    <Simbolo tamano={620} />
  </AbsoluteFill>
);

/** Banner de X (1500 × 500): logotipo, frase y dos pantallas reales. */
export const Banner: React.FC = () => (
  <AbsoluteFill style={{background: C.fondo, flexDirection: 'row', alignItems: 'center', padding: '0 0 0 340px'}}>
    <div style={{display: 'flex', flexDirection: 'column', gap: 16, flex: 1}}>
      <div style={{display: 'flex', alignItems: 'center', gap: 14}}>
        <Simbolo tamano={84} />
        <Palabra tamano={84} />
      </div>
      <div style={{fontFamily: fuente, fontWeight: 900, fontSize: 52, color: C.tinta, letterSpacing: -1.2, lineHeight: 1.05}}>
        Tu diario de restaurantes.
      </div>
      <div style={{fontFamily: fuente, fontWeight: 800, fontSize: 30, color: C.secundario}}>
        Pagas, valoras en 10 segundos y nunca olvidas un sitio.
      </div>
    </div>
    <div style={{width: 520, height: 500, position: 'relative', overflow: 'hidden'}}>
      <div style={{position: 'absolute', left: 30, top: 70, transform: 'rotate(-8deg)'}}>
        <Telefono ancho={200} captura="ficha-light" />
      </div>
      <div style={{position: 'absolute', left: 250, top: 40, transform: 'rotate(6deg)'}}>
        <Telefono ancho={200} captura="diario-light" />
      </div>
    </div>
  </AbsoluteFill>
);
