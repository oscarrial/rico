-- El servidor fija actualizado_en al crear y al editar, y creado_en no cambia al editar.
-- La sincronización pide «lo cambiado desde X»: no puede depender del reloj del móvil.

create or replace function public.tocar_actualizado_en()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.actualizado_en = now();
  if tg_op = 'UPDATE' then
    new.creado_en = old.creado_en;
  end if;
  return new;
end;
$$;

do $$
declare
  tabla text;
begin
  foreach tabla in array array[
    'restaurantes', 'pagos_capturados', 'visitas', 'platos', 'fotos',
    'listas', 'lista_restaurantes', 'alias_comercio'
  ] loop
    execute format('drop trigger if exists tocar_actualizado_en on public.%I', tabla);
    execute format(
      'create trigger tocar_actualizado_en before insert or update on public.%I '
      'for each row execute function public.tocar_actualizado_en()',
      tabla
    );
  end loop;
end;
$$;
