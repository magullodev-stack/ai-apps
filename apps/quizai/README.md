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

`SettingsPage` sigue siendo provisional. La futura pantalla de Ajustes
será la primera construida estrictamente sobre este sistema.

Quiz10 es la modalidad protagonista y conserva su acceso directo a la
partida existente. Sala y 1vs1 mantienen su estado no disponible; Estudio
conserva su acceso a la pantalla existente.

Los indicadores de puntos, racha y ranking mostrarán sus datos cuando
existan los sistemas responsables de proporcionar sus datos reales.

La cabecera incorpora el logotipo propio de QuizAI, registrado como
recurso gráfico de la aplicación en `assets/branding/`.

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

La navegación mantiene las pestañas Modalidades y Perfil, conserva la
selección al volver desde Configuración y permanece fija durante el
desplazamiento de la pantalla principal.
Los estilos particulares existentes siguen utilizando sus tamaños
y pesos hasta que se complete el rediseño de cada pantalla.

La pantalla principal utiliza cuatro PNG propios en assets/modalidades/.
Los textos y las acciones permanecen implementados en Flutter.

Los colores pertenecen a `lib/app/app_theme.dart`. La estructura general
y la navegación pertenecen a `lib/app/app_shell.dart`. Las tarjetas y la
pantalla de modalidades pertenecen a `lib/app/home/`.

El diseño se adapta al ancho disponible y permite desplazamiento vertical
cuando la altura del dispositivo no permite mostrar todas las modalidades.

## Navegación

La cabecera muestra **QuizAI** y el acceso a **Configuración**. La barra inferior fija alterna entre **Modalidades** y **Perfil**. Modalidades muestra directamente, en este orden, **🎲 Quiz10**, **🏆 Sala**, **⚔️ 1vs1** y **📚 Estudio**. Quiz10 y Estudio abren sus pantallas existentes; la generación se solicita desde **Jugar** o **Generar**, respectivamente. Sala y 1vs1 siguen sin estar disponibles. La flecha de regreso vuelve a la pantalla principal. Salir de una modalidad descarta su partida en memoria.

Perfil y Configuración muestran únicamente un estado provisional, sin funciones ni datos de usuario. Desde Configuración se puede volver a la pestaña de origen.

`lib/main.dart` arranca QuizAI. `lib/app/` contiene la identidad, el tema, la navegación general y las pantallas Modalidades, Perfil y Configuración. `lib/modes/quiz10/` contiene la pantalla, el estado, las reglas, la validación y la generación mediante IA de la modalidad 🎲 Quiz10. `lib/modes/estudio/` contiene la implementación de Estudio. Las pruebas del Design System y su integración se encuentran en `test/app/`.

## Ejecutar con IA

Con `emulator-5554` iniciado, desde la raíz del repositorio en PowerShell:

```powershell
.\apps\quizai\run.ps1
```

El procedimiento inicia o reutiliza el servicio Dart, conecta el emulador y abre QuizAI con la configuración de desarrollo de `gpt-4.1-mini`. Busca la clave OpenAI en el entorno y, si falta, la solicita con entrada oculta. No es necesario introducir un token; la clave no se incluye en Flutter ni en el APK. La tarea manual de VS Code **AI-APPS: ejecutar QuizAI con IA** usa este mismo procedimiento. Cambiar de pestaña o abrir Configuración no llama al modelo; pulsar **Jugar** dentro de 🎲 Quiz10 solicita una generación.

La generación usa el Dart incluido en Flutter. El proyecto Android conserva su compilación independiente. El prompt y las reglas siguen en Quiz10; el esquema no envía `minItems` ni `maxItems` y el validador sigue exigiendo diez preguntas.

Consulta [`ai/README.md`](../../ai/README.md) para las variables, diagnósticos, seguridad y ciclo de vida del servicio. El registro está en `.ai-apps/dart-service.log`; `scripts/run-android.ps1 -StopService` detiene el servicio local. En Flutter, `r` aplica Hot Reload, `R` reinicia la partida y `q` cierra la sesión.

## Comprobaciones

Desde `apps/quizai`:

```powershell
flutter analyze
flutter test
flutter build apk --debug
git diff --check
```

Las pruebas de `test/app/` cubren el contrato del Design System, Nunito, la compatibilidad del tema con superficies claras, el orden y disponibilidad de las modalidades, Home en distintos tamaños, la navegación fija al desplazar, el cambio de pestañas, Configuración y el regreso desde Quiz10 y Estudio. No ejecutan generaciones ni llamadas reales a modelos. El APK se genera en `build/app/outputs/flutter-apk/app-debug.apk`.

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
`lib/modes/quiz10/quiz10_DART_Pi+Di.dart`: 20 pivotes P01–P20 y 34 dimensiones D01–D34 expresadas como instrucciones directas.

Cada Quiz10 selecciona diez P distintas y diez D distintas. G recibe diez
unidades independientes y simultáneas:

```text
(P, I_D, H) -> F
(F, I_D) -> Q
(F, Q) -> O
```

`lib/modes/quiz10/Quiz10_PROMPT_G.dart` contiene el prompt de generación G.
`F` es un andamiaje factual transitorio que G materializa antes de construir la
pregunta; no entra en H, no se envía a R ni a S y no forma parte del test final.
`O` contiene cuatro opciones y `C` señala la correcta; internamente
`R := O_C`. G no recibe dificultad.

Cuando terminan las diez llamadas G, Dart transforma cada fila en
`Q, R, d1, d2, d3`. `lib/modes/quiz10/Quiz10_PROMPT_R.dart` revisa cada
ítem de forma independiente: se lanzan diez llamadas R simultáneas y cada una
devuelve únicamente los campos de su propio ítem que sea necesario corregir.

Dart aplica los parches R y construye el test corregido `T*`.
`lib/modes/quiz10/Quiz10_PROMPT_S.dart` define S, una única llamada global
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
