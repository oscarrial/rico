import React from 'react';
import {AbsoluteFill} from 'remotion';
import {C, Palabra, Simbolo, TextoEntra, fuente} from './marca';

/** Versión 16:9 para X: el vídeo vertical a la derecha y el titular a la izquierda. */
export const Horizontal: React.FC<{titular: string; subtitulo: string; children: React.ReactNode}> = ({
  titular,
  subtitulo,
  children,
}) => {
  const escala = 1080 / 1920;
  return (
    <AbsoluteFill style={{background: C.fondo, flexDirection: 'row'}}>
      <div style={{flex: 1, padding: '0 90px', display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 34}}>
        <div style={{display: 'flex', alignItems: 'center', gap: 18}}>
          <Simbolo tamano={84} />
          <Palabra tamano={76} />
        </div>
        <TextoEntra texto={titular} desde={6} tamano={96} alinear="left" ancho={1000} />
        <div style={{fontFamily: fuente, fontWeight: 800, fontSize: 44, color: C.secundario, maxWidth: 900}}>{subtitulo}</div>
      </div>
      <div style={{width: 1080 * escala + 80, display: 'flex', alignItems: 'center', justifyContent: 'center'}}>
        <div
          style={{
            width: 1080,
            height: 1920,
            transform: `scale(${escala * 0.94})`,
            transformOrigin: 'center',
            flexShrink: 0,
            borderRadius: 60,
            overflow: 'hidden',
            boxShadow: '0 30px 80px rgba(31,26,22,0.18)',
            position: 'relative',
          }}
        >
          {children}
        </div>
      </div>
    </AbsoluteFill>
  );
};
