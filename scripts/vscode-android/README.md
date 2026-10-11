# Visualización de Android en VS Code

AI-APPS Android gestiona un visor por aplicación y dispositivo mediante
EmbeDroid mantenido 1.1.0. Incluye selección múltiple; la vista de QuizAI se
recupera al abrir VS Code, mientras que las vistas de experimentos del laboratorio
son temporales y se abren bajo demanda. Consulta [sesiones, configuración y pruebas](../android/README.md).
La tarea **AI-APPS Development** mantiene Android, Dart y Flutter fuera del
editor; abrir o cerrar un visor no compila, arranca ni detiene QuizAI.

## Corrección del transporte

EmbeDroid 1.0.2 generaba `scid` con `randomBytes(4).toString('hex')`
en el constructor y en cada arranque. El servidor scrcpy 3.2 interpreta ese
argumento con `Integer.parseInt(value, 16)`: acepta identificadores de 31
bits. El bit de signo provocaba `NumberFormatException` y la salida con
código 1. Véase [Options.java de scrcpy 3.2](https://github.com/Genymobile/scrcpy/blob/v3.2/server/src/main/java/com/genymobile/scrcpy/Options.java).

El registro actual confirma la causa el 10 de octubre de 2026 a las 14:47
Europe/Madrid (12:47 UTC), en
`%APPDATA%/Code/logs/20261010T141931/window1/exthost/output_logging_20261010T144729/3-Android Emulator.log`:

| Intento | scid rechazado | Resultado |
| --- | --- | --- |
| 1 | `cf1b8d37` | NumberFormatException, código 1 |
| 2 | `efb79b97` | NumberFormatException, código 1 |
| 3 | `a5439c11` | NumberFormatException, código 1 |
| 4 | `d47f445a` | NumberFormatException, código 1 |

Los cuatro valores superan `7fffffff`. La gestión de pestañas no explica
estas excepciones. Se corrigen los dos generadores dentro del transporte
EmbeDroid, sin añadir esperas ni reintentos.

La distribución mantenida `magullodev.ai-apps-embedroid` 1.0.3 deriva de
1.0.2 y está versionada en [scripts/embedroid/](../embedroid/README.md).
El generador limita a 31 bits y conserva ocho dígitos hexadecimales para
que coincidan el socket ADB y el nombre generado por scrcpy. La versión 1.1.0
conserva esta corrección y amplía las pestañas con identidad y serialización,
sin modificar el transporte scrcpy ni los archivos upstream.

## Instalación y actualizaciones

`scripts/install-embedroid.ps1` construye y comprueba el VSIX, lo instala,
retira la extensión original para evitar comandos duplicados y actualiza el
enlace de AI-APPS Android. Después recarga o reabre VS Code. No detiene Android
ni Flutter.

`scripts/install-vscode-android.ps1` instala solo el enlace de la integración;
para preparar ambos componentes utiliza:

```powershell
.\scripts\install-embedroid.ps1
```

La identidad propia impide que Marketplace sobrescriba el arreglo con una
actualización de `utpalbarman.embedroid`. Los archivos originales, sus
hashes, el generador, el constructor del VSIX y las pruebas están en Git.
No se edita el bundle instalado. La actualización upstream exige importar,
revisar y validar deliberadamente otra versión; el constructor rechaza un
paquete original que no coincida con los hashes fijados. El repositorio
upstream indicado por el paquete devolvió 404 durante esta intervención;
no se ha presentado un PR al autor.

## Validación del 10 de octubre de 2026

- Límites `00000000`, `7fffffff`, `80000000` y `ffffffff`, más 100.000
  identificadores aleatorios dentro del intervalo admitido.
- Clase real del bundle: constructor y arranque usan el generador corregido;
  el argumento del servidor y el socket ADB coinciden.
- Servidor incluido: el identificador original `ffffffff` reproduce la
  excepción y el código 1. Con el arreglo, tres transmisiones H.264 sostienen
  vídeo diez segundos cada una, sin errores y conectadas al primer intento.
- Webviews reales en un perfil aislado de VS Code: vídeo H.264, sin excepciones
  ni fallos de arranque. La prueba reproducible `host-test.ps1` abre dos
  procesos independientes sobre el mismo perfil y dos vistas en cada uno.
- Android conserva su identificador de arranque y QuizAI su PID. La tarea
  persistente y los procesos Dart/Flutter siguen activos, sin nueva compilación.

Los informes y registros de estas pruebas están en `.ai-apps/embedroid/`,
excluidos de Git. Las reaperturas aisladas no equivalen a afirmar que se ha
recargado el editor principal del usuario. La nueva distribución instalada
se carga al recargar o reabrir ese editor.

La corrección resuelve el rechazo de `scid`; otros cierres con código 0 o
255 requieren sus propias evidencias. Una pestaña abierta y el mensaje
`EmbeDroid abierto` solo acreditan la solicitud; el canal **Android Emulator**
debe confirmar `streaming h264` y `streaming established on attempt 1`.

## Comprobación en el editor principal

1. Recargar o reabrir VS Code, manteniendo **AI-APPS Development** activa.
2. Comprobar vídeo e interacción y el canal **Android Emulator**.
3. Repetir una reapertura y comprobar que Android, QuizAI, Dart y Flutter
   conservan sus procesos y que `dev-session.log` no registra otra compilación.

No uses **Stop Device**, **Boot** ni **Cold Boot** para reparar el visor.
