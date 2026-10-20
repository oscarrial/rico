# Plan 005: El servidor fija `actualizado_en` también al crear filas

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 685cbe0..HEAD -- supabase/ docs/decisiones/0001-servidor-propio-supabase.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `685cbe0`, 2026-10-20

## Why this matters

La sincronización prevista pedirá al servidor «lo que ha cambiado desde X» usando la columna `actualizado_en` (hay índices `(usuario_id, actualizado_en)` en todas las tablas). Hoy el disparador que la fija solo actúa en `UPDATE`: en un `INSERT` el cliente puede enviar cualquier valor (por ejemplo una fecha pasada de un móvil con la hora mal), y esa fila nunca llegará a los demás dispositivos. Además, la decisión documentada dice que «`actualizado_en` lo fija siempre el servidor», lo que hoy no es cierto.

## Current state

- `supabase/migrations/20261020130000_esquema_inicial.sql` — **ya aplicada** en producción. La regla del repo (`CLAUDE.md`) es: «Los cambios de esquema van en una migración nueva, nunca editando una ya aplicada.»
- Función (líneas 11-20):

```sql
11	create or replace function public.tocar_actualizado_en()
12	returns trigger
13	language plpgsql
14	set search_path = ''
15	as $$
16	begin
17	  new.actualizado_en = now();
18	  return new;
19	end;
20	$$;
```

- Disparadores (líneas 184-205), creados en un bucle sobre las 8 tablas `restaurantes, pagos_capturados, visitas, platos, fotos, listas, lista_restaurantes, alias_comercio`:

```sql
198	    execute format(
199	      'create trigger tocar_actualizado_en before update on public.%I '
200	      'for each row execute function public.tocar_actualizado_en()',
201	      tabla
202	    );
```

- `docs/decisiones/0001-servidor-propio-supabase.md`: punto 6 de «Decisión» («`actualizado_en` lo mantiene un disparador») y, en «Estado», la línea «las notas solo admiten medias estrellas y `actualizado_en` lo fija siempre el servidor;».
- La base de datos es PostgreSQL 17 en Supabase. Las migraciones se registran en `supabase_migrations.schema_migrations (version, name)`.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Comprobar que no hay otro archivo con la misma versión | `ls supabase/migrations/` | solo `20261020130000_esquema_inicial.sql` antes de empezar |
| Aplicar (lo hace el **operador**) | SQL Editor del panel de Supabase, o CLI `supabase db push` | sin errores |

El ejecutor **no** tiene credenciales de la base de datos y no debe pedirlas. Escribe la migración y el script de comprobación; la aplicación la hace el operador.

## Scope

**In scope**:
- `supabase/migrations/20261021090000_actualizado_en_al_crear.sql` (crear)
- `supabase/verificaciones/actualizado_en.sql` (crear)
- `docs/decisiones/0001-servidor-propio-supabase.md` (solo el apartado «Estado»)

**Out of scope**:
- `supabase/migrations/20261020130000_esquema_inicial.sql` — no se edita nunca.
- `creado_en` en inserciones: el cliente puede enviar la hora real de creación (visitas creadas sin conexión). Solo se protege en actualizaciones.

## Git workflow

- Rama: `advisor/005-tiempos-del-servidor`. Commits en castellano, estilo del repo.

## Steps

### Step 1: Escribir la migración

Crea `supabase/migrations/20261021090000_actualizado_en_al_crear.sql` con comentarios en castellano como el archivo inicial:

```sql
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
```

**Verify**: `grep -c "before insert or update" supabase/migrations/20261021090000_actualizado_en_al_crear.sql` → `1`.

### Step 2: Script de comprobación para el operador

Crea `supabase/verificaciones/actualizado_en.sql`. Debe hacerlo todo dentro de `begin; … rollback;` para no dejar datos:

1. Insertar un usuario de prueba en `auth.users` (`id`, `email`, `aud='authenticated'`, `role='authenticated'`).
2. Insertar un restaurante para ese usuario con `actualizado_en = '2000-01-01'` y comprobar con `select` que `actualizado_en = now()`.
3. Hacer `update` con `creado_en = '2000-01-01'` y comprobar que `creado_en` no cambió.
4. Terminar con `rollback;`.

Usa `do $$ … assert …; $$` o `select ... as ok` que devuelva `true` en cada comprobación.

**Verify**: `grep -c "rollback;" supabase/verificaciones/actualizado_en.sql` → `1`.

### Step 3: Corregir la documentación

En `docs/decisiones/0001-servidor-propio-supabase.md`, apartado «Estado», añade una línea: «- **21 de octubre de 2026:** migración `20261021090000_actualizado_en_al_crear`: `actualizado_en` lo fija el servidor también al crear filas, y `creado_en` no se puede cambiar al editar.» No borres las líneas existentes.

**Verify**: `grep -c "20261021090000" docs/decisiones/0001-servidor-propio-supabase.md` → `1`.

### Step 4: Entregar al operador

Commit y empuja la rama. En tu informe final, indica al operador:
1. Ejecutar `supabase/migrations/20261021090000_actualizado_en_al_crear.sql` en el SQL Editor (o `supabase db push`).
2. Registrar la versión si lo hace a mano: `insert into supabase_migrations.schema_migrations (version, name) values ('20261021090000', 'actualizado_en_al_crear');`
3. Ejecutar `supabase/verificaciones/actualizado_en.sql` y confirmar que todas las comprobaciones devuelven verdadero.

**Verify**: `git log --oneline -1` muestra tu commit; el informe incluye los tres pasos.

## Test plan

No hay pruebas automáticas de la base de datos en el repo. La prueba es el script del paso 2, que ejecuta el operador.

## Done criteria

- [ ] Existen la migración nueva y el script de comprobación, y la migración inicial no ha cambiado (`git diff 685cbe0 -- supabase/migrations/20261020130000_esquema_inicial.sql` vacío).
- [ ] El ADR menciona la migración nueva.
- [ ] El informe final pide al operador aplicar y comprobar.
- [ ] Fila en `plans/README.md` en `IN PROGRESS (pendiente de aplicar)` hasta que el operador confirme; entonces `DONE`.

## STOP conditions

- Ya existe en `supabase/migrations/` otra migración posterior a `20261020130000` que toca `tocar_actualizado_en`.
- Alguien te pide aplicar la migración tú mismo con una contraseña: no lo hagas; deja la aplicación al operador.

## Maintenance notes

- Toda tabla nueva debe crear el disparador como `before insert or update` (actualiza la regla de `CLAUDE.md` si alguien la toca).
- La sincronización no debe enviar `actualizado_en`: el servidor lo ignora.
