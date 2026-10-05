# IA.md — Inteligencia artificial de AI-APPS

## Modelos

AI-APPS puede utilizar cualquier modelo de inteligencia artificial para cualquier tarea que lo requiera.

Un mismo modelo puede realizar distintas funciones y una tarea puede utilizar uno o varios modelos.

Los modelos no tienen responsabilidades arquitectónicas permanentes. Su selección y configuración pueden cambiar sin alterar las reglas de las aplicaciones.

## Contexto

Cada sistema mantiene la realidad, el estado y las reglas de su actividad.

La inteligencia artificial no mantiene la realidad ni la memoria de las actividades. Cualquier estado persistente pertenece al sistema responsable.

Las operaciones de IA reciben el contexto necesario para realizar su tarea, junto con las instrucciones y los requisitos del resultado esperado.

Cada aplicación determina qué información necesita proporcionar y cómo utilizar los resultados obtenidos.

La IA no sustituye al sistema en el gobierno de la actividad.

## Ejecución

La inteligencia artificial puede incorporarse en cualquier punto de una experiencia cuando resulte necesaria.

Cada tarea puede disponer de sus propios prompts, modelos y procedimientos de ejecución.

Una tarea puede resolverse mediante una o varias operaciones de IA, combinar distintos modelos o prescindir de ellos.

Los prompts y los procedimientos específicos pertenecen al componente responsable de la tarea.

El subsistema `ai/` proporciona los mecanismos técnicos de ejecución sin conocer las reglas particulares de las aplicaciones.

Los modelos, prompts y procedimientos pueden incorporarse, sustituirse, combinarse o retirarse sin imponer cambios innecesarios al funcionamiento de las actividades.

La aplicación conecta los componentes necesarios y el sistema determina cómo se incorporan los resultados a su realidad.

## Implementación

La implementación técnica compartida de inteligencia artificial se encuentra en `ai/`.

Consulta [`ai/README.md`](../ai/README.md) para su contrato, funcionamiento y límites de desarrollo.