# Muondia

**Muondia** es la aplicación móvil interactiva de AI-APPS. Vive en
`apps/muondia/`, con paquete Dart `muondia` e identificador Android
`com.aiapps.muondia`. El test inicial de diez preguntas forma parte del
recorrido de bienvenida y no es una modalidad independiente.

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
Sobre la bienvenida se muestra el PNG original
`assets/auth/Logotipo_MuondIA.png`, centrado y sin alterar su proporción.
La bienvenida se limita a «¡Qué alegría verte por aquí! ¿Empezamos?»,
distribuida en tres líneas con la tipografía redondeada Nunito en peso
máximo, tamaño grande adaptable y color blanco. Se muestra sobre la franja
azul anterior al robot, sin modificar la posición ni las animaciones de
las ilustraciones. El texto se ajusta desde
`lib/app/auth/auth_entry_page.dart`.
Los botones de acceso y el texto legal forman un bloque inferior adaptable.
Los tres botones se dibujan mediante Flutter; Google utiliza
`assets/auth/Muondia_Auth_Google_ICON.png` como icono.

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

Los cambios de Dart y assets se recogen mediante Hot Reload automático.
Las modificaciones de identificador Android, actividad Kotlin o configuración
nativa sí requieren **una recompilación/instalación nativa**.

## Firebase y autenticación

El `applicationId` de Muondia es `com.aiapps.muondia`. Debe estar registrado
en el proyecto Firebase compartido de AI-APPS. Descarga el
`google-services.json` correspondiente **a ese ID** y colócalo localmente en
`apps/muondia/android/app/google-services.json`; no publiques ese fichero.
Es necesario registrar también las huellas SHA Android para Google.

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
