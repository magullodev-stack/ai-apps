# Visibilidad operativa compartida

La sincronización continua de `dev` incorpora un resumen seguro de la estación
de desarrollo Windows y lo publica en `diagnostics/current.json` en el
repositorio privado. Se recoge cada minuto y se actualiza cuando cambia el
contenido o, como máximo, una vez por hora para mostrar actividad. No requiere
iniciar otro servicio cuando `auto-sync-dev.ps1` ejecuta la versión nueva.

El diagnóstico incluye la existencia, tamaño, huella SHA-256 y los
identificadores de problemas legibles de los informes Gradle conocidos de
AI-APPS y Muondia; también los últimos eventos tipificados de
`.ai-apps/dev-session.log` y `.ai-apps/auto-sync-dev.log`.

**No se envían** HTML de Gradle, registros sin filtrar, trazas, rutas personales,
variables de entorno, claves o contenido de los archivos ignorados. Para los
problemas de Gradle se extraen solo `problemId.name`,
`problemId.displayName`, gravedad y número de apariciones. Algunos formatos
de informe no exponen datos estructurados interpretables. En tal caso se marca
`extraction: metadata_only`; esto **no equivale a cero problemas**.

El estado operativo compartido complementa, pero no sustituye, Git: no da
acceso remoto al disco C:, no ejecuta acciones en Windows y no replica caches
ni procesos. Un `checkedUtcHour` antiguo indica que no se ha publicado un
nuevo diagnóstico; puede deberse a que se ha detenido el equipo, el sincronizador
o la red. El log local es la fuente para resolver esa distinción.

## Validación

```powershell
.\scripts\diagnostics\test.ps1
```

El colector `collect.cjs` funciona con Node o con el motor Node incluido en
VS Code. No necesita acceso a Internet y no modifica Gradle ni Flutter.
