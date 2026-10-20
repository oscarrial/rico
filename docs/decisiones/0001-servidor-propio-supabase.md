# 0001 · Servidor propio con Supabase en lugar de CloudKit

- **Estado:** aceptada (20 de octubre de 2026)
- **Sustituye a:** «local-first con CloudKit, sin servidor de datos» del plan de producto.

## Contexto

El plan proponía guardar los datos solo en el iPhone y sincronizarlos con el iCloud privado de cada usuario (CloudKit). Era gratis, sin mantenimiento y muy privado, pero:

- deja fuera Android (prevista en v3) y cualquier acceso web;
- complica las funciones sociales (listas colaborativas, recomendaciones entre amigos);
- no permite ver datos agregados para entender el producto.

## Decisión

1. **Supabase** (PostgreSQL, Auth y Storage) en una **región de la UE** (Fráncfort).
2. **Cuentas:** «Iniciar sesión con Apple» y **correo con código de 6 dígitos** (sin contraseñas ni enlaces mágicos). Apple obliga a ofrecer su inicio de sesión si hay otros de terceros, y a permitir **borrar la cuenta** desde la app.
3. **La app sigue siendo local primero:** SwiftData guarda todo en el iPhone y una capa de sincronización sube y baja cambios. La captura al pagar funciona sin conexión.
4. **Seguridad por fila (RLS):** cada tabla tiene `usuario_id` y una política «solo el dueño». Las claves externas incluyen `usuario_id` para que nadie pueda enlazar filas de otro usuario.
5. **Fotos** en un bucket privado `fotos`, en la carpeta `{usuario_id}/`.
6. **Borrado suave** (`borrado_en`) para que la sincronización propague los borrados; `actualizado_en` lo mantiene un disparador.

## Consecuencias

- Aparece una pantalla de acceso antes de la primera visita. Hay que medir su efecto en la activación (objetivo: 40 %).
- El responsable de ubicaciones, pagos y fotos pasa a ser Rico. Pendientes legales: registro de actividades de tratamiento, contrato de encargo con Supabase y política de privacidad que lo explique.
- Coste: plan gratuito al principio; las fotos son lo que más crecerá (Storage).
- Si Supabase no está configurado (`Config/Secretos.xcconfig` vacío), la app funciona solo en local, sin cuenta. Así compila la CI y se puede desarrollar sin servidor.

## Cómo aplicarlo

1. Crear un proyecto en [supabase.com](https://supabase.com) en la región **Central EU (Frankfurt)**.
2. Ejecutar `supabase/migrations/*.sql` en orden (SQL Editor o `supabase db push`).
3. **Auth → Providers:**
   - **Email:** activado. En la plantilla «Magic Link», el correo debe incluir `{{ .Token }}` para enviar el código de 6 dígitos.
   - **Apple:** activado, con el Bundle ID de la app (`es.siweb.rico`) en «Client IDs».
4. Copiar `Config/Secretos.example.xcconfig` a `Config/Secretos.xcconfig` con el host del proyecto y la clave pública (`anon`). Para la CI, guardar los mismos valores como secretos `RICO_SUPABASE_HOST` y `RICO_SUPABASE_CLAVE` del repositorio.
