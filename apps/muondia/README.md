# Muondia

## Explorador de experiencias de desarrollo

En VS Code, «Explorador de experiencias» permite abrir directamente Auth, Loading, Test de bienvenida y Home. El catálogo está en `lib/app/development/experiences.json` y las previews en `lib/app/development/experience_preview.dart`. Se reutilizan los widgets reales.

Loading ofrece tres estados; el test utiliza diez preguntas fijas. La previsualización evita Google Sign-In y las llamadas a IA, y no marca el onboarding como completado. La navegación real del usuario permanece independiente. Disponible solo en APK debug. Tras sincronizar `dev`, recarga VS Code para activar la vista; la sesión persistente de Flutter no se reinicia desde el panel.


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

La tarea programada de Windows **AI-APPS Development** inicia al entrar en
Windows la sincronización de `dev`, el AVD `AI_APPS_Dev` (`emulator-5554`),
el servicio Dart y **Muondia con Flutter**. Mantiene su sesión y Hot Reload
automático aunque VS Code esté cerrado. Al abrir el repositorio, AI-APPS Android
solo conecta el visor EmbeDroid al emulador ya activo. **No hay que pulsar F5**
para trabajar normalmente.

`scripts/start-dev-session.ps1` es el punto de entrada de la tarea y
`apps/muondia/run.ps1 -Device emulator-5554` ejecuta el Flutter Dev Runner
persistente. Los cambios Dart y de recursos recibidos mediante Git también
activan su recarga automática, sin depender de guardar desde VS Code.

**F5 con depuración:** la configuración `Muondia` de VS Code cede
temporalmente la sesión Flutter persistente al depurador, sin cerrar el
emulador ni el servicio de IA. Al terminar la depuración, la tarea
`postDebugTask` restaura `AI-APPS Development` si F5 había tomado su
control. Nunca se ejecutan simultáneamente dos sesiones Flutter en
`emulator-5554`. El sincronizador Git es independiente.

Los cambios nativos Android, plugins o dependencias provocan una nueva
compilación Gradle desde el runner persistente, no un Hot Reload. No existe
límite por número de reconstrucciones: solamente se limita la recuperación
tras pérdidas reales de conexión al emulador. La vigilancia de
`google-services.json` combina eventos de archivo y comprobación de contenido
periódica, útil cuando Windows sustituye el fichero sin notificar el cambio.
El arranque comprueba que Firebase corresponde a `com.aiapps.muondia`
y verifica los clientes OAuth para Google. Un fallo de inicialización
muestra un código de diagnóstico en Auth, sin exponer credenciales.

Si VS Code se cierra de forma forzada durante una depuración, el ciclo
normal vuelve a arrancar al iniciar Windows; en condiciones normales basta
con detener la sesión de depuración en VS Code.

## Atajo de desarrollo F7

En VS Code, **F7 vuelve a la pantalla Auth** desde onboarding, Home u otra
pantalla mientras Muondia esté ejecutándose en modo debug. No cierra Firebase,
no borra progreso y no exige F5 ni reiniciar Flutter. El comando
`AI-APPS Android: Volver a Auth (F7)` envía un intent explícito a
`MainActivity` mediante ADB. La actividad comunica el evento al
`MuondiaApp` a través de un canal Flutter de desarrollo, sin depender de
las teclas que EmbeDroid consiga transmitir.

Con sesión activa, Auth es una **previsualización de desarrollo**:
«Continuar con Google» reanuda la sesión sin pedir credenciales de nuevo y
vuelve a la pantalla que corresponde al estado real del usuario (onboarding
si está pendiente, Home si ya lo completó). El recorrido antiguo sigue
existiendo hasta que se rediseñe; este atajo no lo sustituye.

El manejador Flutter solo se registra en modo debug (`kDebugMode`) y la
actividad Android ignora ese intent cuando la app no es depurable. El
intent-filter está en el manifiesto debug. Las versiones release de Google
Play no incluyen este comportamiento.
Al actualizar la extensión enlazada del repositorio, recarga una vez VS Code
para que registre la asignación F7. La sesión persistente sigue independiente.

## Firebase y autenticación

El `applicationId` de Muondia es `com.aiapps.muondia`. Debe estar registrado
en el proyecto Firebase compartido de AI-APPS. Descarga el
`google-services.json` correspondiente **a ese ID** y colócalo localmente en
`apps/muondia/android/app/google-services.json`; no publiques ese fichero.
Para activar los botones reales de Auth:

1. Habilita **Google** y **Apple** en Firebase Authentication → Sign-in method.
2. Para Google en Android registra en Firebase los SHA-1 y SHA-256 del
   certificado con que firmas (debug y posteriormente release); vuelve a
   descargar `google-services.json` después de registrar las huellas y
   confirma que contiene el cliente OAuth web de ese proyecto.
3. Para Apple configura **Sign in with Apple** en Apple Developer (Services ID,
   clave privada de Sign in with Apple, Team ID y Key ID) y registra la
   configuración requerida en el proveedor Apple de Firebase. Verifica el
   dominio y la URL de retorno indicados por Firebase para el flujo web Android.
4. Ejecuta `flutter pub get` y recompila Muondia reiniciando de forma controlada
   la sesión persistente (o mediante F5 tras detenerla). Hot Reload no instala
   plugins nativos. Usa un emulador Android con Google Play Services para probar
   Google y un navegador funcional para Apple.

Las credenciales sensibles de Apple se configuran en sus consolas, nunca se
incorporan a los archivos Dart ni al repositorio. La identidad de ambos
proveedores desemboca en el mismo recorrido inicial o Home que email.

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
