import React from 'react';
import {
  AbsoluteFill,
  Img,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';
import {loadFont} from '@remotion/google-fonts/Nunito';
import {Audio, Sequence} from 'remotion';
import duraciones from '../public/voz/duraciones.json';

// ── Voz en off ──────────────────────────────────────────────────────────────
// Las frases las genera voz.py; las escenas se alargan para que quepa cada frase.
type VideoConVoz = keyof typeof duraciones;
const COLA_ECO = 0.35; // segundos de eco al final de cada frase, que pueden pisar la siguiente

/** Fotogramas que ocupa la frase `i` del vídeo, sin la cola del eco y con un respiro. */
export const fv = (video: VideoConVoz, i: number, respiro = 6) =>
  Math.ceil((duraciones[video][i] - COLA_ECO) * 30) + respiro;

/** Suena la frase `i` a partir del fotograma `desde`. */
export const Voz: React.FC<{video: VideoConVoz; i: number; desde: number}> = ({video, i, desde}) => (
  <Sequence from={desde} layout="none">
    <Audio src={staticFile(`voz/${video}-${i}.wav`)} />
  </Sequence>
);

// SF Pro Rounded no se puede usar fuera de Apple: Nunito es la redondeada más parecida.
export const {fontFamily: fuente} = loadFont('normal', {
  weights: ['600', '700', '800', '900'],
  subsets: ['latin', 'latin-ext'],
});

/** Paleta de DESIGN.md §3 (valores claros). */
export const C = {
  tomate: '#D2381F',
  tomateSuave: '#FBE3DC',
  tomateTexto: '#A8291A',
  fondo: '#FBF6F0',
  superficie: '#FFFFFF',
  hundida: '#F3ECE4',
  linea: '#EADFD3',
  tinta: '#1F1A16',
  secundario: '#6B6158',
  estrella: '#F0A202',
  estrellaVacia: '#DCCFC2',
  albahaca: '#3F5A30',
  verde: '#1F5A37',
  verdeSuave: '#DDEFE3',
  pinTop: '#B02A17',
  pinBien: '#EE8A3C',
  pinNormal: '#8E8379',
  fondoOscuro: '#17130F',
};

/** Muelle con el mismo carácter en todas las piezas: rápido y con un pelín de rebote. */
export const useMuelle = (desde: number, opciones?: {damping?: number; duracion?: number}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  return spring({
    frame: frame - desde,
    fps,
    config: {damping: opciones?.damping ?? 14, mass: 0.8, stiffness: 140},
    durationInFrames: opciones?.duracion,
  });
};

/** 0 → 1 lineal entre dos fotogramas, con recorte. */
export const tramo = (frame: number, a: number, b: number) =>
  interpolate(frame, [a, b], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});

/** El tomate con la estrella de cáliz (Brand/simbolo.svg). */
export const Simbolo: React.FC<{tamano: number; monocromo?: string; oscuro?: boolean; style?: React.CSSProperties}> = ({
  tamano,
  monocromo,
  oscuro,
  style,
}) => {
  if (oscuro) {
    // Versión oscura del icono: tomate y albahaca más claros y sin brillo.
    return (
      <svg width={tamano} height={tamano} viewBox="0 0 100 100" style={style}>
        <path fill="#FF5A3C" d="M50 30C73 25 91 40 90 61C89 81 71 93 50 93C29 93 11 81 10 61C9 40 27 25 50 30Z" />
        <path fill="#7FA866" stroke="#7FA866" strokeWidth="3.5" strokeLinejoin="round" d="M50 18L54.4 28.9L66.2 29.8L57.1 37.3L60 48.8L50 42.5L40 48.8L42.9 37.3L33.8 29.8L45.6 28.9Z" />
        <path d="M50 22C50 16 52 11 56 8" fill="none" stroke="#7FA866" strokeWidth="4.5" strokeLinecap="round" />
      </svg>
    );
  }
  if (monocromo) {
    return (
      <svg width={tamano} height={tamano} viewBox="0 0 100 100" style={style}>
        <defs>
          <mask id="recorte">
            <rect width="100" height="100" fill="white" />
            <path
              d="M50 18L54.4 28.9L66.2 29.8L57.1 37.3L60 48.8L50 42.5L40 48.8L42.9 37.3L33.8 29.8L45.6 28.9Z"
              fill="black"
              stroke="black"
              strokeWidth="7"
              strokeLinejoin="round"
            />
          </mask>
        </defs>
        <path mask="url(#recorte)" fill={monocromo} d="M50 30C73 25 91 40 90 61C89 81 71 93 50 93C29 93 11 81 10 61C9 40 27 25 50 30Z" />
        <path
          fill={monocromo}
          stroke={monocromo}
          strokeWidth="3.5"
          strokeLinejoin="round"
          d="M50 18L54.4 28.9L66.2 29.8L57.1 37.3L60 48.8L50 42.5L40 48.8L42.9 37.3L33.8 29.8L45.6 28.9Z"
        />
        <path d="M50 22C50 16 52 11 56 8" fill="none" stroke={monocromo} strokeWidth="4.5" strokeLinecap="round" />
      </svg>
    );
  }
  return <Img src={staticFile('simbolo.svg')} style={{width: tamano, height: tamano, ...style}} />;
};

/** «rico» en minúsculas, redondeada Black, interletraje −3 %. */
export const Palabra: React.FC<{tamano: number; color?: string}> = ({tamano, color = C.tinta}) => (
  <span
    style={{
      fontFamily: fuente,
      fontWeight: 900,
      fontSize: tamano,
      letterSpacing: -tamano * 0.03,
      color,
      lineHeight: 1,
    }}
  >
    rico
  </span>
);

/** Texto que entra subiendo desde una máscara, palabra a palabra. */
export const TextoEntra: React.FC<{
  texto: string;
  desde: number;
  tamano: number;
  color?: string;
  peso?: number;
  retardo?: number;
  alinear?: 'left' | 'center';
  ancho?: number;
}> = ({texto, desde, tamano, color = C.tinta, peso = 900, retardo = 3, alinear = 'center', ancho}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const palabras = texto.split(' ');
  return (
    <div
      style={{
        fontFamily: fuente,
        fontWeight: peso,
        fontSize: tamano,
        lineHeight: 1.05,
        letterSpacing: -tamano * 0.025,
        color,
        textAlign: alinear,
        display: 'flex',
        flexWrap: 'wrap',
        justifyContent: alinear === 'center' ? 'center' : 'flex-start',
        columnGap: tamano * 0.26,
        width: ancho,
      }}
    >
      {palabras.map((p, i) => {
        const s = spring({
          frame: frame - desde - i * retardo,
          fps,
          config: {damping: 16, mass: 0.7, stiffness: 160},
        });
        return (
          <span key={i} style={{display: 'inline-block', overflow: 'hidden', paddingBottom: tamano * 0.12}}>
            <span
              style={{
                display: 'inline-block',
                transform: `translateY(${(1 - s) * 110}%)`,
              }}
            >
              {p}
            </span>
          </span>
        );
      })}
    </div>
  );
};

/** iPhone sencillo: marco tinta y pantalla con una captura real de la app. */
export const Telefono: React.FC<{
  ancho: number;
  captura?: string;
  children?: React.ReactNode;
  style?: React.CSSProperties;
}> = ({ancho, captura, children, style}) => {
  const alto = ancho * (2622 / 1206);
  const borde = ancho * 0.035;
  return (
    <div
      style={{
        width: ancho + borde * 2,
        height: alto + borde * 2,
        borderRadius: ancho * 0.16,
        background: C.tinta,
        padding: borde,
        boxShadow: '0 40px 80px rgba(31,26,22,0.18)',
        ...style,
      }}
    >
      <div
        style={{
          width: ancho,
          height: alto,
          borderRadius: ancho * 0.13,
          overflow: 'hidden',
          position: 'relative',
          background: C.fondo,
        }}
      >
        {captura ? (
          <Img src={staticFile(`capturas/${captura}.png`)} style={{width: '100%', height: '100%', objectFit: 'cover'}} />
        ) : null}
        {children}
      </div>
    </div>
  );
};

/** Final común: logotipo vertical y la frase de cierre. */
export const Cierre: React.FC<{desde: number; frase?: string; oscuro?: boolean}> = ({
  desde,
  frase = 'Tu diario de restaurantes',
  oscuro = false,
}) => {
  const frame = useCurrentFrame();
  const s = useMuelle(desde);
  const latido = useMuelle(desde + 10, {damping: 8});
  const sub = tramo(frame, desde + 14, desde + 24);
  return (
    <AbsoluteFill
      style={{
        background: oscuro ? C.fondoOscuro : C.fondo,
        alignItems: 'center',
        justifyContent: 'center',
        opacity: tramo(frame, desde, desde + 6),
      }}
    >
      <div style={{transform: `scale(${0.6 + 0.4 * s + 0.06 * Math.sin(latido * Math.PI)})`, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10}}>
        <Simbolo tamano={220} oscuro={oscuro} />
        <Palabra tamano={170} color={oscuro ? '#F5EEE6' : C.tinta} />
      </div>
      <div
        style={{
          marginTop: 40,
          fontFamily: fuente,
          fontWeight: 800,
          fontSize: 52,
          color: oscuro ? '#B5A99D' : C.secundario,
          maxWidth: 900,
          textAlign: 'center',
          lineHeight: 1.15,
          opacity: sub,
          transform: `translateY(${(1 - sub) * 20}px)`,
        }}
      >
        {frase}
      </div>
      <div
        style={{
          marginTop: 28,
          fontFamily: fuente,
          fontWeight: 900,
          fontSize: 44,
          color: C.superficie,
          background: C.tomate,
          padding: '18px 40px',
          borderRadius: 999,
          opacity: tramo(frame, desde + 22, desde + 30),
        }}
      >
        Pronto en iPhone
      </div>
    </AbsoluteFill>
  );
};

/** Aparece con un fundido corto y sube un poco. */
export const Aparece: React.FC<{desde: number; children: React.ReactNode; style?: React.CSSProperties}> = ({
  desde,
  children,
  style,
}) => {
  const s = useMuelle(desde, {damping: 18});
  return <div style={{opacity: s, transform: `translateY(${(1 - s) * 40}px)`, ...style}}>{children}</div>;
};

/** Estrellas de la nota, rellenándose una a una. */
export const Estrellas: React.FC<{nota: number; desde: number; tamano: number}> = ({nota, desde, tamano}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  return (
    <div style={{display: 'flex', gap: tamano * 0.18}}>
      {[0, 1, 2, 3, 4].map((i) => {
        const s = spring({frame: frame - desde - i * 4, fps, config: {damping: 9, stiffness: 200}});
        const llena = i < nota && frame >= desde + i * 4;
        return (
          <svg key={i} width={tamano} height={tamano} viewBox="0 0 24 24" style={{transform: `scale(${llena ? 0.7 + 0.3 * s : 1})`}}>
            <path
              d="M12 2.5l2.9 6.1 6.6.7-4.9 4.5 1.4 6.6L12 17.1l-6 3.3 1.4-6.6L2.5 9.3l6.6-.7z"
              fill={llena ? C.estrella : C.estrellaVacia}
              stroke={llena ? C.estrella : C.estrellaVacia}
              strokeWidth="1.5"
              strokeLinejoin="round"
            />
          </svg>
        );
      })}
    </div>
  );
};
