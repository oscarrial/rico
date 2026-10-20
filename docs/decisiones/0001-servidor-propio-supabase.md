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
2. **Cuentas:** «Iniciar sesión con Apple» y **correo con contraseña** (mínimo 8 caracteres, con al menos una letra y un número). Al crear la cuenta se confirma el correo con un enlace, y «¿Has olvidado tu contraseña?» envía otro enlace. Ambos vuelven a la app por `rico://auth/confirmar` y `rico://auth/recuperar`. Apple obliga a ofrecer su inicio de sesión si hay otros de terceros, y a permitir **borrar la cuenta** desde la app.
3. **La app sigue siendo local primero:** SwiftData guarda todo en el iPhone y una capa de sincronización sube y baja cambios. La captura al pagar funciona sin conexión.
4. **Seguridad por fila (RLS):** cada tabla tiene `usuario_id` y una política «solo el dueño». Las claves externas incluyen `usuario_id` para que nadie pueda enlazar filas de otro usuario.
5. **Fotos** en un bucket privado `fotos`, en la carpeta `{usuario_id}/`.
6. **Borrado suave** (`borrado_en`) para que la sincronización propague los borrados; `actualizado_en` lo mantiene un disparador.

## Consecuencias

- Aparece una pantalla de acceso antes de la primera visita. Hay que medir su efecto en la activación (objetivo: 40 %).
- El responsable de ubicaciones, pagos y fotos pasa a ser Rico. Pendientes legales: registro de actividades de tratamiento, contrato de encargo con Supabase y política de privacidad que lo explique.
- Coste: plan gratuito al principio; las fotos son lo que más crecerá (Storage).
- Si Supabase no está configurado (`Config/Secretos.xcconfig` vacío), la app funciona solo en local, sin cuenta. Así compila la CI y se puede desarrollar sin servidor.

## Estado

- **20 de octubre de 2026:** proyecto creado en Fráncfort (PostgreSQL 17) y migración `20261020130000_esquema_inicial` aplicada y registrada en `supabase_migrations.schema_migrations`.
- **Seguridad comprobada con dos usuarios simulados** (en una transacción deshecha al terminar):
  - cada usuario solo ve y edita lo suyo, y sin sesión no se ve nada;
  - nadie puede crear filas a nombre de otro ni enlazarlas con filas ajenas;
  - las notas solo admiten medias estrellas y `actualizado_en` lo fija siempre el servidor;
  - `borrar_mi_cuenta()` borra el usuario y sus datos en cascada sin tocar a otros.
- **21 de octubre de 2026:** migración `20261021090000_actualizado_en_al_crear`: `actualizado_en` lo fija el servidor también al crear filas, y `creado_en` no se puede cambiar al editar.
- **Conexión desde redes sin IPv6:** la conexión directa (`db.<ref>.supabase.co`) solo funciona por IPv6. Hay que usar el *session pooler*: `aws-1-eu-central-1.pooler.supabase.com:5432`, usuario `postgres.<ref>`.

## Cómo aplicarlo

1. Crear un proyecto en [supabase.com](https://supabase.com) en la región **Central EU (Frankfurt)**.
2. Ejecutar `supabase/migrations/*.sql` en orden (SQL Editor o `supabase db push`).
3. **Authentication** en el panel de Supabase:
   - **Sign In / Providers → Email:** activado, con «Confirm email» activado.
   - **Policies / Passwords:** longitud mínima 8 y «Letters and digits». Es el servidor quien hace cumplir las reglas; la app solo las enseña.
   - **URL Configuration → Redirect URLs:** añadir `rico://auth/**`.
   - **Emails:** traducir al castellano las plantillas «Confirm signup» y «Reset password». Para producción, configurar un SMTP propio, porque el envío de Supabase tiene un límite muy bajo de correos por hora.
   - **Apple:** activado, con el Bundle ID de la app (`es.siweb.rico`) en «Client IDs». Requiere la cuenta de Apple Developer.
4. Copiar `Config/Secretos.example.xcconfig` a `Config/Secretos.xcconfig` con el host del proyecto y la clave pública (`anon`). Para la CI, guardar los mismos valores como secretos `RICO_SUPABASE_HOST` y `RICO_SUPABASE_CLAVE` del repositorio.
5. **Borrar la cuenta:** desplegar la Edge Function `supabase/functions/borrar-cuenta` con `npx supabase functions deploy borrar-cuenta --project-ref <ref-del-proyecto>`. Borra las fotos y el usuario (las filas caen en cascada) y revoca el acceso de Apple. Para la revocación, definir con `npx supabase secrets set` las variables `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_ID` (`es.siweb.rico`) y `APPLE_PRIVATE_KEY` (contenido de la clave `.p8` de *Sign in with Apple*). Sin ellas la función borra igual y responde `apple_revocado: false`.
