-- Rico · esquema inicial
-- Cada fila pertenece a un usuario (usuario_id) y solo él puede verla o cambiarla (RLS).
-- Los id los genera la app (UUID) para poder crear datos sin conexión.
-- Las claves externas incluyen usuario_id: nadie puede enlazar filas de otro usuario.
-- borrado_en marca borrados suaves para que la sincronización los propague.

-- ---------------------------------------------------------------------------
-- Utilidades
-- ---------------------------------------------------------------------------

create or replace function public.tocar_actualizado_en()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.actualizado_en = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tablas
-- ---------------------------------------------------------------------------

create table public.restaurantes (
  id              uuid primary key,
  usuario_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nombre          text not null check (length(nombre) between 1 and 200),
  direccion       text,
  ciudad          text,
  pais            text,
  latitud         double precision check (latitud between -90 and 90),
  longitud        double precision check (longitud between -180 and 180),
  map_item_id     text,
  cocina          text,
  rango_precio    smallint check (rango_precio between 1 and 4),
  telefono        text,
  web             text,
  silenciado      boolean not null default false,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),
  borrado_en      timestamptz,
  unique (id, usuario_id)
);

create table public.pagos_capturados (
  id                     uuid primary key,
  usuario_id             uuid not null default auth.uid() references auth.users (id) on delete cascade,
  comercio_bruto         text not null,
  comercio_limpio        text not null,
  importe_centimos       integer not null check (importe_centimos >= 0),
  divisa                 char(3) not null default 'EUR',
  tarjeta                text,
  fecha                  timestamptz not null,
  latitud                double precision,
  longitud               double precision,
  puntuacion_emparejado  numeric(4, 3),
  estado                 text not null default 'pendiente'
                         check (estado in ('asignado', 'propuesto', 'pendiente', 'descartado', 'duplicado', 'ignorado')),
  creado_en              timestamptz not null default now(),
  actualizado_en         timestamptz not null default now(),
  borrado_en             timestamptz,
  unique (id, usuario_id)
);

create table public.visitas (
  id                uuid primary key,
  usuario_id        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  restaurante_id    uuid,
  pago_id           uuid,
  fecha             timestamptz not null,
  estado            text not null default 'borrador' check (estado in ('borrador', 'valorada', 'descartada')),
  estrellas         numeric(2, 1) check (estrellas between 0.5 and 5 and (estrellas * 2) = floor(estrellas * 2)),
  resena            text check (length(resena) <= 5000),
  volveria          text check (volveria in ('si', 'quiza', 'no')),
  importe_centimos  integer check (importe_centimos >= 0),
  divisa            char(3) not null default 'EUR',
  comensales        smallint not null default 1 check (comensales between 1 and 100),
  pague_todo        boolean not null default true,
  ocasion           text,
  origen            text not null default 'manual' check (origen in ('pago', 'ubicacion', 'manual')),
  creada_por_ia     boolean not null default false,
  creado_en         timestamptz not null default now(),
  actualizado_en    timestamptz not null default now(),
  borrado_en        timestamptz,
  unique (id, usuario_id),
  foreign key (restaurante_id, usuario_id) references public.restaurantes (id, usuario_id) on delete cascade,
  foreign key (pago_id, usuario_id) references public.pagos_capturados (id, usuario_id) on delete set null (pago_id)
);

create table public.platos (
  id               uuid primary key,
  usuario_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  visita_id        uuid not null,
  nombre           text not null check (length(nombre) between 1 and 200),
  valoracion       text check (valoracion in ('encanto', 'bien', 'noRepetiria')),
  precio_centimos  integer check (precio_centimos >= 0),
  nota             text,
  orden            smallint not null default 0,
  creado_en        timestamptz not null default now(),
  actualizado_en   timestamptz not null default now(),
  borrado_en       timestamptz,
  unique (id, usuario_id),
  foreign key (visita_id, usuario_id) references public.visitas (id, usuario_id) on delete cascade
);

create table public.fotos (
  id                uuid primary key,
  usuario_id        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  visita_id         uuid not null,
  plato_id          uuid,
  -- Rutas dentro del bucket «fotos»: {usuario_id}/{id}.jpg y {usuario_id}/{id}-mini.jpg
  ruta              text not null,
  ruta_miniatura    text not null,
  fecha             timestamptz not null,
  es_comida         boolean not null default false,
  plato_sugerido    text,
  orden             smallint not null default 0,
  creado_en         timestamptz not null default now(),
  actualizado_en    timestamptz not null default now(),
  borrado_en        timestamptz,
  foreign key (visita_id, usuario_id) references public.visitas (id, usuario_id) on delete cascade,
  foreign key (plato_id, usuario_id) references public.platos (id, usuario_id) on delete set null (plato_id)
);

create table public.listas (
  id              uuid primary key,
  usuario_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nombre          text not null check (length(nombre) between 1 and 120),
  emoji           text,
  tipo            text not null default 'propia' check (tipo in ('quieroProbar', 'propia')),
  orden           smallint not null default 0,
  compartida      boolean not null default false,
  enlace_publico  text unique,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),
  borrado_en      timestamptz,
  unique (id, usuario_id)
);

create table public.lista_restaurantes (
  lista_id        uuid not null,
  restaurante_id  uuid not null,
  usuario_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),
  borrado_en      timestamptz,
  primary key (lista_id, restaurante_id),
  foreign key (lista_id, usuario_id) references public.listas (id, usuario_id) on delete cascade,
  foreign key (restaurante_id, usuario_id) references public.restaurantes (id, usuario_id) on delete cascade
);

create table public.alias_comercio (
  id                uuid primary key,
  usuario_id        uuid not null default auth.uid() references auth.users (id) on delete cascade,
  comercio_limpio   text not null,
  restaurante_id    uuid not null,
  veces_confirmado  integer not null default 1 check (veces_confirmado >= 1),
  creado_en         timestamptz not null default now(),
  actualizado_en    timestamptz not null default now(),
  borrado_en        timestamptz,
  unique (usuario_id, comercio_limpio),
  foreign key (restaurante_id, usuario_id) references public.restaurantes (id, usuario_id) on delete cascade
);

-- Índices para la sincronización («dame lo cambiado desde X») y las relaciones.
create index restaurantes_sync      on public.restaurantes (usuario_id, actualizado_en);
create index pagos_sync             on public.pagos_capturados (usuario_id, actualizado_en);
create index visitas_sync           on public.visitas (usuario_id, actualizado_en);
create index visitas_restaurante    on public.visitas (restaurante_id);
create index platos_sync            on public.platos (usuario_id, actualizado_en);
create index platos_visita          on public.platos (visita_id);
create index fotos_sync             on public.fotos (usuario_id, actualizado_en);
create index fotos_visita           on public.fotos (visita_id);
create index listas_sync            on public.listas (usuario_id, actualizado_en);
create index lista_restaurantes_sync on public.lista_restaurantes (usuario_id, actualizado_en);
create index alias_sync             on public.alias_comercio (usuario_id, actualizado_en);

-- ---------------------------------------------------------------------------
-- Seguridad por fila y disparadores
-- ---------------------------------------------------------------------------

do $$
declare
  tabla text;
begin
  foreach tabla in array array[
    'restaurantes', 'pagos_capturados', 'visitas', 'platos', 'fotos',
    'listas', 'lista_restaurantes', 'alias_comercio'
  ] loop
    execute format('alter table public.%I enable row level security', tabla);
    execute format(
      'create policy "solo el dueño" on public.%I for all to authenticated '
      'using (usuario_id = (select auth.uid())) with check (usuario_id = (select auth.uid()))',
      tabla
    );
    execute format(
      'create trigger tocar_actualizado_en before update on public.%I '
      'for each row execute function public.tocar_actualizado_en()',
      tabla
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fotos (Storage): bucket privado, cada usuario en su carpeta
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fotos', 'fotos', false, 10485760, array['image/jpeg'])
on conflict (id) do nothing;

create policy "fotos: ver las mías" on storage.objects
  for select to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "fotos: subir a mi carpeta" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'fotos' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "fotos: cambiar las mías" on storage.objects
  for update to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "fotos: borrar las mías" on storage.objects
  for delete to authenticated
  using (bucket_id = 'fotos' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ---------------------------------------------------------------------------
-- Borrar la cuenta (obligatorio en la App Store)
-- La app borra antes sus fotos con la API de Storage; esto borra el usuario
-- y, en cascada, todas sus filas.
-- ---------------------------------------------------------------------------

create or replace function public.borrar_mi_cuenta()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Hace falta una sesión para borrar la cuenta';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke execute on function public.borrar_mi_cuenta() from public, anon;
grant execute on function public.borrar_mi_cuenta() to authenticated;
