# QuizAI

Aplicación con la modalidad estándar 🎲 Quiz10: diez preguntas de cultura general generadas mediante IA.

En la modalidad 🎲 se eligen diez áreas distintas. Cada pregunta tiene cuatro opciones; cada acierto suma un punto. Al finalizar se muestra el resultado sobre diez.

## Identidad visual de QuizAI

`lib/app/app_theme.dart` es la API canónica del **Design System v1** de
QuizAI. La identidad pertenece a esta aplicación y permanece en `lib/app/`.

El escenario es azul-violeta oscuro, con superficies de contenido claras
y limpias. El violeta brillante identifica la acción principal y la
selección. Los colores semánticos se reservan para estado: verde para
acierto, coral-rojo para error, amarillo para pista o premio y azul/cian
para información. Nunito es la única familia tipográfica, con títulos de
pesos altos y textos secundarios menos dominantes.

Los radios generosos, la profundidad suave y los controles táctiles
redondeados conforman la gramática común. La ilustración 3D/glossy aporta
personalidad en zonas protagonistas; las pantallas utilitarias no necesitan
decoración obligatoria. Home conserva su composición, sus recursos y su
navegación inferior integrada.

La API incluye `QuizPalette`, `QuizTypography`, `QuizSpacing`, `QuizRadii`,
`QuizShadows`, `QuizDurations`, `QuizLayout` y `quizAITheme`. La escala
espacial es 4/8/12/16/24/32; los radios son 12/18/24/28 y cápsula. El ancho
principal máximo es 640 y el padding horizontal normal es 14. Las
transiciones usan 180 o 240 ms y `easeOutCubic`; las sombras cubren card
y superficie elevada. Los valores propios de una composición permanecen
locales cuando no representan identidad común.

Las modalidades consumen esta identidad general y pueden variar de color
e ilustración sin cambiar su gramática. Sus reglas particulares no se
trasladan al sistema visual. Quiz10 y Estudio conservan su UI Material
actual: el tema global mantiene superficies claras para su compatibilidad,
y `AppShell` aplica explícitamente el escenario oscuro de Home. Material
conserva su rojo de error más oscuro para texto legible sobre superficies
claras; el coral de estado está disponible en `QuizPalette.error`.

`SettingsPage` implementa Ajustes v1, la primera pantalla construida
estrictamente sobre este sistema: escenario degradado, cabecera integrada,
tarjetas claras, filas redondeadas y switches violetas, sin ilustraciones.

Home se organiza alrededor de tres zonas de producto: Quiz10 como acceso
principal, Salas como espacio competitivo y Estudia tu documento como entrada
al contenido propio del usuario. Quiz10 conserva su acceso directo a la partida
existente y Estudia tu documento abre la modalidad Estudio, cuya primera capa
permite seleccionar un archivo compatible desde el selector nativo del sistema.
Las Salas visibles todavía no navegan.

Los indicadores de puntos, racha y ranking mostrarán sus datos cuando
existan los sistemas responsables de proporcionar sus datos reales.

Home muestra en su cabecera el logotipo propio de QuizAI y mantiene el acceso a
Ajustes. El logotipo se renderiza directamente desde
`assets/home/QuizAI_Home_LOGO.png`, sin animación ni capas adicionales.

La tipografía Nunito forma parte de la identidad visual de QuizAI.

La fuente variable se incorpora localmente en `assets/fonts/` y se
registra en `pubspec.yaml`. Se utiliza bajo la SIL Open Font License,
cuya copia se conserva en `assets/fonts/OFL.txt`.

La familia tipográfica y los estilos generales se configuran en
`lib/app/app_theme.dart`. Las pantallas de la aplicación y sus modalidades
utilizan el tema común, conservando sus responsabilidades particulares.

La navegación inferior utiliza explícitamente la misma familia.

La barra inferior de QuizAI utiliza una cápsula morada con dos pestañas
de igual anchura. La pestaña seleccionada ocupa su mitad mediante una
superficie clara, mientras que la pestaña inactiva conserva el fondo
morado. Los colores pertenecen a `lib/app/app_theme.dart` y el componente
de navegación pertenece a `lib/app/app_shell.dart`.

La navegación mantiene las pestañas Inicio y Perfil, conserva la selección al
volver desde Ajustes y permanece fija durante el desplazamiento de Home.
Los estilos particulares existentes siguen utilizando sus tamaños
y pesos hasta que se complete el rediseño de cada pantalla.

La estructura de Home permanece implementada en Flutter. El arte de Quiz10,
Salas, Estudia tu documento y el logotipo se mantiene desacoplado para poder
sustituir cada recurso sin modificar la jerarquía ni la navegación. El arte de
Estudia tu documento se muestra como una única imagen conservando su relación
de aspecto, sin texto, borde ni contenedor Flutter superpuestos.

Los colores pertenecen a `lib/app/app_theme.dart`. La estructura general
y la navegación pertenecen a `lib/app/app_shell.dart`. Home y sus bloques
pertenecen a `lib/app/home/`.

El diseño se adapta al ancho disponible y permite desplazamiento vertical
cuando la altura del dispositivo no permite mostrar todas las modalidades.

## Acceso inicial

QuizAI arranca en una pantalla de autenticación propia antes de entrar en la
aplicación. La composición principal conserva las capas 1080×1920 de marca y
los tres botones de acceso se renderizan con un único componente Flutter para
mantener exactamente la misma geometría.

QuizAI consume la capacidad compartida `ai_apps_identity` de
`shared/identity/`. `IdentityService` define el contrato y
`FirebaseIdentityService` implementa sesión persistente, acceso y registro con
email/contraseña, recuperación de contraseña y cierre de sesión sin exponer
Firebase a la aplicación.

**Continuar con email** abre una pantalla real con dos modos: iniciar sesión y
crear cuenta. Una sesión autenticada entra en `AppShell` y se conserva entre
arranques mediante Firebase Authentication.

Google y Apple comparten la misma API, pero sus proveedores todavía no están
conectados. Hasta incorporar sus SDK y credenciales devuelven un estado
explícito de proveedor pendiente; no simulan autenticación.

La configuración concreta del proyecto Firebase para Android/iOS todavía debe
registrarse en QuizAI. Sin esa configuración, la UI de email funciona pero el
backend de autenticación se identifica como no configurado.

El texto legal se renderiza como interfaz Flutter, no como imagen. **Términos
de uso** y **Política de privacidad** son enlaces independientes y subrayados;
mientras no existan los documentos definitivos, muestran los mismos avisos
provisionales que Ajustes.

## Navegación

Home muestra, en este orden, la cabecera con el espacio de marca y **Ajustes**,
el acceso principal a **Quiz10**, la zona **Salas** con tres accesos visibles y
el bloque **Estudia tu documento**. La barra inferior fija alterna entre
**Inicio** y **Perfil**. Quiz10 abre su partida existente; Estudia tu documento
abre Estudio y permite seleccionar un PDF, DOCX, PPTX, JPEG o PNG desde el
selector nativo; las Salas todavía no navegan. La flecha de regreso vuelve a
Home. Salir de una modalidad descarta su
partida en memoria.


## Estudio — archivo → StudyDocument → quiz

Al abrir Estudio se muestra **Subir archivo**. QuizAI permite seleccionar un
único PDF, DOCX, PPTX, JPEG o PNG desde el selector nativo. Los límites activos
de tamaño son **PDF 25 MB**, **DOCX 10 MB**, **PPTX 20 MB** y **JPEG/PNG
10 MB**.

Después de seleccionar el archivo, Estudio lo lee localmente y construye un
`StudyDocument`: una representación fiel del texto extraído, organizada en
secciones, subsecciones y bloques con referencia a su procedencia. El
`StudyDocument` no es un resumen y no sustituye contenido por conocimiento
general.

La extracción es específica por formato:

- PDF: extrae la capa de texto por página y admite hasta **300 páginas**.
- DOCX: lee su estructura OOXML, conserva encabezados y admite hasta
  **75.000 palabras**.
- PPTX: lee el OOXML de las diapositivas y admite hasta **100 diapositivas**.
- JPEG/PNG: aplica OCR local al archivo seleccionado.

Los bloques se dividen además en fragmentos técnicos internos para ejecución.
Esa fragmentación no forma parte de la jerarquía visible: el usuario selecciona
secciones o subsecciones reales del documento.

QuizAI persiste localmente el `StudyDocument` procesado en el almacenamiento
privado de la aplicación. No copia el archivo original a una biblioteca propia
ni lo sube como archivo a un servidor. El original sigue donde lo tenía el
usuario; la representación procesada permite volver a crear quizzes sin
depender de releer ese archivo cada vez.

Al pulsar **Crear quiz**, Estudio entrega a su generador únicamente el texto de
la sección o subsección seleccionada. La generación funciona como fuente
cerrada: pivotes, hechos, preguntas y respuestas correctas deben estar
sustentados por ese texto y no pueden completarse con conocimiento externo.

Perfil mantiene su estado provisional, sin funciones ni datos de usuario.
Desde Ajustes se vuelve a la pestaña de origen; la navegación inferior no
se muestra dentro de esta pantalla.

## Ajustes v1

La sección **Experiencia** reúne Sonidos y Vibración (activados inicialmente)
y Reducir animaciones (desactivado inicialmente). Toda la fila permite
alternar cada preferencia, con estado accesible y una transición suave.

Las preferencias pertenecen a QuizAI. `QuizSettings` vive en `AppShell` y
`SettingsPage` recibe su valor y comunica los cambios. Se conservan al
cerrar y volver a abrir Ajustes durante la sesión, incluso desde otra
pestaña. No existe persistencia en disco: al iniciar una nueva sesión se
restauran los valores iniciales. Todavía no hay consumidores de sonido ni
vibración, y las preferencias no modifican las mecánicas de las modalidades.

La sección **Información** incluye Privacidad, Términos de uso y Versión
`1.0.0`. Privacidad y Términos muestran únicamente un diálogo que indica
que su contenido todavía no está disponible: no contienen documentación
legal ni enlaces. Versión es informativa y no navega.

Los componentes reutilizados pertenecen a `lib/app/settings/` y consumen
los tokens de `app_theme.dart`; no se trasladan a la UI compartida.

`lib/main.dart` arranca QuizAI. `lib/app/` contiene la identidad y la experiencia general; `app/interaction/` presenta las intervenciones de QuizAI y `app/onboarding/` gobierna sus secuencias iniciales. `lib/modes/quiz10/` separa `interaction/`, responsable de la partida y su escena propia, y `production/`, responsable de construir y validar sus tests. `lib/modes/estudio/` contiene la implementación de Estudio. Las pruebas del Design System y su integración se encuentran en `test/app/`.

## Ejecutar con IA

Con `emulator-5554` iniciado, desde la raíz del repositorio en PowerShell:

```powershell
.\apps\quizai\run.ps1
```

El procedimiento inicia o reutiliza el servicio Dart, conecta el emulador y abre QuizAI con la configuración de desarrollo de `gpt-4.1-mini`. Busca la clave OpenAI en el entorno y, si falta, la solicita con entrada oculta. No es necesario introducir un token; la clave no se incluye en Flutter ni en el APK. La tarea manual de VS Code **AI-APPS: ejecutar QuizAI con IA** usa este mismo procedimiento. Cambiar de pestaña o abrir Ajustes no llama al modelo; pulsar **Jugar** dentro de 🎲 Quiz10 solicita una generación.

La generación usa el Dart incluido en Flutter. El proyecto Android conserva su compilación independiente. El prompt y las reglas siguen en Quiz10; el esquema no envía `minItems` ni `maxItems` y el validador sigue exigiendo diez preguntas.

Consulta [`ai/README.md`](../../ai/README.md) para las variables, diagnósticos, seguridad y ciclo de vida del servicio. El registro está en `.ai-apps/dart-service.log`; `run.ps1 -StopService` detiene el servicio local. En desarrollo, `run.ps1` mantiene Hot Reload automático cuando cambian archivos Dart o assets durante una sincronización. `r` fuerza Hot Reload, `R` hace Hot Restart y `q` cierra la sesión.

## Comprobaciones

Desde `apps/quizai`:

```powershell
flutter analyze
flutter test
flutter build apk --debug
git diff --check
```

Las pruebas de `test/app/` cubren el contrato del Design System, Nunito, la entrada de autenticación y el flujo de email, la compatibilidad del tema con superficies claras, la jerarquía de Home en distintos tamaños, la navegación fija al desplazar, el cambio de pestañas y el regreso desde Quiz10 y Estudio. En Ajustes verifican las preferencias iniciales, las filas pulsables, la semántica accesible, el estado de sesión, los diálogos y el texto ampliado en pantallas estrechas. No ejecutan generaciones ni llamadas reales a modelos. El APK se genera en `build/app/outputs/flutter-apk/app-debug.apk`.

Para una generación real explícita, desde la raíz:

```powershell
.\apps\quizai\run.ps1 -VerifyOnly
```

La comprobación usa `gpt-4.1-mini` y solo tiene éxito si el validador de Quiz10 acepta diez preguntas. No modifica la sesión Android. El resultado sin contenido ni credenciales queda en `.ai-apps/quizai-verification.json`.

### Apertura automática desde AI-APPS

AI-APPS prepara el emulador compartido al abrir VS Code. Si
`.ai-apps/active-game.txt` contiene `quizai`, también ejecuta
`apps/quizai/run.ps1` automáticamente en la terminal integrada.

El lanzador de QuizAI conserva la preparación del servicio Dart de IA.
Si necesita una clave OpenAI, la solicita en la terminal.

Para trabajar sin abrir ningún juego, establecer `none` como juego
activo. El archivo de selección es local y no se publica en Git.

## Generación Quiz10: G → R → S → Dart

El catálogo canónico se encuentra en
`lib/modes/quiz10/production/quiz10_DART_Pi+Di.dart`: 20 pivotes P01–P20 y 34 dimensiones D01–D34 expresadas como instrucciones directas.

Cada Quiz10 selecciona diez P distintas y diez D distintas. G recibe diez
unidades independientes y simultáneas:

```text
(P, I_D, H) -> F
(F, I_D) -> Q
(F, Q) -> O
```

`lib/modes/quiz10/production/Quiz10_PROMPT_G.dart` contiene el prompt de generación G.
`F` es un andamiaje factual transitorio que G materializa antes de construir la
pregunta; no entra en H, no se envía a R ni a S y no forma parte del test final.
`O` contiene cuatro opciones y `C` señala la correcta; internamente
`R := O_C`. G no recibe dificultad.

Cuando terminan las diez llamadas G, Dart transforma cada fila en
`Q, R, d1, d2, d3`. `lib/modes/quiz10/production/Quiz10_PROMPT_R.dart` revisa cada
ítem de forma independiente: se lanzan diez llamadas R simultáneas y cada una
devuelve únicamente los campos de su propio ítem que sea necesario corregir.

Dart aplica los parches R y construye el test corregido `T*`.
`lib/modes/quiz10/production/Quiz10_PROMPT_S.dart` define S, una única llamada global
que recibe las diez preguntas corregidas y devuelve exclusivamente su orden
relativo de dificultad. S no corrige contenido.

Dart aplica el orden de S y, al final, baraja las cuatro opciones de cada
pregunta. La posición de la respuesta correcta que produjo G no llega al
jugador.

`H` es el histórico de pares `(Q,R)` ya usados por cruce P×D. El pipeline
no lo actualiza hasta terminar R; guarda la pregunta y la respuesta corregidas.
El orden posterior de S no modifica H.

La pantalla Quiz10 está conectada al pipeline real. Dentro de una misma sesión,
`Otra partida` reutiliza la instancia del pipeline y por tanto su H.

Para auditar solo G:

```powershell
.\apps\quizai\run.ps1 -ProbarLuna -Muestras 20
```

Para auditar el flujo completo G → R → S → Dart:

```powershell
.\apps\quizai\run.ps1 -ProbarQuiz10 -Muestras 20
```

La auditoría completa conserva por test la salida de G, las diez entradas y
salidas R, las correcciones, el test tras R, la entrada y salida S, el orden,
el test resultante y las opciones tras el shuffle de Dart. La terminal resume
G, R, S y TOTAL en una sola tabla por test y mantiene `CAMBIOS` con los
valores G/R únicamente cuando R corrige campos.
