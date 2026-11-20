#!/usr/bin/env bash
# Miarch · interfaz de los scripts de instalación: barra del avance total y una animación mientras trabaja un comando.
# Solo usa ASCII (funciona en la consola de texto de una instalación mínima, sin fuentes de íconos ni emojis).
# Uso (con "source"):
#   ui_total 12                       fija cuántas etapas tiene este script
#   ui_etapa "Instalando paquetes"    avanza una etapa y dibuja la barra
#   ui_ejecutar "Mensaje" cmd args    ejecuta cmd con una animación; guarda su salida en el registro
# Si el script lo lanza setup.sh, la barra continúa la de setup.sh (MIARCH_UI_TOTAL / MIARCH_UI_ACTUAL).

UI_LOG="${MIARCH_LOG:-$HOME/.cache/miarch/instalacion.log}"
mkdir -p "$(dirname "$UI_LOG")" 2>/dev/null || true
UI_TOTAL="${MIARCH_UI_TOTAL:-1}"
UI_ACTUAL="${MIARCH_UI_ACTUAL:-0}"
UI_TTY=0; [ -t 1 ] && UI_TTY=1

ui_total() { [ -n "${MIARCH_UI_TOTAL:-}" ] || UI_TOTAL="$1"; }

ui_columnas() { local c; c="$(tput cols 2>/dev/null || echo 80)"; [ "${c:-80}" -ge 40 ] 2>/dev/null && echo "$c" || echo 80; }

ui_barra() {   # $1 = actual  $2 = total  →  [#########-----------]  45%
    local a="$1" t="$2" ancho=30 lleno pct i b=""
    [ "$t" -gt 0 ] || t=1
    [ "$a" -gt "$t" ] && a="$t"
    lleno=$(( a * ancho / t )); pct=$(( a * 100 / t ))
    for ((i = 0; i < ancho; i++)); do [ "$i" -lt "$lleno" ] && b+="#" || b+="-"; done
    printf '[%s] %3d%%' "$b" "$pct"
}

ui_etapa() {
    UI_ACTUAL=$(( UI_ACTUAL + 1 ))
    printf '\n%s  (%d/%d)\n==> %s\n' "$(ui_barra "$UI_ACTUAL" "$UI_TOTAL")" "$UI_ACTUAL" "$UI_TOTAL" "$*"
}

# ui_ejecutar "Mensaje" comando args...  → devuelve el código de salida del comando
ui_ejecutar() {
    local msg="$1"; shift
    local inicio rc=0 pid i=0 marcas='|/-\' ultima ancho linea desde
    inicio=$(date +%s)
    printf '\n=== %s | %s\n' "$(date '+%F %T')" "$msg" >> "$UI_LOG"
    desde="$(wc -c < "$UI_LOG")"
    if [ "$UI_TTY" = 0 ]; then                       # sin terminal (registros, pruebas): sin animación
        echo "   ... $msg"
        "$@" >> "$UI_LOG" 2>&1 < /dev/null && rc=0 || rc=$?
    else
        "$@" >> "$UI_LOG" 2>&1 < /dev/null &
        pid=$!
        ancho="$(ui_columnas)"
        while kill -0 "$pid" 2>/dev/null; do
            ultima="$(tail -c 400 "$UI_LOG" 2>/dev/null | tr '\r' '\n' | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' | grep -v '^[[:space:]]*$' | tail -n 1)"
            linea="$(printf '   %s %s (%ds)  %s' "${marcas:i%4:1}" "$msg" "$(( $(date +%s) - inicio ))" "$ultima")"
            printf '\r\033[K%s' "${linea:0:ancho-1}"
            i=$(( i + 1 )); sleep 0.15
        done
        wait "$pid" && rc=0 || rc=$?
        printf '\r\033[K'
    fi
    if [ "$rc" -eq 0 ]; then
        echo "   [OK] $msg ($(( $(date +%s) - inicio ))s)"
    else
        echo "   [ERROR] $msg (código $rc). Últimas líneas:"
        tail -c +"$(( desde + 1 ))" "$UI_LOG" | tr '\r' '\n' | grep -v '^[[:space:]]*$' | tail -n 8 | sed 's/^/       /'
        echo "       Registro completo: $UI_LOG"
    fi
    return "$rc"
}

# ui_sudo: pide la contraseña UNA vez y la mantiene viva mientras dura el script (las animaciones ocultan
# cualquier aviso de sudo, así que hay que tenerla antes). Si setup.sh ya lo hizo, no repite.
UI_KEEPALIVE=""
ui_sudo() {
    sudo -v || { echo "[ERROR] No se pudo obtener permiso de administrador (sudo)."; exit 1; }
    if [ -z "${MIARCH_SUDO_VIVO:-}" ]; then
        ( while true; do sudo -n true; sleep 45; kill -0 "$$" 2>/dev/null || exit; done ) &
        UI_KEEPALIVE=$!
        trap '[ -z "$UI_KEEPALIVE" ] || kill "$UI_KEEPALIVE" 2>/dev/null || true' EXIT
    fi
}
