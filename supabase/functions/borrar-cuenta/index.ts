// Borra la cuenta de quien llama: fotos, usuario (y, por cascada, todas sus filas)
// y, si se puede, revoca el acceso de «Iniciar sesión con Apple».
//
// Variables que inyecta Supabase: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY.
// Variables opcionales (secretos del operador): APPLE_TEAM_ID, APPLE_KEY_ID,
// APPLE_CLIENT_ID y APPLE_PRIVATE_KEY (contenido de la clave .p8).

import { createClient } from "npm:@supabase/supabase-js@2";
import { importPKCS8, SignJWT } from "npm:jose@5";

const BUCKET = "fotos";
const MAX_VUELTAS = 50;
const TAMANO_PAGINA = 1000;

function responder(estado: number, cuerpo: Record<string, unknown>): Response {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { "Content-Type": "application/json" },
  });
}

/** Borra todo lo de `fotos/{uid}/`. Devuelve false si no se pudo vaciar. */
async function borrarFotos(
  // deno-lint-ignore no-explicit-any
  admin: any,
  uid: string,
): Promise<boolean> {
  for (let vuelta = 0; vuelta < MAX_VUELTAS; vuelta++) {
    const { data, error } = await admin.storage
      .from(BUCKET)
      .list(uid, { limit: TAMANO_PAGINA, offset: 0 });
    if (error) {
      console.error("borrar-cuenta: no se pudo listar la carpeta de fotos");
      return false;
    }
    if (!data || data.length === 0) return true;

    const rutas = data.map((archivo: { name: string }) => `${uid}/${archivo.name}`);
    const { data: borrados, error: errorBorrado } = await admin.storage
      .from(BUCKET)
      .remove(rutas);
    if (errorBorrado) {
      console.error("borrar-cuenta: no se pudieron borrar fotos");
      return false;
    }
    // Una vuelta que no borra nada no avanzará nunca: se sale.
    if (!borrados || borrados.length === 0) return false;
  }
  console.error("borrar-cuenta: demasiadas vueltas borrando fotos");
  return false;
}

/** Intercambia el código de Apple y revoca el refresh_token. Nunca lanza. */
async function revocarApple(codigo: string): Promise<boolean> {
  const equipo = Deno.env.get("APPLE_TEAM_ID");
  const clave = Deno.env.get("APPLE_KEY_ID");
  const cliente = Deno.env.get("APPLE_CLIENT_ID");
  const privada = Deno.env.get("APPLE_PRIVATE_KEY");
  if (!equipo || !clave || !cliente || !privada) return false;

  try {
    const ahora = Math.floor(Date.now() / 1000);
    const secreto = await new SignJWT({})
      .setProtectedHeader({ alg: "ES256", kid: clave })
      .setIssuer(equipo)
      .setSubject(cliente)
      .setAudience("https://appleid.apple.com")
      .setIssuedAt(ahora)
      .setExpirationTime(ahora + 300)
      .sign(await importPKCS8(privada.replace(/\\n/g, "\n"), "ES256"));

    const intercambio = await fetch("https://appleid.apple.com/auth/token", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: cliente,
        client_secret: secreto,
        code: codigo,
        grant_type: "authorization_code",
      }),
    });
    if (!intercambio.ok) {
      console.error(`borrar-cuenta: Apple rechazó el código (${intercambio.status})`);
      return false;
    }
    const { refresh_token: refresco } = await intercambio.json();
    if (typeof refresco !== "string" || refresco === "") {
      console.error("borrar-cuenta: Apple no devolvió refresh_token");
      return false;
    }

    const revocacion = await fetch("https://appleid.apple.com/auth/revoke", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        client_id: cliente,
        client_secret: secreto,
        token: refresco,
        token_type_hint: "refresh_token",
      }),
    });
    if (!revocacion.ok) {
      console.error(`borrar-cuenta: Apple no revocó el token (${revocacion.status})`);
      return false;
    }
    return true;
  } catch (_error) {
    console.error("borrar-cuenta: fallo al revocar el acceso de Apple");
    return false;
  }
}

Deno.serve(async (peticion: Request) => {
  if (peticion.method !== "POST") {
    return responder(405, { error: "metodo_no_permitido" });
  }

  const cabecera = peticion.headers.get("Authorization") ?? "";
  const jwt = cabecera.startsWith("Bearer ") ? cabecera.slice(7).trim() : "";
  if (jwt === "") return responder(401, { error: "sin_autorizacion" });

  const url = Deno.env.get("SUPABASE_URL");
  const anon = Deno.env.get("SUPABASE_ANON_KEY");
  const servicio = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !anon || !servicio) {
    console.error("borrar-cuenta: faltan variables de Supabase");
    return responder(500, { error: "configuracion" });
  }

  const comoUsuario = createClient(url, anon);
  const { data: datosUsuario, error: errorUsuario } = await comoUsuario.auth.getUser(jwt);
  const uid = datosUsuario?.user?.id;
  if (errorUsuario || !uid) return responder(401, { error: "sin_autorizacion" });

  let codigoApple: string | undefined;
  try {
    const cuerpo = await peticion.json();
    if (typeof cuerpo?.apple_codigo === "string" && cuerpo.apple_codigo !== "") {
      codigoApple = cuerpo.apple_codigo;
    }
  } catch (_error) {
    // Sin cuerpo (o no es JSON): se borra igual, sin revocar Apple.
  }

  const admin = createClient(url, servicio, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  if (!(await borrarFotos(admin, uid))) {
    return responder(500, { error: "fotos_no_borradas" });
  }

  // Antes de borrar el usuario: no hace falta que exista para revocar, pero así
  // un fallo aquí nunca deja la cuenta a medias.
  const appleRevocado = codigoApple ? await revocarApple(codigoApple) : false;

  const { error: errorBorrado } = await admin.auth.admin.deleteUser(uid);
  if (errorBorrado) {
    console.error("borrar-cuenta: no se pudo borrar el usuario");
    return responder(500, { error: "usuario_no_borrado" });
  }

  return responder(200, { ok: true, apple_revocado: appleRevocado });
});
