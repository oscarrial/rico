# 0004 · Sincronización local primero con Supabase

- **Estado:** aceptada (21 de octubre de 2026)
- **Depende de:** [0001 · Servidor propio con Supabase](0001-servidor-propio-supabase.md)

## Contexto

La app lee y escribe siempre en SwiftData (una base por cuenta, `Rico-<usuario>.store`). Con sesión iniciada, los datos tienen que llegar al servidor y bajar a otros iPhone de la misma cuenta sin bloquear nunca la interfaz y funcionando sin conexión. El esquema del servidor ya está preparado: todas las tablas tienen `usuario_id`, RLS «solo el dueño», `actualizado_en` que fija un disparador al crear y al editar, y `borrado_en` para el borrado lógico.

## Decisión

### 1. Qué ha cambiado en local: registro con huellas, no marcas en cada pantalla

Las pantallas cambian los modelos en muchos sitios (ficha rápida, listas, bandeja de pagos, Atajos…). Poner `pendienteSubir = true` en cada uno es frágil: basta un olvido para que un cambio no suba nunca, y los borrados en cascada de SwiftData no pasan por ningún código nuestro.

Por eso la sincronización compara el estado local con lo último que sabe del servidor:

- **`RegistroSincronizado`** (modelo nuevo de SwiftData, en la misma base): una fila por fila remota con `tabla`, `clave`, `huella` (SHA-256 del JSON que se subiría), `actualizadoEnServidor`, `cambiadoEnLocal` y `borradoEnLocal`.
- **Detección:** en cada vuelta se construye el DTO de cada fila local y se calcula su huella.
  - Sin registro o con huella distinta → cambio pendiente; `cambiadoEnLocal` guarda **cuándo se vio por primera vez** (hace de fecha de la edición local).
  - Registro sin fila local → **borrado pendiente** (`borradoEnLocal`). Así se detectan también los borrados en cascada.
  - Registro sin fila local que nunca se subió (`huella == nil`) → se olvida.
- **Coste:** recorrer toda la base en cada vuelta. Para un diario personal (cientos o pocos miles de filas) son milisegundos; si crece, se puede limitar a los identificadores de `ModelContext.didSave`.
- **Modelos:** solo se añaden a `Foto` `rutaRemota` y `rutaMiniaturaRemota` (opcionales) y dos modelos nuevos (`RegistroSincronizado`, `MarcaBajada`). Todo opcional o con valor por defecto: SwiftData migra solo.

### 2. Borrados

- **En el servidor:** borrado lógico (`borrado_en`), nunca `delete`. Al subir un borrado se hace `update … set borrado_en` por clave.
- **En local:** se borra la fila de verdad y el **registro** hace de lista de borrados pendientes (punto anterior). Se descarta poner una marca de borrado en los modelos porque obligaría a filtrar `borrado == false` en todas las consultas y `@Query` de la app.
- **Fotos borradas:** además se borran del bucket la imagen y la miniatura (sin bloquear si falla).
- **Al bajar** una fila con `borrado_en` se borra en local (con sus cascadas, que a su vez se suben como borrados en la vuelta siguiente: coherente con el servidor).

### 3. Vuelta de sincronización

1. **Detectar** cambios locales (punto 1).
2. **Bajar** por tabla, en el orden de las claves externas, las filas con `actualizado_en` posterior a la **marca de la última bajada** de esa tabla (`MarcaBajada`, guardada en la base de la cuenta, así que es por usuario y se borra con ella). Se pide desde la marca **menos 2 minutos** para no perder filas de transacciones que confirmaron tarde; lo repetido se reconoce y se salta. Páginas de 500 ordenadas por `actualizado_en`.
3. **Detectar** otra vez (recoge las cascadas de lo bajado).
4. **Subir** primero los borrados y después los cambios (upsert por lotes de 200). Los borrados van antes para liberar los valores únicos: al corregir un alias, la app borra el viejo y crea otro con el mismo `comercio_limpio`.

**Conflictos: gana la última escritura, por fila.** Al bajar una fila:

| Situación local | Qué se hace |
| --- | --- |
| `actualizado_en` igual o anterior al conocido | Nada (es el eco de una subida propia o se repite por el margen). |
| Sin cambios pendientes | Se aplica lo del servidor. |
| Cambio o borrado pendiente **anterior** a `actualizado_en` remoto | Gana el servidor: se aplica y se descarta lo local. |
| Cambio o borrado pendiente **posterior** | Gana lo local: se sube en el paso 4. |

La comparación mezcla el reloj del iPhone con el del servidor; un desfase de unos segundos solo importa si dos dispositivos editan la misma fila casi a la vez.

**Orden de subida** (respeta las claves externas del esquema):
`restaurantes → pagos_capturados → listas → visitas → platos → fotos → lista_restaurantes → alias_comercio`.
`pagos_capturados` va **antes** de `visitas` porque `visitas.pago_id` apunta a pagos (el pago no tiene clave externa a nada). Los borrados son `update` y no dependen del orden; se mandan en orden inverso.

Si un lote falla por algo que no es la red, se reintenta fila a fila y las que fallan se registran y se quedan pendientes (no paran al resto). Un error de red corta la vuelta y se reintenta en la siguiente.

### 4. Fotos

- Antes de subir la fila de `fotos` se suben al bucket privado `fotos` la imagen (`<usuario_id>/<foto_id>.jpg`) y la miniatura (`<usuario_id>/<foto_id>-mini.jpg`, la columna `ruta_miniatura` es obligatoria), con `upsert`. Las rutas quedan en `Foto.rutaRemota`/`rutaMiniaturaRemota`; si ya están, no se vuelve a subir.
- Si una foto no tiene imagen completa se sube la miniatura en las dos rutas.
- **Al bajar** se crea la `Foto` sin datos y con las rutas. Tras cada vuelta se bajan las **miniaturas** que faltan (hasta 40 por vuelta), que es lo que enseñan el diario y las fichas. La **imagen completa** se baja bajo demanda con `Sincronizador.bajarImagenCompleta(de:)`.

### 5. Cuándo se sincroniza

`Sincronizador` (`@MainActor`, `@Observable`) por cuenta:

- al abrir sesión (la primera vuelta de un iPhone nuevo, sin marcas, **baja todo** lo no borrado);
- al volver a primer plano;
- tras cada guardado de SwiftData (`ModelContext.didSave`), con **antirrebote** de 3 s. Sus propios guardados no cuentan.

En `.soloLocal` (sin claves de Supabase) o sin sesión no existe. Al cambiar de usuario o cerrar sesión se para (cancela la vuelta en curso). Los errores se registran con `Registro.sincronizacion`, nunca con alertas.

### 6. Interfaz

Una línea discreta en «Tu cuenta»: «Guardado en tu cuenta · hace 2 min» o «Pendiente de guardar». Sin la palabra «sincronizar» (DESIGN.md §9).

### 7. Servidor detrás de un protocolo

`ServicioSincronizacion` (subir filas, marcar borradas, bajar cambios, subir/bajar/borrar imágenes). `ServicioSincronizacionSupabase` lo implementa con supabase-swift usando el mismo `SupabaseClient` que la cuenta. Las pruebas usan un servidor falso en memoria. Los DTO (`RestauranteRemoto`, `VisitaRemota`…) tienen las columnas en *snake_case* como las migraciones y codifican los opcionales vacíos como `null` (si no, un upsert no borraría un campo vaciado en el iPhone). `actualizado_en` nunca se envía: lo pone el disparador.

## Huecos conocidos

- **Datos del modo solo local (`Rico.store`):** no se mezclan con la cuenta al iniciar sesión. Quedan en el iPhone, en su archivo, sin subir. Hace falta decidir si se ofrece «Pasar a tu cuenta lo que tenías en este iPhone».
- **Duplicados entre dispositivos:** el mismo restaurante creado en dos iPhone sin conexión queda como dos restaurantes. Con `alias_comercio`, si dos iPhone aprenden sin conexión el mismo comercio, el índice único rechaza el segundo alias (se registra y queda pendiente). «Quiero probar» sí se fusiona: si hay varias, se queda la de id menor y recibe los restaurantes de las demás.
- **Imagen completa bajo demanda:** la API existe, pero ninguna pantalla enseña aún la foto a tamaño completo, así que nadie la llama.
- **Fotos del bucket sin fila:** si se sube la imagen y falla la fila, la imagen queda en el bucket hasta que la fila suba en otra vuelta.
- **Tiempo real:** no se escucha Supabase Realtime; los cambios de otro iPhone llegan al volver a primer plano o tras el siguiente guardado.

## Migraciones

`20261021120000_alias_unico_sin_borrados`: la restricción `unique (usuario_id, comercio_limpio)` de `alias_comercio` contaba también los alias borrados (que con el borrado lógico siguen en la tabla), así que corregir un alias fallaba para siempre. Pasa a ser un índice único parcial `where borrado_en is null`. **Hay que aplicarla** en el proyecto de Supabase antes de activar la sincronización.
