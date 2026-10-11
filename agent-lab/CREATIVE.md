# Creatividad autónoma

El laboratorio creativo ahora ejecuta **un agente Codex** sobre un único proyecto
Flutter aislado. No hay roles Chispa/Caos/Materia ni un orden fijo de intervención.

La entrada es la imagen original (PNG) y el texto original (Markdown), por separado.
Cada iteración vuelve al **mismo código**, reconoce lo implementado y decide qué
construir a continuación. El agente puede añadir archivos, distribuir el código,
cambiar pubspec.yaml e incorporar paquetes externos. En modo creativo se habilita
red dentro del sandbox de Codex para permitir dependencias; el anfitrión hace
flutter pub get cuando corresponde, fuera del sandbox, y solo valida código modificado.

Android se abre al terminar el bloque de ciclos si se solicitó. No es utilizado como
fuente de la imagen original. Dos ciclos consecutivos sin cambios detienen la sesión
para no seguir consumiendo recursos sin avances. Se puede continuar más tarde.

Uso:

    .\agent-lab\creative.ps1 -SeedZip .\agent-lab\seeds\spinai_semilla.zip -Flutter -Build -Android -Rounds 12
    .\agent-lab\creative.ps1 -Latest -Build -Android -Rounds 12
    .\agent-lab\creative.ps1 -Latest -Discard

El ZIP debe contener solamente imagen.png y texto.md. Los códigos de experimentos
antiguos permanecen en sus salas independientes, pero no se introducen en la
nueva ejecución.

El sandbox protege el repositorio AI-APPS, QuizAI y las credenciales externas.
Se utiliza el ejecutor Codex ya instalado; este modo no requiere el servicio
Dart de IA ni la cadena ChatDev anterior.
