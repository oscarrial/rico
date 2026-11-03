import React from 'react';
import {AbsoluteFill} from 'remotion';
import {C, LLAMADA, Palabra, Simbolo, Telefono, fuente} from './marca';

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
      <Pastilla tamano={28} />
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

/** La llamada en cápsula tomate, como en el cierre de los vídeos. */
const Pastilla: React.FC<{tamano: number; invertida?: boolean}> = ({tamano, invertida}) => (
  <div
    style={{
      alignSelf: 'flex-start',
      display: 'inline-block',
      fontFamily: fuente,
      fontWeight: 900,
      fontSize: tamano,
      color: invertida ? C.tomate : C.superficie,
      background: invertida ? C.fondo : C.tomate,
      padding: `${tamano * 0.4}px ${tamano * 0.9}px`,
      borderRadius: 999,
    }}
  >
    {LLAMADA}
  </div>
);

/** Post de lanzamiento (1080 × 1350, Instagram y LinkedIn): titular, llamada y dos pantallas. */
export const PostLanzamiento: React.FC = () => (
  <AbsoluteFill style={{background: C.fondo, padding: '90px 80px 0', overflow: 'hidden'}}>
    <div style={{display: 'flex', alignItems: 'center', gap: 14}}>
      <Simbolo tamano={72} />
      <Palabra tamano={72} />
    </div>
    <div style={{marginTop: 46, fontFamily: fuente, fontWeight: 900, fontSize: 96, color: C.tinta, letterSpacing: -2.6, lineHeight: 1.02}}>
      Cada sitio donde comes, <span style={{color: C.tomate}}>guardado solo.</span>
    </div>
    <div style={{marginTop: 34}}>
      <Pastilla tamano={40} />
    </div>
    <div style={{position: 'absolute', left: 120, top: 760, transform: 'rotate(-7deg)'}}>
      <Telefono ancho={400} captura="ficha-light" />
    </div>
    <div style={{position: 'absolute', left: 560, top: 700, transform: 'rotate(6deg)'}}>
      <Telefono ancho={400} captura="diario-light" />
    </div>
  </AbsoluteFill>
);

/** Historia 9:16 a una tinta (DESIGN.md §12): fondo tomate, un dato grande, marca arriba y la web abajo. */
export const HistoriaLanzamiento: React.FC = () => (
  <AbsoluteFill style={{background: C.tomate, alignItems: 'center', padding: '150px 90px 140px'}}>
    <div style={{display: 'flex', alignItems: 'center', gap: 14}}>
      <Simbolo tamano={80} monocromo={C.fondo} />
      <Palabra tamano={80} color={C.fondo} />
    </div>
    <div style={{flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', gap: 40}}>
      <div style={{fontFamily: fuente, fontWeight: 900, fontSize: 150, color: C.fondo, letterSpacing: -4.5, lineHeight: 0.98, textAlign: 'center'}}>
        Ya en la App Store
      </div>
      <div style={{fontFamily: fuente, fontWeight: 800, fontSize: 52, color: C.fondo, opacity: 0.9, textAlign: 'center', lineHeight: 1.2}}>
        Tu diario de restaurantes. Pagas, valoras en 10 segundos y queda guardado.
      </div>
    </div>
    <div style={{fontFamily: fuente, fontWeight: 900, fontSize: 44, color: C.fondo}}>rico.app</div>
  </AbsoluteFill>
);
