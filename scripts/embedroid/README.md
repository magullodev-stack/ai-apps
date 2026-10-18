# EmbeDroid mantenido por AI-APPS

Distribución `magullodev.ai-apps-embedroid` 1.1.2, basada en
`utpalbarman.embedroid` 1.0.2. Conserva el servidor scrcpy 3.2, su
transporte y sus cuatro intentos internos de conexión. Corrige el `scid`
mediante `scid.cjs` y conserva la identidad y deduplicación de las pestañas
de diferentes dispositivos en `sessions.cjs`.

**Muondia arranca una sola vez desde la tarea de Windows `AI-APPS Development`,
al iniciar sesión.** El visor de VS Code no inicia Android ni Flutter:
al restaurar una pestaña recupera su identidad, pero **no abre el
transporte de vídeo** hasta que AI-APPS Android informa que la tarea está
en ejecución y Muondia tiene proceso Android. Después abre un único
puente de vídeo para la pestaña existente. El visor no incorpora sondeos
ADB propios ni reintentos superpuestos a los de scrcpy. Un problema real
de scrcpy (por ejemplo, código 134) permanece visible y requiere sus
registros para identificar la causa. Consulta
[el responsable único del arranque](../android/README.md).
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
de aplicar cambios. El webview guarda con `setState` únicamente el serial del dispositivo: nunca persiste el nombre ni el
identificador de una aplicación. En cada apertura, el registro de AI-APPS aporta la identidad
vigente. Para `emulator-5554`, reservado a Muondia, el título se fija
inmediatamente como `Muondia · emulator-5554`, incluso si el transporte de
vídeo no consigue reconectarse. No se muestra un título intermedio `Android`.
Un panel cuyo
estado pertenece al formato anterior se descarta y
se crea una vista nueva desde ese registro. La conexión renueva
socket/decodificador al reconectar y reporta frames renderizados para
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

`test.ps1` usa Node instalado o el runtime Node de VS Code.
Comprueba que las pestañas restauradas esperan a que AI-APPS confirme
Muondia, que no arrancan un segundo puente y que abrir repetidamente la
misma sesión no crea duplicados. También comprueba los límites de entropía,
los ocho dígitos y 100.000 valores aleatorios. Ejecuta además
la clase `ScrcpyStream` del bundle construido con ADB simulado para
verificar que constructor y arranque usan el generador corregido y que el
socket y el argumento `scid` coinciden.

```powershell
.\scripts\embedroid\test.ps1 -Device emulator-5554
```

La prueba con dispositivo usa la clase real del transporte y el servidor
incluido. Fuerza entropía `80000000` y `ffffffff`, abre transmisiones separadas,
exige recibir frames H.264 durante diez segundos en cada ciclo y las cierra
liberando solo sus sockets, forwards y servidores. No inicia Flutter, no
reinicia Android y no modifica Muondia. Usa `power_on=false` en una prueba
negativa aislada para no despertar un dispositivo apagado.

`host-test.ps1` ejecuta dos procesos independientes de VS Code sobre el mismo
perfil aislado. En cada reapertura abre y cierra dos webviews reales, exige
conexión al primer intento y mantiene el vídeo diez segundos sin errores.
Los resultados y registros quedan en `.ai-apps/embedroid/`. No cierra ni
recarga el editor principal. Ejecutarlo solo con `emulator-5554` disponible:

```powershell
.\scripts\embedroid\host-test.ps1
```
