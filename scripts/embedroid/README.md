# EmbeDroid mantenido por AI-APPS

Distribución `magullodev.ai-apps-embedroid` 1.1.0, basada en
`utpalbarman.embedroid` 1.0.2. Conserva sus comandos, ajustes, interfaz y
servidor scrcpy 3.2. Corrige los dos generadores de `scid`
del transporte: `scid.cjs` elimina el bit de signo y mantiene ocho dígitos
hexadecimales. Tanto `adb forward` como `scrcpy.Server` reciben el mismo valor.
`sessions.cjs` amplía el manager original con identidad por app/dispositivo,
deduplicación concurrente, cierre y reconexión independientes y serialización
de webviews. Reutiliza su HTML y transporte. Las vistas nuevas se abren en
grupos contiguos; las existentes conservan su posición. No añade reintentos
al transporte. Consulta [la operación multiemulador](../android/README.md).

## Procedencia y mantenimiento

`upstream/` conserva los archivos del paquete 1.0.2 instalado el 9 de octubre
de 2026, sin modificar. `upstream-sha256.json` fija sus SHA-256. El código
JavaScript original está empaquetado y minificado; no se presenta como el
TypeScript de origen. La licencia MIT de EmbeDroid y los avisos del bundle
se conservan. El servidor conserva su licencia Apache 2.0 en
`media/vendor/LICENSE-scrcpy.txt`, añadida desde el repositorio oficial de
scrcpy 3.2. `.gitattributes` impide alterar los bytes upstream al clonar.

El repositorio indicado por el paquete,
<https://github.com/utpal-barman/embedroid-vscode-plugin>, devolvió 404 en la
consulta del 10 de octubre de 2026. No se ha enviado una incidencia ni un PR
al autor. Esta distribución es el mecanismo de mantenimiento disponible.

`build.ps1` verifica los hashes y exige encontrar exactamente los dos
generadores conocidos antes de sustituirlos por `generateScid()`. Verifica
también cada punto de integración del manager, API de sesiones y webview antes
de aplicar cambios. El webview conserva únicamente la identidad con `setState`,
renueva socket/decodificador al reconectar y reporta frames renderizados para
verificar el vídeo. El token de transporte no se persiste. Produce
una extensión y un VSIX en `.ai-apps/embedroid/`. No necesita npm ni modifica
la extensión instalada. El empaquetado usa las bibliotecas .NET de Windows.

```powershell
.\scripts\embedroid\build.ps1
.\scripts\embedroid\test.ps1
.\scripts\install-embedroid.ps1
```

El instalador comprueba primero el paquete, instala el VSIX con identidad
propia y desinstala la distribución original para evitar comandos duplicados.
Después actualiza el enlace de AI-APPS Android. Recarga VS Code para cargar
la nueva extensión; el emulador y Flutter continúan fuera del editor.
Si se reinstala EmbeDroid desde Marketplace, vuelve a ejecutar el instalador.

La identidad propia evita que una actualización de `utpalbarman.embedroid`
sobrescriba la corrección. El código, el paquete original, los hashes y las
pruebas están versionados en `origin/dev`: se reconstruye e instala en otro
equipo sin depender de archivos editados dentro de `.vscode/extensions`.
Las actualizaciones de esta distribución se construyen e instalan desde
el repositorio; no se publica automáticamente en Marketplace.

Para incorporar otra versión upstream, importar deliberadamente sus archivos,
actualizar los hashes, revisar el transporte y ajustar la sustitución y las
pruebas. Incrementar la versión del manifiesto y del VSIX juntos. Si upstream
corrige `scid`, validar la versión y migrar explícitamente la dependencia de
AI-APPS Android; no seguir aplicando la sustitución a un bundle desconocido.

## Verificación

`test.ps1` usa Node instalado o el runtime Node de VS Code. Comprueba los
límites de entropía, los ocho dígitos y 100.000 valores aleatorios. Ejecuta
además la clase `ScrcpyStream` del bundle construido con ADB simulado para
verificar que constructor y arranque usan el generador corregido y que el
socket y el argumento `scid` coinciden.

```powershell
.\scripts\embedroid\test.ps1 -Device emulator-5554
```

La prueba con dispositivo usa la clase real del transporte y el servidor
incluido. Fuerza entropía `80000000` y `ffffffff`, abre transmisiones separadas,
exige recibir frames H.264 durante diez segundos en cada ciclo y las cierra
liberando solo sus sockets, forwards y servidores. No inicia Flutter, no
reinicia Android y no modifica QuizAI. Usa `power_on=false` en una prueba
negativa aislada para no despertar un dispositivo apagado.

`host-test.ps1` ejecuta dos procesos independientes de VS Code sobre el mismo
perfil aislado. En cada reapertura abre y cierra dos webviews reales, exige
conexión al primer intento y mantiene el vídeo diez segundos sin errores.
Los resultados y registros quedan en `.ai-apps/embedroid/`. No cierra ni
recarga el editor principal. Ejecutarlo solo con `emulator-5554` disponible:

```powershell
.\scripts\embedroid\host-test.ps1
```
