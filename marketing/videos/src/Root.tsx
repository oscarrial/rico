import React from 'react';
import {Composition, Still} from 'remotion';
import {ApplePay, DURACION_APPLEPAY} from './videos/ApplePay';
import {DURACION_TUANO, TuAno} from './videos/TuAno';
import {DURACION_MAPA, Mapa} from './videos/Mapa';
import {DURACION_POV, POV} from './videos/POV';
import {DURACION_EN_PUBLICO, EnPublico} from './videos/EnPublico';
import {Horizontal} from './Horizontal';
import {Banner, Perfil} from './Estaticos';

const vertical = {width: 1080, height: 1920, fps: 30};
const horizontal = {width: 1920, height: 1080, fps: 30};

export const Root: React.FC = () => (
  <>
    <Composition id="01-ApplePay" component={ApplePay} durationInFrames={DURACION_APPLEPAY} {...vertical} />
    <Composition id="02-TuAno" component={TuAno} durationInFrames={DURACION_TUANO} {...vertical} />
    <Composition id="03-Mapa" component={Mapa} durationInFrames={DURACION_MAPA} {...vertical} />
    <Composition id="04-POV" component={POV} durationInFrames={DURACION_POV} {...vertical} />
    <Composition id="05-EnPublico" component={EnPublico} durationInFrames={DURACION_EN_PUBLICO} {...vertical} />

    <Composition
      id="X-ApplePay"
      durationInFrames={DURACION_APPLEPAY}
      {...horizontal}
      component={() => (
        <Horizontal titular="Pagas la cena. Rico te pregunta qué tal." subtitulo="Valoras en 10 segundos y queda en tu diario.">
          <ApplePay />
        </Horizontal>
      )}
    />
    <Composition
      id="X-TuAno"
      durationInFrames={DURACION_TUANO}
      {...horizontal}
      component={() => (
        <Horizontal titular="Tu año comiendo fuera, en cifras." subtitulo="Restaurantes, gasto y lo que más repetiste.">
          <TuAno />
        </Horizontal>
      )}
    />

    <Still id="Perfil" component={Perfil} width={1000} height={1000} />
    <Still id="BannerX" component={Banner} width={1500} height={500} />
  </>
);
