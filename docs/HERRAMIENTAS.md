# HERRAMIENTAS.md — AI-APPS

## Catálogo

| Herramienta | Finalidad | Ubicación | Estado |
| --- | --- | --- | --- |
| MONIT-AI | Observación, consumo, costes y auditorías de las ejecuciones de IA. | `tools/monit-ai/` | Código conservado. Pendiente de adaptación y reintegración en la compilación activa. |

## Mantenimiento

Las herramientas se incorporan a la compilación activa cuando su implementación y sus pruebas están integradas.

Las instrucciones técnicas de cada herramienta se mantienen en su documentación específica.

## Confirmar y publicar cambios desde VS Code en Windows

Abre el terminal integrado en la raíz del repositorio y comprueba que su prompt corresponde a PowerShell. Git de Windows y Git de WSL mantienen configuraciones de usuario distintas. Antes del primer commit con Git de Windows, configura una vez tu identidad con el nombre y el correo que usas para tus commits:

```powershell
git config --global user.name "Tu nombre de autor"
git config --global user.email "tu-correo-de-commits@example.com"
```

Sustituye ambos valores por los tuyos. La identidad del autor de un commit no es la autenticación usada para enviar cambios a GitHub.

Para publicar cambios en `dev`, revisa primero los archivos que se van a incluir y ejecuta:

```powershell
git status --short --branch
git add -A
git diff --cached --check
git commit -m "chore: actualizar AI-APPS"
git push origin dev
```

`git add -A` incluye cambios en archivos ya seguidos por Git. El repositorio ignora `.vscode/`; si necesitas publicar un archivo **nuevo** de esa carpeta, añádelo expresamente antes del commit, por ejemplo `git add -f .vscode/launch.json`. Si no hay cambios preparados, `git commit` indicará que no hay nada que confirmar. Si falla algún paso, consulta su mensaje antes de continuar.
