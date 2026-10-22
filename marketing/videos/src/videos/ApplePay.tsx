import React from 'react';
import {AbsoluteFill, Sequence, interpolate, useCurrentFrame} from 'remotion';
import {C, Cierre, Estrellas, Telefono, TextoEntra, Voz, fuente, fv, tramo, useMuelle} from '../marca';

// 1 · «Así funciona en 10 segundos»: pagas, Rico te pregunta y valoras.
// Cada fase dura lo que su frase de voz en off (mínimo, lo que necesita la animación).
const V = '01-ApplePay';
const PAGO = 0;
const AVISO = Math.max(120, 3 + fv(V, 0) + fv(V, 1));
const VALORA = AVISO + Math.max(80, fv(V, 2));
const CIERRE = VALORA + Math.max(110, fv(V, 3));
export const DURACION_APPLEPAY = CIERRE + Math.max(70, fv(V, 4) + 20);

export const ApplePay: React.FC = () => {
  const entraTelefono = useMuelle(30);
  return (
    <AbsoluteFill style={{background: C.fondo}}>
      <Voz video={V} i={0} desde={3} />
      <Voz video={V} i={1} desde={3 + fv(V, 0)} />
      <Voz video={V} i={2} desde={AVISO} />
      <Voz video={V} i={3} desde={VALORA} />
      <Voz video={V} i={4} desde={CIERRE + 4} />

      <AbsoluteFill style={{alignItems: 'center', paddingTop: 170}}>
        <Sequence durationInFrames={AVISO} layout="none">
          <TextoEntra texto="Pagas la cena." desde={4} tamano={110} />
        </Sequence>
        <Sequence from={AVISO} durationInFrames={VALORA - AVISO} layout="none">
          <TextoEntra texto="Rico te pregunta." desde={0} tamano={110} />
        </Sequence>
        <Sequence from={VALORA} durationInFrames={CIERRE - VALORA} layout="none">
          <TextoEntra texto="Valoras en 10 s." desde={0} tamano={110} color={C.tomate} />
        </Sequence>
      </AbsoluteFill>

      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'flex-end', paddingBottom: 70}}>
        <div style={{transform: `translateY(${(1 - entraTelefono) * 1500}px)`}}>
          <Telefono ancho={630} captura="diario-light">
            <Sequence from={PAGO + 40} durationInFrames={AVISO - 40} layout="none">
              <HojaApplePay />
            </Sequence>
            <Sequence from={AVISO + 4} durationInFrames={VALORA - AVISO - 4} layout="none">
              <Aviso dura={VALORA - AVISO - 4} />
            </Sequence>
            <Sequence from={VALORA} durationInFrames={CIERRE - VALORA} layout="none">
              <Valoracion />
            </Sequence>
          </Telefono>
        </div>
      </AbsoluteFill>

      <Sequence from={CIERRE}>
        <Cierre desde={0} />
      </Sequence>
    </AbsoluteFill>
  );
};

const HojaApplePay: React.FC = () => {
  const frame = useCurrentFrame();
  const s = useMuelle(0);
  const hecho = tramo(frame, 34, 42);
  const sale = tramo(frame, 66, 78);
  return (
    <AbsoluteFill style={{background: `rgba(0,0,0,${0.35 * s * (1 - sale)})`, justifyContent: 'flex-end'}}>
      <div
        style={{
          background: '#fff',
          borderTopLeftRadius: 56,
          borderTopRightRadius: 56,
          padding: '50px 50px 120px',
          transform: `translateY(${(1 - s) * 100 + sale * 100}%)`,
          fontFamily: '-apple-system, Helvetica, Arial',
        }}
      >
        <div style={{fontSize: 40, fontWeight: 800, color: '#000', fontFamily: fuente}}>Apple Pay</div>
        <div style={{marginTop: 40, display: 'flex', justifyContent: 'space-between', fontSize: 36, color: '#000'}}>
          <span style={{fontFamily: fuente, fontWeight: 800}}>Taberna O Grelo</span>
          <span style={{fontFamily: fuente, fontWeight: 900}}>48,00 €</span>
        </div>
        <div style={{marginTop: 60, display: 'flex', justifyContent: 'center'}}>
          <div
            style={{
              width: 120,
              height: 120,
              borderRadius: 60,
              border: `6px solid ${hecho > 0 ? '#34C759' : '#0A84FF'}`,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 64,
              color: '#34C759',
              transform: `rotate(${frame * (hecho > 0 ? 0 : 12)}deg)`,
              borderTopColor: hecho > 0 ? '#34C759' : 'transparent',
            }}
          >
            {hecho > 0 ? <span style={{opacity: hecho, transform: `scale(${hecho})`}}>✓</span> : null}
          </div>
        </div>
        <div style={{textAlign: 'center', marginTop: 24, fontSize: 32, color: '#666', fontFamily: fuente, fontWeight: 700}}>
          {hecho > 0 ? 'Hecho' : 'Pagando…'}
        </div>
      </div>
    </AbsoluteFill>
  );
};

const Aviso: React.FC<{dura: number}> = ({dura}) => {
  const frame = useCurrentFrame();
  const s = useMuelle(0);
  const sale = tramo(frame, dura - 11, dura);
  return (
    <AbsoluteFill style={{alignItems: 'center', paddingTop: 70}}>
      <div
        style={{
          width: '93%',
          boxSizing: 'border-box',
          background: 'rgba(255,255,255,0.96)',
          borderRadius: 44,
          padding: 28,
          display: 'flex',
          gap: 22,
          alignItems: 'center',
          boxShadow: '0 20px 50px rgba(0,0,0,0.18)',
          transform: `translateY(${(1 - s) * -260 - sale * 300}px) scale(${0.9 + 0.1 * s})`,
        }}
      >
        <div style={{width: 84, height: 84, borderRadius: 20, background: C.fondo, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0}}>
          <svg width="64" height="64" viewBox="0 0 100 100">
            <path fill={C.tomate} d="M50 30C73 25 91 40 90 61C89 81 71 93 50 93C29 93 11 81 10 61C9 40 27 25 50 30Z" />
            <path fill={C.albahaca} d="M50 18L54.4 28.9L66.2 29.8L57.1 37.3L60 48.8L50 42.5L40 48.8L42.9 37.3L33.8 29.8L45.6 28.9Z" />
          </svg>
        </div>
        <div style={{fontFamily: fuente}}>
          <div style={{fontSize: 26, fontWeight: 800, color: C.secundario}}>RICO · ahora</div>
          <div style={{fontSize: 34, fontWeight: 900, color: C.tinta, marginTop: 4}}>¿Qué tal en Taberna O Grelo?</div>
          <div style={{fontSize: 28, fontWeight: 700, color: C.secundario, marginTop: 2}}>Toca para valorar en 10 segundos</div>
        </div>
      </div>
    </AbsoluteFill>
  );
};

const Valoracion: React.FC = () => {
  const frame = useCurrentFrame();
  const s = useMuelle(0);
  const guardado = useMuelle(118);
  return (
    <AbsoluteFill style={{justifyContent: 'flex-end'}}>
      <div
        style={{
          background: C.superficie,
          borderTopLeftRadius: 56,
          borderTopRightRadius: 56,
          padding: '48px 48px 120px',
          fontFamily: fuente,
          transform: `translateY(${(1 - s) * 100}%)`,
          boxShadow: '0 -20px 60px rgba(0,0,0,0.12)',
        }}
      >
        <div style={{fontSize: 48, fontWeight: 900, color: C.tinta}}>Taberna O Grelo</div>
        <div style={{fontSize: 30, fontWeight: 700, color: C.secundario, marginTop: 6}}>Hoy · 48,00 € · 2 personas</div>
        <div style={{marginTop: 40}}>
          <Estrellas nota={5} desde={45} tamano={92} />
        </div>
        <div style={{display: 'flex', gap: 16, marginTop: 40}}>
          {['Sí', 'Quizá', 'No'].map((op, i) => {
            const activa = i === 0 && frame > 90;
            return (
              <div
                key={op}
                style={{
                  flex: 1,
                  textAlign: 'center',
                  padding: '24px 0',
                  borderRadius: 24,
                  fontSize: 34,
                  fontWeight: 900,
                  background: activa ? C.tomate : C.superficie,
                  color: activa ? '#fff' : C.tinta,
                  border: `3px solid ${activa ? C.tomate : C.linea}`,
                }}
              >
                {op}
              </div>
            );
          })}
        </div>
        <div style={{marginTop: 22, fontSize: 28, fontWeight: 800, color: C.secundario}}>¿Volverías?</div>
        <div
          style={{
            marginTop: 30,
            background: C.verdeSuave,
            color: C.verde,
            borderRadius: 999,
            padding: '20px 30px',
            fontSize: 34,
            fontWeight: 900,
            textAlign: 'center',
            opacity: guardado,
            transform: `scale(${interpolate(guardado, [0, 1], [0.8, 1])})`,
          }}
        >
          ✓ Guardado en tu diario
        </div>
      </div>
    </AbsoluteFill>
  );
};
