-- Un alias borrado (borrado lógico: la fila sigue con borrado_en) no debe impedir
-- aprender otro con el mismo comercio. Al corregir un alias, la app borra el viejo
-- y crea uno nuevo con otro id: con la restricción completa el nuevo no subía nunca.

alter table public.alias_comercio
  drop constraint if exists alias_comercio_usuario_id_comercio_limpio_key;

create unique index if not exists alias_comercio_vivo_unico
  on public.alias_comercio (usuario_id, comercio_limpio)
  where borrado_en is null;
