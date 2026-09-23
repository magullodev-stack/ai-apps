# IA.md — Inteligencia artificial de AI-APPS

## Modelos

AI-APPS puede utilizar cualquier modelo de inteligencia artificial para cualquier tarea que lo requiera.

Un mismo modelo puede realizar distintas funciones y una tarea puede utilizar uno o varios modelos.

Los modelos no tienen responsabilidades arquitectónicas permanentes. Su selección y configuración pueden cambiar sin alterar las reglas de las aplicaciones.

## Contexto

Cada sistema mantiene la realidad, el estado y las reglas de su actividad.

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

## Implementación recuperada

`ai/` contiene el cliente JVM de OpenAI Responses, su transporte, la configuración y el registro técnico de consumo. Cada solicitud puede seleccionar su modelo; los antiguos perfiles LUNA, MINI y TERRA se conservan únicamente como compatibilidad. El alcance actual del cliente es la generación JSON estructurada.

`ai/flutter_client` permite a los juegos móviles solicitar generaciones a un servidor AI-APPS. El puente local `AiHttpServer` sirve para desarrollo; la clave de OpenAI permanece en el proceso servidor. Consulta [`ai/README.md`](../ai/README.md) para los pasos de ejecución y sus límites.
