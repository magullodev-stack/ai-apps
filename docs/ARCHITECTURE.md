# Arquitectura de Quiz10

## Propósito

Este documento define la arquitectura conceptual inicial de Quiz10.

Su objetivo es establecer:

- qué responsabilidades pertenecen a cada capa;
- qué dependencias están permitidas;
- qué decisiones deben permanecer separadas;
- cómo se relacionan la infraestructura, las reglas del juego y su representación;
- cómo debe crecer el repositorio sin erosionar esas fronteras.

La topología física del repositorio puede evolucionar cuando la tecnología lo exija.

La separación de responsabilidades definida aquí no depende de una tecnología concreta.

---

# 1. Definición del producto

Quiz10 es un juego de conocimiento basado en una interacción por turnos entre una IA y un concursante.

No es un chat presentado como juego.

No es un test estático compuesto simplemente por diez preguntas previamente almacenadas.

No es una colección cerrada de cuestionarios prefabricados.

Quiz10 utiliza una estructura de juego estable para recorrer un espacio de conocimiento potencialmente abierto.

El usuario propone un tema.

El sistema construye internamente una ruta de cobertura sobre ese tema.

La partida materializa esa planificación mediante diez turnos reales de interacción.

El ciclo fundamental es:

**IA pregunta → concursante responde → sistema resuelve → juego avanza**

La interfaz puede representarlo mediante paneles, botones, imágenes, animaciones y otros elementos visuales sin adoptar la apariencia de un chat.

La interacción con IA pertenece al funcionamiento del juego, aunque su representación visible sea la de un concurso.

---

# 2. Principio fundamental

Quiz10 es:

> **un juego cerrado en su estructura y abierto en su conocimiento.**

La estructura fundamental de una partida estándar permanece estable:

- una partida;
- diez turnos;
- una pregunta activa cada vez;
- cuatro opciones;
- una intervención real del concursante;
- una resolución;
- un progreso;
- un resultado final.

El contenido puede cambiar entre partidas.

Un tema como:

- historia;
- ciencia;
- arte;
- programación;
- literatura;
- cine;
- geografía;
- química;
- música;

es un dato de ejecución.

No constituye un sistema arquitectónico nuevo.

La arquitectura de Quiz10 no debe necesitar una implementación distinta para cada tema.

---

# 3. Unidad fundamental: el turno

La unidad fundamental del juego no es la pregunta aislada.

Es el **turno**.

Un turno contiene conceptualmente:

**Pregunta + Intervención del concursante + Resolución**

La pregunta es contenido.

El turno es comportamiento.

La partida es una secuencia gobernada de turnos.

Una partida estándar de Quiz10 contiene exactamente diez turnos resueltos.

El sistema nunca debe simular la intervención del concursante para avanzar una partida normal.

---

# 4. Ruta de cobertura

Antes de desarrollar la partida, Quiz10 construye internamente una Ruta de Cobertura.

La Ruta de Cobertura determina qué conocimientos serán evaluados y cómo se distribuirán dentro del tema elegido.

Cada posición puede contener conceptualmente:

- dificultad;
- área;
- grupo;
- referente;
- conocimiento;
- respuesta esperada.

La ruta estándar contiene diez posiciones.

Cada posición gobierna un turno de la partida.

La Ruta de Cobertura:

- permanece oculta al concursante;
- favorece diversidad temática;
- reduce repeticiones;
- controla la progresión de dificultad;
- aporta coherencia a la partida completa;
- evita tratar cada pregunta como una improvisación completamente independiente.

La IA puede colaborar en su generación.

El estado estructurado mantenido por Quiz10 conserva la autoridad sobre la ejecución de la partida.

---

# 5. Separación arquitectónica A–B–C

Quiz10 separa estrictamente tres responsabilidades:

| Capa | Responsabilidad |
|---|---|
| A | Infraestructura y capacidades técnicas |
| B | Reglas y comportamiento de Quiz10 |
| C | Materialización visible e interactiva |

Esta separación expresa autoridad, no únicamente organización de carpetas.

La pregunta fundamental para clasificar una responsabilidad es:

> **¿Quién debe tener autoridad para decidir esto?**

---

# 6. A — Columna vertebral estable

A contiene la infraestructura, contratos y servicios técnicos que permiten ejecutar el producto.

A puede proporcionar capacidades como:

- configuración;
- red;
- acceso técnico a modelos de IA;
- serialización;
- persistencia;
- almacenamiento;
- autenticación;
- seguridad;
- localización;
- logging;
- telemetría;
- caché;
- recuperación ante errores;
- servicios técnicos transversales;
- contratos para integraciones externas.

A puede saber:

> “Envía esta petición estructurada a un servicio y devuelve una respuesta estructurada.”

A no debe saber:

> “La pregunta 8 de Quiz10 debe ser difícil.”

A tampoco debe decidir:

- cuántos turnos tiene una partida;
- qué significa acertar;
- cuándo finaliza Quiz10;
- cómo se calculan las estrellas;
- qué dificultad corresponde a cada turno;
- qué significado de juego tiene seleccionar A, B, C o D.

**A hace posible Quiz10, pero no sabe jugar a Quiz10.**

Correspondencia inicial en el repositorio:

`core/`

---

# 7. B — La mente de Quiz10

B contiene las reglas que convierten las capacidades técnicas en el juego Quiz10.

Aquí reside la lógica específica del producto.

B gobierna conceptos como:

- partida;
- sesión;
- turno;
- tema;
- Ruta de Cobertura;
- progresión de dificultad;
- generación lógica de preguntas;
- alternativas A, B, C y D;
- respuesta correcta;
- intervención del concursante;
- resolución;
- progreso;
- aciertos;
- errores;
- puntuación;
- resultado;
- estrellas;
- reglas de repetición;
- revisión de fallos;
- comportamiento específico de los distintos modos de Quiz10.

B también determina qué papel debe desempeñar la IA dentro del juego.

La infraestructura técnica utilizada para acceder a un modelo pertenece a A.

Las instrucciones y reglas mediante las cuales Quiz10 utiliza esa capacidad pertenecen a B.

Por tanto:

**A conecta con capacidades externas.**

**B les da significado dentro de Quiz10.**

B no depende de:

- Jetpack Compose;
- componentes visuales concretos;
- SDKs concretos de proveedores de IA;
- implementaciones concretas de persistencia;
- implementaciones concretas de red;
- detalles de autenticación;
- detalles de facturación.

Correspondencia inicial en el repositorio:

`systems/`

La lógica principal del producto podrá materializarse bajo:

`systems/quiz10/`

Los temas introducidos por el usuario no crean carpetas o sistemas nuevos dentro de `systems/`.

---

# 8. C — El cuerpo visible de Quiz10

C convierte el estado del juego en una experiencia visible, táctil e interactiva.

C puede contener:

- pantallas;
- paneles;
- tablero de juego;
- pregunta visible;
- categoría;
- dificultad;
- opciones A, B, C y D;
- contenido visual;
- imágenes;
- progreso;
- estados correcto e incorrecto;
- explicación;
- puntuación visible;
- temporizadores;
- animaciones;
- sonidos;
- navegación visible;
- resultado final;
- clasificación;
- estados de carga;
- errores visibles;
- identidad visual;
- adaptaciones de plataforma.

C recibe estado y datos estructurados.

C los representa.

Cuando el concursante interactúa, C comunica una intervención al sistema.

Por ejemplo:

**SelectAnswer(B)**

C no decide si B es correcta.

C no incrementa directamente el marcador.

C no modifica directamente una sesión.

C no determina por sí sola la siguiente pregunta.

**C expresa Quiz10, pero no gobierna Quiz10.**

Correspondencia inicial en el repositorio:

`ui/`

---

# 9. Composición ejecutable

Las aplicaciones ejecutables ensamblan las piezas necesarias del producto.

Su responsabilidad es conectar implementaciones concretas con contratos y módulos existentes.

Pueden encargarse de:

- iniciar la plataforma;
- cargar configuración;
- registrar implementaciones;
- conectar servicios técnicos;
- montar la interfaz;
- iniciar el servidor;
- iniciar la aplicación móvil;
- delegar la ejecución.

Los puntos de entrada no contienen una segunda implementación de las reglas de Quiz10.

La composición no constituye una cuarta capa de dominio.

Es el lugar donde A, B y C se conectan para producir un ejecutable.

Correspondencia inicial:

`apps/`

Las aplicaciones concretas podrán incluir, cuando corresponda:

- `apps/mobile/`
- `apps/server/`

La existencia de otras aplicaciones dependerá de necesidades reales del producto.

---

# 10. Estado y fuente de verdad

El estado estructurado mantenido por Quiz10 es la fuente de verdad de una partida.

Nunca lo es una representación textual generada por un modelo.

El sistema debe poder conservar estructuradamente información como:

- identificador de sesión;
- tema;
- estado de la partida;
- número de turno;
- Ruta de Cobertura;
- pregunta activa;
- respuesta correcta;
- selección del concursante;
- aciertos;
- errores;
- progreso;
- historial;
- resultado acumulado.

Si un texto generado contradice el estado interno, prevalece el estado estructurado.

La representación visual tampoco constituye la fuente de verdad.

C representa el estado.

B lo gobierna.

---

# 11. Resolución determinista de respuestas cerradas

Cuando una pregunta A–B–C–D ya ha sido generada y validada, Quiz10 conoce internamente cuál es la opción correcta.

Una selección cerrada puede resolverse comparando:

**opción seleccionada** con **opción correcta**

No es necesario delegar nuevamente en un modelo de IA una comparación que ya puede resolverse de forma determinista.

La IA puede generar:

- contenido;
- alternativas;
- solución;
- explicación.

Quiz10 conserva esos datos estructurados y gobierna la resolución.

Esta separación reduce:

- latencia;
- coste;
- discrepancias;
- ambigüedad;
- dependencia innecesaria del proveedor.

---

# 12. Datos estructurados frente a representación

La comunicación interna debe favorecer datos estructurados frente al uso de texto libre como protocolo entre capas.

Una pregunta puede contener conceptualmente:

- identificador;
- turno;
- dificultad;
- área;
- grupo;
- referente;
- conocimiento evaluado;
- enunciado;
- opciones;
- opción correcta;
- explicación.

La UI no debe analizar Markdown generado por IA para descubrir cuál es la opción B o cuál es la respuesta correcta.

B conserva significado estructurado.

C decide cómo representarlo.

---

# 13. Modalidades

Quiz10 puede admitir distintas modalidades de pregunta o presentación.

Por ejemplo:

- preguntas textuales;
- preguntas con imagen;
- modalidades futuras.

Una diferencia de representación no implica automáticamente un motor de juego distinto.

Una modalidad solo debe convertirse en un sistema independiente cuando posea reglas esenciales diferentes y no únicamente una presentación distinta.

La arquitectura debe evitar duplicar el motor de partida por razones puramente visuales.

---

# 14. Flujo arquitectónico principal

El flujo conceptual de una partida es:

1. C recibe del concursante el tema.
2. C comunica la intervención.
3. B crea una nueva sesión.
4. B solicita mediante contratos de A las capacidades técnicas necesarias.
5. A ejecuta las integraciones correspondientes.
6. B construye o valida la Ruta de Cobertura.
7. B prepara el turno actual.
8. C representa la pregunta.
9. El concursante realiza una intervención.
10. C comunica la intervención.
11. B determina su significado.
12. B resuelve el turno.
13. B actualiza el estado.
14. C representa el nuevo estado.
15. Si quedan turnos, el ciclo continúa.
16. Después del turno 10 resuelto, B finaliza la partida.
17. C representa el resultado final.

Conceptualmente:

**C comunica → B decide → A proporciona capacidades → B actualiza → C representa**

A nunca adquiere conocimiento específico del juego por participar en este flujo.

---

# 15. Invariantes arquitectónicas

1. `core/` no contiene reglas específicas de Quiz10.

2. `systems/` contiene la lógica específica del producto.

3. `systems/` no depende de componentes visuales concretos.

4. `systems/` no utiliza directamente SDKs concretos de proveedores externos cuando exista una integración técnica que deba quedar abstraída mediante A.

5. `ui/` no contiene reglas de partida.

6. `ui/` no modifica directamente el estado del dominio.

7. `apps/` ensambla y delega; no duplica el motor.

8. El estado estructurado es la fuente de verdad de la partida.

9. El texto generado por IA no sustituye al estado interno.

10. La representación visual no sustituye al estado interno.

11. Solo existe una pregunta activa por turno en una partida estándar.

12. El sistema no simula la intervención del concursante para avanzar una partida normal.

13. Cada pregunta requiere una intervención real antes de resolver el turno.

14. Una partida estándar contiene exactamente diez turnos resueltos.

15. La Ruta de Cobertura permanece oculta al concursante salvo que una funcionalidad futura defina expresamente lo contrario.

16. Los temas son datos de ejecución.

17. Un tema nuevo no implica un sistema arquitectónico nuevo.

18. Cambiar un proveedor técnico no debe obligar a reescribir las reglas del juego.

19. Cambiar la representación visual no debe obligar a reescribir el motor de partida.

20. Una nueva modalidad visual no debe duplicar reglas existentes sin una diferencia real de comportamiento.

---

# 16. Tronco inicial del repositorio

La correspondencia conceptual inicial es:

| Directorio | Capa | Responsabilidad |
|---|---|---|
| `core/` | A | Infraestructura, contratos y servicios técnicos |
| `systems/` | B | Motor y reglas de Quiz10 |
| `ui/` | C | Materialización visible del juego |
| `apps/` | Composición | Aplicaciones ejecutables |
| `tests/` | Verificación | Pruebas transversales, arquitectura e integración |
| `tooling/` | Desarrollo | Herramientas internas del repositorio |
| `docs/` | Documentación | Arquitectura, decisiones y especificaciones |

Esta correspondencia es inicial.

Las convenciones de la tecnología elegida pueden requerir adaptar la topología física.

La responsabilidad arquitectónica no cambia por ello.

---

# 17. Dirección de dependencias

La dirección conceptual principal es:

**C → B → A**

C utiliza el comportamiento del producto.

B utiliza capacidades proporcionadas mediante contratos técnicos.

A no adquiere conocimiento de reglas específicas del juego.

Las implementaciones concretas se conectan en los puntos de composición.

La arquitectura debe favorecer dependencias dirigidas hacia contratos estables y evitar dependencias desde el dominio hacia detalles externos.

---

# 18. Criterio para introducir nuevas abstracciones

No se introduce una nueva abstracción únicamente porque pueda resultar útil en el futuro.

Una abstracción debe responder a una necesidad observable del diseño o del código.

Antes de crear un nuevo sistema, servicio, interfaz o capa, debe poder explicarse:

- qué responsabilidad posee;
- qué problema resuelve;
- qué capa tiene autoridad sobre esa responsabilidad;
- qué dependencia evita o controla;
- por qué no pertenece ya a una pieza existente.

La arquitectura debe crecer por necesidad demostrada y no por anticipación especulativa.

---

# 19. Evolución de la arquitectura

Este documento es normativo, pero no inmutable.

Una decisión arquitectónica puede cambiar cuando aparezca evidencia suficiente.

Los cambios significativos deben:

1. identificar la limitación de la arquitectura vigente;
2. explicar la nueva decisión;
3. actualizar este documento cuando corresponda;
4. registrar una ADR cuando la decisión lo justifique;
5. mantener coherencia entre documentación y repositorio.

Modificar A para incorporar una capacidad realmente general no constituye un fallo arquitectónico.

Convertir una regla específica de Quiz10 en infraestructura general sin justificación sí lo constituye.

---

# 20. Síntesis

A sostiene el producto.

B gobierna Quiz10.

C lo convierte en experiencia.

La IA puede generar contenido.

La IA puede colaborar en la planificación.

La IA puede explicar respuestas.

Pero Quiz10 conserva la autoridad sobre la partida.

La fórmula conceptual del producto es:

**Tema → Ruta de Cobertura → 10 turnos reales → Resultado**

La fórmula arquitectónica es:

**A = infraestructura**

**B = Quiz10**

**C = experiencia de concurso**

El principio final es:

> **La IA genera posibilidades; Quiz10 gobierna la partida; el concursante la hace avanzar.**

---
