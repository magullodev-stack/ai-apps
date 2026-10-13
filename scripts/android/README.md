# Sesiones Android independientes

AI-APPS Android identifica aplicaciones mediante su registro local y muestra
cada emulador con EmbeDroid dentro de VS Code. Android, Dart y los procesos
Flutter se ejecutan fuera del editor. Abrir, cerrar o reconectar un visor no
reinicia ninguna aplicación.

## Instalación

```powershell
.\scripts\install-embedroid.ps1
```

Tras instalar, recarga VS Code. La integración recupera la sesión activa
de Muondia en `emulator-5554`; otras aplicaciones registradas pueden
abrirse desde el selector **AI-APPS Android**.

Muondia utiliza la tarea persistente `AI-APPS Development`. Su identificador,
paquete `com.aiapps.muondia` y AVD `AI_APPS_Dev` están reservados.
No ejecutes una segunda instancia Flutter sobre ese dispositivo.

## Otras aplicaciones Flutter

El registro permite conectar proyectos Flutter independientes con su propio
AVD, serial y paquete Android, sin compartir el dispositivo de Muondia.
Ejemplo para una aplicación real ya existente:

```powershell
.\scripts\android-session.ps1 -Action Register `
  -AppId app-demo -Label 'App Demo' `
  -Serial emulator-5556 -AvdName AI_APPS_Demo `
  -ProjectPath 'C:\ruta\app-flutter' -PackageName dev.example.demo
.\scripts\android-session.ps1 -Action Start -AppId app-demo -Serial emulator-5556
.\scripts\android-session.ps1 -Action List
.\scripts\android-session.ps1 -Action Stop -AppId app-demo -Serial emulator-5556
```

El ejemplo no registra ni instala ninguna aplicación por sí mismo. Cada
sesión queda aislada por dispositivo y AVD; el controlador rechaza el uso
compartido de `emulator-5554` y dos procesos Flutter sobre un dispositivo.

Para retirar el registro de una aplicación detenida, utiliza
`-Action Unregister`. Esta operación no borra el código, el AVD ni otros
archivos. Android mantiene estados y registros en `.ai-apps/android/`,
fuera de Git.

## Visores y recuperación

VS Code recupera Muondia al abrir el repositorio. Un visor cerrado
manualmente permanece cerrado hasta que se elige desde el selector;
otras sesiones se abren bajo demanda. EmbeDroid guarda únicamente el
serial del dispositivo y consulta la identidad actual de la aplicación
en el registro. No persiste nombres antiguos.

El visor se reconecta sin reiniciar Android ni Flutter. Si está detenida,
la tarea de desarrollo se solicita al Programador de tareas; la extensión
no abre APK antiguas ni inicia otro `flutter run` por su cuenta.
El sondeo cada cinco segundos detecta cambios de estado.

## Verificación

```powershell
.\scripts\embedroid\test.ps1
.\scripts\android\test.ps1
```

Las pruebas simulan el registro persistente, la exclusividad de AVD,
los arranques concurrentes, las paradas, la reconexión de visores, la
restauración y la recuperación de Muondia. Para verificar dos aplicaciones
reales se dispone de `scripts/android/host-test.ps1`, que exige
`-AppId`, `-Serial` y `-Label` de una segunda aplicación activa.
No crea una segunda aplicación.
