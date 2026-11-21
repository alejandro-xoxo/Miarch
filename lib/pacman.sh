#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Miarch · gestión y espera de bloqueos de pacman (db.lck).
# Evita fallos confusos si pacman o yay están bloqueados por otra terminal o por un bloqueo huérfano.

pacman_lck_path() {
    printf '%s\n' "${MIARCH_PACMAN_LCK:-/var/lib/pacman/db.lck}"
}

# Comprueba si un PID desciende de la propia ejecución actual ($$)
pacman_es_hijo() {
    [ -n "${MIARCH_PACMAN_NO_FILTRAR_HIJOS:-}" ] && return 1
    local p="$1" yo="$$"
    while [ -n "$p" ] && [ "$p" -gt 1 ] 2>/dev/null; do
        [ "$p" -eq "$yo" ] && return 0
        p="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
    done
    return 1
}

# Comprueba si un PID es de checkupdates (o invocado por checkupdates)
pacman_es_checkupdates() {
    local p="$1" cmd ppid pcmd
    cmd="$(ps -o args= -p "$p" 2>/dev/null || true)"
    [[ "$cmd" == *"checkupdates"* ]] && return 0
    ppid="$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')"
    if [ -n "$ppid" ] && [ "$ppid" -gt 1 ] 2>/dev/null; then
        pcmd="$(ps -o args= -p "$ppid" 2>/dev/null || true)"
        [[ "$pcmd" == *"checkupdates"* ]] && return 0
    fi
    return 1
}

# Devuelve los PIDs de procesos pacman/yay/paru/pamac activos que bloquean pacman
pacman_procesos_bloqueando() {
    local pids=() p
    if [ "${MIARCH_PACMAN_PIDS+x}" = "x" ]; then
        read -r -a pids <<< "$MIARCH_PACMAN_PIDS"
    else
        mapfile -t pids < <(pgrep -x 'pacman|yay|paru|pamac' 2>/dev/null || true)
    fi
    for p in "${pids[@]}"; do
        [ -n "$p" ] || continue
        kill -0 "$p" 2>/dev/null || continue
        pacman_es_hijo "$p" && continue
        pacman_es_checkupdates "$p" && continue
        echo "$p"
    done
}

# Convierte el formato etime de ps ([[DD-]hh:]mm:ss) a texto en español y segundos
pacman_formatear_etime() {
    local raw="$1" dias=0 horas=0 mins=0 segs=0
    if [[ "$raw" =~ ^([0-9]+)-([0-9]+):([0-9]+):([0-9]+)$ ]]; then
        dias="${BASH_REMATCH[1]}"; horas="${BASH_REMATCH[2]}"; mins="${BASH_REMATCH[3]}"; segs="${BASH_REMATCH[4]}"
    elif [[ "$raw" =~ ^([0-9]+):([0-9]+):([0-9]+)$ ]]; then
        horas="${BASH_REMATCH[1]}"; mins="${BASH_REMATCH[2]}"; segs="${BASH_REMATCH[3]}"
    elif [[ "$raw" =~ ^([0-9]+):([0-9]+)$ ]]; then
        mins="${BASH_REMATCH[1]}"; segs="${BASH_REMATCH[2]}"
    fi
    dias=$(( 10#$dias )); horas=$(( 10#$horas )); mins=$(( 10#$mins )); segs=$(( 10#$segs ))
    local total_seg=$(( dias * 86400 + horas * 3600 + mins * 60 + segs ))
    local txt=""
    if [ "$dias" -gt 0 ]; then
        txt="${dias} d ${horas} h"
    elif [ "$horas" -gt 0 ]; then
        txt="${horas} h ${mins} min"
    elif [ "$mins" -gt 0 ]; then
        [ "$segs" -gt 0 ] && txt="${mins} min ${segs} s" || txt="${mins} min"
    else
        txt="${segs} s"
    fi
    printf '%s|%d\n' "$txt" "$total_seg"
}

# Obtiene datos del proceso: tiempo_texto|comando|terminal|segundos
pacman_datos_proceso() {
    local pid="$1" raw tty etime args info_t txt segs desc
    raw="$(ps -o tty=,etime=,args= -p "$pid" 2>/dev/null || true)"
    tty="$(echo "$raw" | awk '{print $1}')"
    etime="$(echo "$raw" | awk '{print $2}')"
    args="$(echo "$raw" | awk '{$1=""; $2=""; sub(/^  */, ""); print}')"
    [ -n "$tty" ] || tty="?"
    [ "$tty" != "?" ] && tty="terminal $tty" || tty="sin terminal"
    info_t="$(pacman_formatear_etime "$etime")"
    txt="${info_t%|*}"
    segs="${info_t#*|}"
    desc="$args"
    [ ${#desc} -gt 55 ] && desc="${desc:0:52}..."
    printf '%s|%s|%s|%s\n' "$txt" "$desc" "$tty" "$segs"
}

# Mensaje descriptivo para cuando pacman sigue bloqueado
pacman_mensaje_bloqueo() {
    local pid="$1" datos txt desc tty segs
    datos="$(pacman_datos_proceso "$pid")"
    IFS='|' read -r txt desc tty segs <<< "$datos"
    printf 'Hay una instalación abierta desde hace %s (%s, %s). Respóndele o ciérrala (Ctrl+C) y vuelve a pulsar la nube.\n' "$txt" "$desc" "$tty"
}

# Revisión en Fase 1 (no cambia nada): si hay proceso vivo de más de 5 min (300 s), avisa
revisar_bloqueo_pacman() {
    local lck procs=() datos txt desc tty segs
    lck="$(pacman_lck_path)"
    [ -e "$lck" ] || return 0
    mapfile -t procs < <(pacman_procesos_bloqueando)
    [ "${#procs[@]}" -gt 0 ] || return 0
    datos="$(pacman_datos_proceso "${procs[0]}")"
    IFS='|' read -r txt desc tty segs <<< "$datos"
    if [ "${segs:-0}" -ge 300 ]; then
        if declare -F ui_aviso >/dev/null; then
            ui_aviso "Hay una instalación abierta desde hace $txt ($desc, $tty): ciérrala antes de actualizar"
        else
            printf '  [!] Hay una instalación abierta desde hace %s (%s, %s): ciérrala antes de actualizar\n' "$txt" "$desc" "$tty"
        fi
        return 1
    fi
    return 0
}

# Espera reutilizable antes de operaciones que modifiquen paquetes
esperar_pacman() {
    local lck max reintento procs=() transcurrido=0 es_tty=0
    lck="$(pacman_lck_path)"
    [ -e "$lck" ] || return 0

    max="${MIARCH_ESPERA_PACMAN:-90}"
    reintento="${MIARCH_ESPERA_PACMAN_REINTENTO:-2}"
    [ -t 1 ] && es_tty=1
    [ "${UI_TTY:-0}" = 1 ] && es_tty=1

    mapfile -t procs < <(pacman_procesos_bloqueando)

    # Caso huérfano inicial: bloqueo sin proceso vivo
    if [ "${#procs[@]}" -eq 0 ]; then
        sleep "$reintento"
        mapfile -t procs < <(pacman_procesos_bloqueando)
        if [ -e "$lck" ] && [ "${#procs[@]}" -eq 0 ]; then
            sudo rm -f "$lck"
            if declare -F ui_aviso >/dev/null; then
                ui_aviso "Se eliminó el bloqueo huérfano de pacman ($lck)"
            else
                printf '  [!] Se eliminó el bloqueo huérfano de pacman (%s)\n' "$lck"
            fi
            return 0
        fi
    fi

    [ -e "$lck" ] || return 0

    # Caso proceso vivo: esperar hasta max segundos con indicador
    while [ "$transcurrido" -lt "$max" ]; do
        [ -e "$lck" ] || { [ "$es_tty" -eq 1 ] && printf '\r\033[K'; return 0; }
        mapfile -t procs < <(pacman_procesos_bloqueando)
        if [ "${#procs[@]}" -eq 0 ]; then
            sleep "$reintento"
            mapfile -t procs < <(pacman_procesos_bloqueando)
            if [ -e "$lck" ] && [ "${#procs[@]}" -eq 0 ]; then
                [ "$es_tty" -eq 1 ] && printf '\r\033[K'
                sudo rm -f "$lck"
                if declare -F ui_aviso >/dev/null; then
                    ui_aviso "Se eliminó el bloqueo huérfano de pacman ($lck)"
                else
                    printf '  [!] Se eliminó el bloqueo huérfano de pacman (%s)\n' "$lck"
                fi
                return 0
            fi
        fi

        if [ "$es_tty" -eq 1 ]; then
            printf '\r\033[K  %s Esperando a que termine pacman/yay (%ds/%ds)...' "${S_INFO:-[i]}" "$transcurrido" "$max"
        fi
        sleep 1
        transcurrido=$(( transcurrido + 1 ))
    done
    [ "$es_tty" -eq 1 ] && printf '\r\033[K'

    # Tras agotar la espera
    if [ -e "$lck" ]; then
        mapfile -t procs < <(pacman_procesos_bloqueando)
        if [ "${#procs[@]}" -gt 0 ]; then
            local msg
            msg="$(pacman_mensaje_bloqueo "${procs[0]}")"
            if declare -F ui_aviso >/dev/null; then
                ui_aviso "$msg"
            else
                printf '  [!] %s\n' "$msg"
            fi
            return 1
        else
            sudo rm -f "$lck"
            if declare -F ui_aviso >/dev/null; then
                ui_aviso "Se eliminó el bloqueo huérfano de pacman ($lck)"
            else
                printf '  [!] Se eliminó el bloqueo huérfano de pacman (%s)\n' "$lck"
            fi
            return 0
        fi
    fi
    return 0
}
