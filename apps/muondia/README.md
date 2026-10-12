# Muondia

**Muondia** es la aplicación móvil interactiva de AI-APPS. Vive en
`apps/muondia/`, con paquete Dart `muondia` e identificador Android
`com.aiapps.muondia`. La aplicación ya no se llama QuizAI; el antiguo Quiz10
no es una modalidad accesible desde Home.

## Experiencia

1. **Registro o acceso:** email, Google o Apple a través de
   `shared/identity/` (los proveedores requieren configuración).
2. **Recorrido inicial:** diez preguntas y una secuencia visual interactiva
   para presentar Muondia antes de entrar a Home. Es obligatorio hasta que
   el usuario lo termina.
3. **Home:** accesos a Salas y Estudio, además del perfil y ajustes. La
   partida de bienvenida no se expone como opción repetible de Home.

La entrada se decide en `lib/app/app.dart`. El recorrido vive en
`lib/app/onboarding/`, con la coreografía en `intro_sequence.dart`,
la pantalla en `interaction/onboarding_quiz_page.dart` y el generador,
revisor, ordenador y validador en `production/`. Se mantienen las reglas
de las diez preguntas y el pipeline real de IA, sin presentarlo como producto.

La finalización se guarda **por UID en el almacenamiento local privado**
(`lib/app/onboarding/completion_store.dart`) y solo después de completar
las diez preguntas y elegir «Entrar en Muondia». Una siguiente apertura
de la misma cuenta en este dispositivo entra directamente en Home. En otra
instalación o dispositivo, mientras no exista persistencia remota del
progreso, se realizará el recorrido allí también.

## Identidad visual

La entrada monta cuatro capas de `assets/auth/`: `Background.png`,
`Estrellas.png`, `Esferas.png` y `Robot.png`, con parallax suave.
Las capas respetan las áreas seguras; las barras nativas Android son negras.
Los botones de acceso y el texto legal forman un bloque inferior adaptable.

Home usa los recursos de `assets/home/` y un rótulo tipográfico «Muondia».
El icono de lanzamiento Android utiliza el símbolo gráfico ya presente en
`assets/branding/muondia_logo.png`, en lugar del icono predeterminado Flutter.
Los gráficos de la secuencia inicial viven en `assets/onboarding/loading/`.

## Arranque y sincronización

La tarea programada de Windows **AI-APPS Development** mantiene el emulador
`emulator-5554`, el servicio Dart, el runner Flutter y la sincronización de
la rama `dev`. El lanzador es `apps/muondia/run.ps1`; la entrada de la
sesión sigue siendo `scripts/start-dev-session.ps1`. No inicies otro
`flutter run` mientras la tarea esté activa.

El cambio de carpeta Flutter, de identificador Android y de actividad
Kotlin requiere **una recompilación/instalación nativa**, no basta con Hot
Reload. Tras sincronizar esta migración, reinicia una sola vez la tarea
de desarrollo para usar la nueva ruta y generar el nuevo paquete. El
arranque retira la antigua APK del emulador dedicado si sigue instalada.

## Firebase y autenticación

El nuevo `applicationId` es `com.aiapps.muondia`: Android lo trata como
otra aplicación. Regístrala en el proyecto Firebase compartido de AI-APPS,
descarga un `google-services.json` correspondiente **a ese ID** y colócalo
localmente en `apps/muondia/android/app/google-services.json`. No publiques
ese fichero. Es necesario registrar también las huellas SHA Android para
el proveedor Google. Un fichero configurado para el antiguo ID no sirve.

## Comprobaciones

Desde `apps/muondia/`, ejecuta `flutter test` para validar la interfaz,
el acceso, el recorrido, el diseño y las pantallas de Estudio.

El lanzador admite diagnósticos de IA:
- `.\apps\muondia\run.ps1 -ProbarLuna -Muestras 20`
- `.\apps\muondia\run.ps1 -ProbarOnboardingQuiz -Muestras 20`

El segundo invoca `tool/verify_onboarding_pipeline.dart`: audita
la producción real de las diez preguntas sin crear una modalidad nueva.
Los experimentos históricos de modelos se conservan como evidencias de
desarrollo, no como funciones del producto.
