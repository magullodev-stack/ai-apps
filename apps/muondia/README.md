# Muondia

## Explorador de experiencias de desarrollo

La interfaz visual de Auth se gestiona desde el explorador **AI-APPS Android**
en VS Code, sin paneles de capas duplicados en Flutter. Cada imagen tiene
un ojo reversible y acciones de sustitución y borrado seguro.

En VS Code, expande Muondia en la vista existente «AI-APPS Android» y entra en **ACCESO → Auth**, **PRIMERA EXPERIENCIA → Loading del robot / Test de bienvenida** o **APLICACIÓN → Home**, o usa **Buscar pantalla…**. El catálogo está en `lib/app/development/experiences.json` y las previews en `lib/app/development/experience_preview.dart`. Se reutilizan los widgets reales.

Loading ofrece tres estados; el test utiliza diez preguntas fijas. En la aplicación real ejecutada en modo debug, el arranque muestra Auth en previsualización, sin entrar en el onboarding y sin generar preguntas. También F7 abre esta vista segura. «Continuar con Google» en la previsualización pasa al Loading simulado, sin iniciar sesión real. El test del explorador usa diez preguntas fijas; no modifica el progreso. La navegación de usuarios en release no cambia.

La entrada **Recorrido real** cambia la misma sesión del emulador a la ruta
auténtica de Firebase: muestra Auth si no hay usuario y, si hay una sesión,
entra al onboarding pendiente o a Home. Desde cualquier pantalla puede
abrirse otra previsualización para regresar al modo UI. No se desconecta la
cuenta, no se borra el progreso, no se lanza otro Flutter y Hot Reload
conserva la elección real. **Atención:** el onboarding auténtico puede
generar contenido con IA; las vistas previas siguen siendo seguras y
utilizan datos de prueba. En compilaciones debug el emulador comunica su ubicación efectiva
(`preview:experiencia:estado` o `real`) a la extensión. La carpeta que
contiene la experiencia activa se ilumina en amarillo, la pantalla activa
muestra el ojo amarillo y la cabecera ofrece su ruta; los cambios hechos
tocando el emulador se reflejan en el siguiente sondeo. El modo real se
distingue claramente, aunque las rutas internas de Home todavía no se
identifican individualmente. Este protocolo es solo debug y no expone
identificadores de usuario ni contraseñas. Después de cambiar el código de la extensión, recarga
VS Code una vez; como el intent Android también cambia, la tarea
persistente reconstruirá la parte nativa cuando corresponda.


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

La entrada utiliza `Background.png` y `Robot.png` de `assets/auth/`,
con un movimiento suave del robot. El logo y el icono de Google se
mantienen como recursos independientes.
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

## Ilustraciones de pivotes del test inicial

Los veinte PNG originales transparentes están en `assets/Pivotes/` (P mayúscula),
registrados en `pubspec.yaml`. No se duplican ni se renombran.
La lista canónica de códigos y nombres está en
`lib/app/onboarding/production/onboarding_dimensions.dart`.
`lib/app/onboarding/pivot_images.dart` resuelve el recurso a partir del
pivote que contiene cada pregunta de `OnboardingQuizFinalQuestion`.
Por ejemplo, `Física` → `assets/Pivotes/P08 - Física.png`; los pivotes
no registrados no reciben imágenes de otro tema.
Tras pasar de pregunta se resuelve el recurso del nuevo pivote, sin
modificar la generación, revisión, ordenación o historial de IA.

El test de previsualización utiliza diez pivotes canónicos con preguntas
ficticias y no realiza llamadas a IA. Sus imágenes están declaradas como
recursos del estado `Test de bienvenida` en el explorador Android.
En esta previsualización el cronómetro permanece fijo en 60 s y la barra
llena, sin iniciar ningún temporizador: se pueden recorrer las preguntas y
probar los comodines durante el tiempo que sea necesario. Solo el recorrido
real activa la cuenta atrás de 60 s; esta distinción se configura
explícitamente mediante `countdownEnabled`, sin deducirla de que existan
preguntas de prueba.
`OnboardingQuizPage` conserva el estado y las reglas del cuestionario;
`interaction/onboarding_quiz_scene.dart` compone toda la pantalla sobre un
fondo índigo-violeta continuo, sin esquinas ni marco exterior redondeado.
`interaction/onboarding_quiz_backdrop.dart` pinta halos, órbitas luminosas
y grano fino reproducible con CustomPainter; no incorpora una captura
de pantalla con textos como recurso de fondo. La cabecera se integra
sin fondo propio, sin flecha de regreso (el onboarding es obligatorio),
con el PNG original del pivote activo y su nombre en Nunito blanca de
tamaño contenido. El contador de preguntas, el cronómetro de 60 s y
la barra de tiempo usan una jerarquía tipográfica secundaria.
Una gran tarjeta clara reúne el enunciado y cuatro tarjetas de
respuesta blancas con sombra. Las letras A–D utilizan distintivos rectangulares
redondeados en lila neutro y un separador vertical fino, iguales para las
cuatro opciones; no hay códigos de color por letra. La puntuación se muestra
al finalizar. La tarjeta ocupa únicamente el espacio vertical entre la
cabecera y los comodines y conserva esa geometría con opciones cortas o
largas. Cada respuesta incrementa su altura para admitir varias líneas,
sin escalar el texto para encajarlo. Si el contenido no cabe, se desplaza
solamente el interior de la tarjeta; los comodines y la cabecera siguen
visibles. El desplazamiento vuelve al inicio en cada pregunta.
La composición es particular de Muondia y no modifica el tema global ni
los componentes compartidos. La imagen conserva su
proporción y se carga mediante `onboardingPivotImageFor()`. El contador
indica la pregunta visible (por ejemplo, `3/10`); la barra y el cronómetro
reflejan el tiempo restante de una única cuenta atrás para todo el test,
sin reiniciarse al avanzar. Empieza al aparecer la primera pregunta.
Al agotarse, el test concluye con la puntuación alcanzada. La pantalla
no incluye flecha de regreso: el test es un paso obligatorio y no ofrece
un destino de retroceso dentro del recorrido.

Al pulsar una respuesta, la tarjeta elegida se cubre durante medio segundo
con un velo semitransparente verde si es correcto o rojo si falla. Si falla,
solo se señala la respuesta elegida en rojo: no se revela la correcta.
Las demás tarjetas quedan bloqueadas y a los 500 ms se avanza
automáticamente, sin «Siguiente».
La última respuesta lleva a resultados, pero **el usuario sigue pulsando
«Entrar en Muondia»** para registrar la finalización del onboarding.
Los temporizadores pendientes se cancelan al desmontar o reiniciar la página.
Los comodines 50 % y Pista IA disponen de un uso cada uno compartido entre las
diez preguntas; sus contadores no se reinician entre preguntas y sus cifras
oscuras contrastan con el amarillo de los distintivos. Cada esfera amarilla
solo se dibuja mientras haya usos disponibles. Al agotarse uno, la esfera
desaparece por completo (nunca muestra «0») y su botón permanece en el mismo
sitio pero queda atenuado al 40 % y sin interacción, igual que una respuesta
descartada por el 50 %. Ambos comodines se comportan de forma independiente.
50 % desactiva dos respuestas incorrectas de la pregunta actual, pero
mantiene las cuatro tarjetas visibles y exactamente en la misma posición;
solo atenúa las descartadas con un velo, que impide pulsarlas. La tarjeta
contenedora conserva su tamaño. Pista IA solicita al servicio
Dart existente una orientación conceptual corta que no debe revelar la
respuesta; un fallo de red o validación no consume el uso y permite reintentar.
El reloj se detiene mientras se genera y se lee la pista, pero no al usar 50 %.
Las previsualizaciones nunca contactan con IA y muestran explícitamente una
pista de demostración.

Las pruebas de `test/app/onboarding_quiz_page_test.dart` comprueban el
contenedor de pregunta/respuestas, la visibilidad de las cuatro tarjetas en
formato móvil, opciones de múltiples líneas con desplazamiento interno
sin mover cabecera, tarjeta ni comodines, textos largos al 200 %,
el reinicio del desplazamiento al avanzar, la ausencia de flecha
de regreso, las diez temáticas, la puntuación, la cuenta atrás global, los comodines, los distintivos neutros y la
ausencia de redondeo exterior; en particular verifican que activar 50 %
no elimine ninguna respuesta ni modifique sus dimensiones o coordenadas,
además del bloqueo durante los 500 ms de feedback.

`MuondiaSystemSafeFrame` en `lib/app/system_safe_frame.dart` establece el
mismo respeto a las barras de estado y navegación de Auth en todas las
pantallas mediante el `builder` raíz de `MaterialApp`: fondo negro
exterior, iconos claros y un solo `SafeArea` común, compatible con las
zonas seguras interiores de Auth, Loading y Home. Sin una segunda sesión
Flutter ni cambios de configuración de Android.

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

## Capas e imágenes (debug)

En el explorador **AI-APPS Android**, abre **Muondia → ACCESO → Auth** para ver sus imágenes directamente bajo la pantalla (Background, Robot, logotipo e icono de Google). **Home** y **Loading del robot** muestran las suyas del mismo modo, sin carpeta intermedia. Usa el ojo situado a la derecha para ocultar o mostrar, o el botón derecho para sustituir o eliminar. La eliminación de código solo está disponible cuando la capa está identificada de forma segura. Las relaciones pantalla/carpeta se declaran en `lib/app/development/experiences.json` con `assetDirectories`. La visibilidad se restablece al reiniciar Flutter; el inspector no se incorpora a release ni genera llamadas a IA.
