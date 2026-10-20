-- Comprobación de la migración 20261021090000_actualizado_en_al_crear.
-- Todo ocurre dentro de una transacción que se deshace al final: no deja datos.
-- Si alguna comprobación falla, el script se detiene con un error; los select
-- devuelven true en cada comprobación correcta.

begin;

insert into auth.users (id, email, aud, role)
values ('00000000-0000-0000-0000-0000000000a1', 'prueba-actualizado-en@example.com', 'authenticated', 'authenticated');

-- 1. Al crear, el servidor ignora el actualizado_en enviado por el cliente.
insert into public.restaurantes (id, usuario_id, nombre, actualizado_en)
values ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-0000000000a1', 'Restaurante de prueba', '2000-01-01');

do $$
begin
  assert (select actualizado_en = now() from public.restaurantes
          where id = '00000000-0000-0000-0000-0000000000b1'),
    'Al crear, actualizado_en debería ser now()';
end;
$$;

select (actualizado_en = now()) as ok_actualizado_en_al_crear
from public.restaurantes where id = '00000000-0000-0000-0000-0000000000b1';

-- 2. Al editar, creado_en no cambia aunque el cliente lo intente.
update public.restaurantes
set creado_en = '2000-01-01', nombre = 'Restaurante editado'
where id = '00000000-0000-0000-0000-0000000000b1';

do $$
begin
  assert (select creado_en = now() from public.restaurantes
          where id = '00000000-0000-0000-0000-0000000000b1'),
    'Al editar, creado_en no debería cambiar';
end;
$$;

select (creado_en <> '2000-01-01'::timestamptz) as ok_creado_en_no_cambia
from public.restaurantes where id = '00000000-0000-0000-0000-0000000000b1';

rollback;
