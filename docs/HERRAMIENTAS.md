# HERRAMIENTAS.md — AI-APPS

## Herramientas vigentes

| Herramienta | Función | Ubicación |
| --- | --- | --- |
| Git automático | Sincronizar `dev` en Windows sin iniciar Muondia | `scripts/auto-sync-dev.ps1` |
| Instalar Git automático | Instalar `AI-APPS Git Sync` al iniciar Windows y retirar la tarea anterior `AI-APPS Development` | `scripts/install-git-sync.ps1` |
| Git manual | Sincronización puntual de `dev` | `scripts/sync-dev.ps1` |
| Prelanzamiento Muondia | Preparar/reutilizar AVD y backend antes de Dart-Code | `apps/muondia/prepare-debug.ps1` |
| Backend y auditorías IA | Servicio Dart privado, `adb reverse`, defines, pruebas Luna y onboarding | `apps/muondia/run.ps1` |
| Flutter | Iniciar, detener, Hot Reload y Hot Restart en VS Code | Extensión oficial Flutter/Dart y `.vscode/launch.json` |
| Android integrado | Registro de aplicaciones, Explorador de experiencias e inspector visual | `scripts/android/`, `scripts/vscode-android/` |
| EmbeDroid | Vídeo del emulador en VS Code, sin iniciar Flutter | `scripts/embedroid/` |
| Instalar extensiones | Integración del visor y del Explorador en VS Code | `scripts/install-embedroid.ps1`, `scripts/install-vscode-android.ps1` |
| Retirada de app obsoleta | Herramienta histórica eliminada del arranque normal | Historial Git |

## Contrato de arranque

1. **Windows:** `AI-APPS Git Sync` ejecuta solo `auto-sync-dev.ps1`; funciona con VS Code cerrado.
2. **VS Code:** al abrir el repositorio AI-APPS, la extensión Android solicita una única sesión Flutter mediante Dart-Code.
3. **Prelanzamiento:** `prepare-debug.ps1` arranca el AVD `AI_APPS_Dev` si hace falta; `run.ps1 -ServiceOnly` prepara la IA y los defines privados.
4. **Flutter oficial:** compila Muondia y recibe las actualizaciones locales y sincronizadas usando Hot Reload/Restart.
5. **Explorador:** previsualiza el Test de bienvenida y las otras experiencias en **la misma APK** sin iniciar otro Flutter.
6. **Cierre:** `postDebugTask` detiene el backend y el AVD reservado; ninguna tarea de Windows mantiene Flutter activo.

El prelaunch conserva la mitigación gráfica del emulador 37.2.12:
`-no-snapshot -feature -Vulkan`, documentada en
`scripts/android/diagnostico-estabilidad.md`.
No se eliminan ni recrean los datos del AVD.

## Instalación tras retirar la infraestructura anterior

Una vez actualizado `dev`, ejecutar **una vez** en PowerShell desde la raíz:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-git-sync.ps1
```

Esto detiene y desregistra la tarea `AI-APPS Development` y registra
`AI-APPS Git Sync`. Reiniciar Windows después de la transición limpia
los procesos que hubiesen sobrevivido al antiguo lanzador. La nueva tarea
no interviene en Android ni Flutter.

La extensión AI-APPS Android está enlazada con el repositorio mediante
`install-vscode-android.ps1`; hay que recargar VS Code para que lea
sus cambios. EmbeDroid instalado mediante `install-embedroid.ps1`
no se reemplaza por una sincronización de Git.

## Validaciones

`node scripts/android/test.cjs`,
`node scripts/vscode-android/test.cjs`,
`node scripts/vscode-android/explorer.test.cjs`
y las pruebas Flutter de `apps/muondia/`.

**Imprescindible en Windows:** iniciar VS Code en frío, verificar
compilación Flutter, abrir Test de bienvenida desde el Explorador,
probar edición local, aplicar una actualización de GitHub y repetir
tras reiniciar Windows. Las pruebas simuladas no sustituyen esta verificación.
