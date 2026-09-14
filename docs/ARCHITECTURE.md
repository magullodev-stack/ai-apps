# Arquitectura de Quiz10

## Estructura

Quiz10 se divide conceptualmente en:

- `A/core/` — A: infraestructura, contratos y capacidades técnicas.
- `B/systems/` — B: lógica y reglas del producto.
- `C/ui/` — C: representación e interacción.
- `apps/` — composición ejecutable.

Dirección conceptual:

`C → B → A`

`apps/` conecta las implementaciones concretas.

## A — `A/core/`

Proporciona capacidades técnicas reutilizables.

Puede incluir:

- configuración;
- red;
- IA;
- persistencia;
- seguridad;
- autenticación;
- localización;
- telemetría.

A no conoce reglas específicas de Quiz10.

## B — `B/systems/`

Contiene la lógica del producto.

`B/systems/quiz10/` gobierna la partida, los turnos, la Ruta de Cobertura, preguntas, respuestas, resolución, progreso y resultado.

B no depende de una UI concreta ni de implementaciones concretas de servicios externos.

## C — `C/ui/`

Representa el estado y recibe las intervenciones del usuario.

C no decide reglas de juego ni modifica directamente el estado del dominio.

## Composición — `apps/`

Contiene los ejecutables.

Inicialmente:

- `apps/mobile/`
- `apps/server/`

Su responsabilidad es configurar, conectar y arrancar componentes.

No contiene una segunda implementación de las reglas del producto.

## Estado

El estado estructurado del sistema es la fuente de verdad.

Ni la UI ni el texto generado por IA sustituyen ese estado.

Cuando una respuesta cerrada A/B/C/D ya tiene una opción correcta conocida, su resolución es determinista.

## Reglas de dependencia

- `A/core/` no depende de Quiz10.
- `B/systems/` no depende de Compose ni de SDKs concretos externos.
- `C/ui/` no contiene reglas de dominio.
- `apps/` ensambla y delega.
- Los temas son datos de ejecución, no nuevos sistemas.

## Evolución

No se crean nuevas capas, servicios, abstracciones o carpetas por anticipación.

Cada pieza debe responder a una necesidad real del producto o de la infraestructura.