#!/usr/bin/env bash
set -Eeuo pipefail

cd /workspaces/ai-apps/apps/quiz10
unset ADB_SERVER_SOCKET

# Impedir dos ejecuciones simultáneas de esta tarea.
exec 9>/tmp/ai-apps-quiz10.lock
if ! flock -n 9; then
    echo "Quiz10 ya tiene una tarea de arranque activa."
    exit 0
fi

adb start-server >/dev/null
echo "Esperando a que Android esté preparado..."

for ((i=0; i<150; i++)); do
    adb connect host.docker.internal:5556 >/dev/null 2>&1 || true

    if [[ "$(adb -s host.docker.internal:5556 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then
        echo "Android preparado. Iniciando Quiz10..."
        exec flutter run -d host.docker.internal:5556 --disable-dds
    fi

    sleep 2
done

echo "ERROR: Android no está disponible."
exit 1
