# 0002 · Extraer los textos sin Xcode en local

- **Estado:** aceptada (20 de octubre de 2026)
- **Conclusión:** B (la vía es `-exportLocalizations` en la CI), con un hallazgo añadido que se explica abajo.

## Contexto

Todos los textos visibles usan `Text("…", bundle: .module)` o `String(localized:bundle:)`, pero los tres catálogos (`Packages/RicoKit/Sources/{Cuenta,DesignSystem,Visitas}/Resources/Localizable.xcstrings`) están vacíos: normalmente los rellena Xcode al compilar en un Mac, y aquí no hay Xcode en local. Además la app declaraba `CFBundleLocalizations: [es, en]`, de modo que la App Store la listaría en inglés aunque todo saliera en castellano.

## Qué se hizo

1. `project.yml`: `CFBundleLocalizations` pasa a `[es]`. Se vuelve a añadir `en` cuando haya traducción.
2. Paso temporal en la CI (Xcode 26.3, `macos-15`) después de `xcodebuild test`: `git status` sobre los `.xcstrings`, `xcodebuild -exportLocalizations -exportLanguage es`, recuento de `<trans-unit` y subida de todo como artefacto (ejecución 39442762573, en verde).

## Resultado

- `xcodebuild test` **no modifica** los catálogos: `git status --porcelain -- '*.xcstrings'` salió vacío. Por eso no es la conclusión A.
- `xcodebuild -exportLocalizations` **funciona sin firma ni dispositivo** (ni la investigación ni el trabajo manual necesitaron un dispositivo). Compila el proyecto, extrae las cadenas y genera `es.xcloc` con un `es.xliff` de **114 unidades**: 3 de `App/InfoPlist.xcstrings`, 3 de DesignSystem, 62 de Visitas y 46 de Cuenta.
- Efecto secundario: esa misma orden **rellena con las claves** los `Localizable.xcstrings` del árbol de trabajo (las copias subidas pesan unos 2,4 KB y 2,6 KB frente a los 73 bytes versionados), pero con los valores vacíos (`"clave" : { }`, sin `extractionState`). Los catálogos versionados siguen vacíos a propósito: sin traducciones no aportan nada, y las claves se vuelven a generar cuando haga falta.
- Ya existe `App/InfoPlist.xcstrings` con `CFBundleDisplayName`, `CFBundleName` y `NSPhotoLibraryUsageDescription` (solo en castellano).

## Cómo extraer los textos a partir de ahora

```
gh workflow run ci.yml --ref <rama> -f extraer_textos=true
gh run list --workflow ci.yml --branch <rama> --limit 1 --json databaseId --jq '.[0].databaseId'
gh run watch <id> --exit-status
gh run download <id> -n localizacion -D <carpeta>
```

El artefacto `localizacion` contiene `localizacion/es.xcloc` (con `Localized Contents/es.xliff`), `catalogos/` (los `.xcstrings` tal como quedan tras la exportación) y el registro de la orden. El trabajo `textos` del flujo `ci.yml` solo se ejecuta con ese input.

## Cómo añadir inglés (pendiente, no forma parte de este cambio)

1. Descargar el artefacto y traducir el `.xliff` (o copiar los `.xcstrings` con claves y rellenar las traducciones).
2. Versionar los catálogos traducidos; si se prefiere el `.xliff`, importarlo en la CI con `xcodebuild -importLocalizations -localizationPath <xcloc>` antes de compilar.
3. Volver a poner `en` en `CFBundleLocalizations` y traducir también el texto de permiso de fotos en `App/InfoPlist.xcstrings`.
