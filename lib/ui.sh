#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Miarch · interfaz de los scripts: logo, barra del avance total, animación por comando, resumen final.
# Se adapta a donde corre:
#   nivel 2  terminal moderna (kitty, ssh...) con UTF-8: símbolos, indicador braille, color verdadero
#   nivel 1  consola de texto (tty) con UTF-8: recuadros y bloques seguros, indicador ASCII, 16 colores
#   nivel 0  sin UTF-8: solo ASCII
# Uso (con "source"):
#   ui_banner [subtítulo]            logo animado
#   ui_total N / ui_etapa "Texto"    barra del total y título de cada etapa
#   ui_ejecutar "Mensaje" cmd ...    ejecuta con animación; la salida va al registro
#   ui_ok / ui_info / ui_aviso / ui_error "Texto"
#   ui_resumen "Título"              recuadro final con tiempo, errores y avisos
# Si setup.sh lanza otro script, éste continúa la misma barra (MIARCH_UI_TOTAL / MIARCH_UI_ACTUAL).

UI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_LOG="${MIARCH_LOG:-$HOME/.cache/miarch/instalacion.log}"
UI_STATS="${MIARCH_STATS:-$HOME/.cache/miarch/instalacion.stats}"
mkdir -p "$(dirname "$UI_LOG")" 2>/dev/null || true
UI_TOTAL="${MIARCH_UI_TOTAL:-1}"
UI_ACTUAL="${MIARCH_UI_ACTUAL:-0}"
UI_PRIMERO=0; [ -n "${MIARCH_UI_INICIO:-}" ] || UI_PRIMERO=1       # el primer script de la cadena empieza de cero
UI_INICIO="${MIARCH_UI_INICIO:-$(date +%s)}"
export MIARCH_STATS="$UI_STATS" MIARCH_UI_INICIO="$UI_INICIO"
UI_TTY=0; [ -t 1 ] && UI_TTY=1
UI_PCT_ANT=0
[ "$UI_PRIMERO" = 0 ] || : > "$UI_STATS" 2>/dev/null || true

# ---- nivel de detalle gráfico ----
if [ -n "${MIARCH_UI_NIVEL:-}" ]; then UI_NIVEL="$MIARCH_UI_NIVEL"
elif ! locale charmap 2>/dev/null | grep -qi 'utf-\?8'; then UI_NIVEL=0
elif [ "${TERM:-}" = "linux" ]; then UI_NIVEL=1
else UI_NIVEL=2; fi

# ---- colores: la paleta del portafolio de alejandro-xoxo (morado, lavanda y pasteles sobre azul marino) ----
#   acento #6f65d6 · lavanda #C4B5FD · correcto menta #A7F3D0 · aviso rosa #FBCFE8 · error rosa fuerte · texto tenue #8892A6
C_ACENTO=""; C_LAVANDA=""; C_OK=""; C_ERR=""; C_AVISO=""; C_TENUE=""; C_NEG=""; C_R=""
if [ "$UI_TTY" = 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
    C_R=$'\033[0m'; C_NEG=$'\033[1m'
    case "${COLORTERM:-}:${TERM:-}" in
        truecolor:*|24bit:*|*:*-direct)
            C_ACENTO=$'\033[38;2;111;101;214m'; C_LAVANDA=$'\033[38;2;196;181;253m'; C_OK=$'\033[38;2;167;243;208m'
            C_ERR=$'\033[38;2;232;128;159m'; C_AVISO=$'\033[38;2;251;207;232m'; C_TENUE=$'\033[38;2;136;146;166m'
            UI_DEGRADE=(55,48,165 76,70,182 111,101,214 143,130,232 171,157,244 196,181,253) ;;
        *:*256color*)
            C_ACENTO=$'\033[38;5;98m'; C_LAVANDA=$'\033[38;5;183m'; C_OK=$'\033[38;5;122m'
            C_ERR=$'\033[38;5;174m'; C_AVISO=$'\033[38;5;218m'; C_TENUE=$'\033[38;5;103m'
            UI_DEGRADE=(54 61 98 98 141 183) ;;
        *)
            C_ACENTO=$'\033[35m'; C_LAVANDA=$'\033[1;35m'; C_OK=$'\033[32m'
            C_ERR=$'\033[31m'; C_AVISO=$'\033[33m'; C_TENUE=$'\033[2m'
            UI_DEGRADE=(35 35 35 35 35 35) ;;
    esac
fi

# ---- símbolos según el nivel ----
case "$UI_NIVEL" in
    2) S_OK="✔"; S_ERR="✘"; S_AVISO="▲"; S_INFO="●"; S_ETAPA="▸"; S_LLENO="█"; S_VACIO="░"; UI_GIRO=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
       B_TL="┌"; B_TR="┐"; B_BL="└"; B_BR="┘"; B_H="─"; B_V="│" ;;
    1) S_OK="[OK]"; S_ERR="[ERROR]"; S_AVISO="[!]"; S_INFO="[i]"; S_ETAPA=">>"; S_LLENO="█"; S_VACIO="░"; UI_GIRO=('|' '/' '-' '\')
       B_TL="┌"; B_TR="┐"; B_BL="└"; B_BR="┘"; B_H="─"; B_V="│" ;;
    *) S_OK="[OK]"; S_ERR="[ERROR]"; S_AVISO="[!]"; S_INFO="[i]"; S_ETAPA="=>"; S_LLENO="#"; S_VACIO="-"; UI_GIRO=('|' '/' '-' '\')
       B_TL="+"; B_TR="+"; B_BL="+"; B_BR="+"; B_H="-"; B_V="|" ;;
esac

ui_total() { [ -n "${MIARCH_UI_TOTAL:-}" ] || UI_TOTAL="$1"; }
# Ancho REAL de la terminal. "tput cols" dentro de $( ) no ve la ventana (su salida es una tubería) y devuelve 80: la línea
# animada se pasaba del borde, se partía en varias y cada cuadro añadía una línea nueva en lugar de reemplazar la anterior.
ui_columnas() {
    local c=""
    [ -r /dev/tty ] && c="$(stty size </dev/tty 2>/dev/null | cut -d' ' -f2)"
    [[ "$c" =~ ^[0-9]+$ ]] || c="${COLUMNS:-}"
    [[ "$c" =~ ^[0-9]+$ ]] || c="$(tput cols 2>/dev/null || echo 80)"
    [ "${c:-0}" -ge 20 ] 2>/dev/null && echo "$c" || echo 80
}
# ancho útil: deja 2 columnas de margen (los caracteres anchos o un borde exacto harían que la línea se parta)
ui_ancho() { local c; c="$(ui_columnas)"; c=$(( c - 2 )); [ "$c" -gt 78 ] && c=78; [ "$c" -lt 18 ] && c=18; echo "$c"; }
ui_registrar() { echo "$1" >> "$UI_STATS" 2>/dev/null || true; }
ui_recortar() { local t="$1" max="$2"; [ "$max" -lt 4 ] && max=4; if [ "${#t}" -gt "$max" ]; then printf '%s…' "${t:0:$(( max - 1 ))}"; else printf '%s' "$t"; fi; }
ui_repetir() { local n="$1" c="$2" s="" i; for ((i = 0; i < n; i++)); do s+="$c"; done; printf '%s' "$s"; }
ui_tiempo() { local s="$1"; if [ "$s" -ge 60 ]; then printf '%dm %02ds' $((s / 60)) $((s % 60)); else printf '%ds' "$s"; fi; }

# ---- logo animado ----
ui_banner() {
    local sub="${1:-}" ver="" i
    ver="$(git -C "$UI_DIR/.." describe --tags --always 2>/dev/null || true)"
    if [ "$UI_TTY" = 0 ]; then echo "== Miarch ${ver} ${sub} (github.com/alejandro-xoxo/Miarch) =="; return; fi
    local logo=()
    if [ "$UI_NIVEL" -ge 1 ]; then
        logo=("███╗   ███╗██╗ █████╗ ██████╗  ██████╗██╗  ██╗"
              "████╗ ████║██║██╔══██╗██╔══██╗██╔════╝██║  ██║"
              "██╔████╔██║██║███████║██████╔╝██║     ███████║"
              "██║╚██╔╝██║██║██╔══██║██╔══██╗██║     ██╔══██║"
              "██║ ╚═╝ ██║██║██║  ██║██║  ██║╚██████╗██║  ██║"
              "╚═╝     ╚═╝╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝")
    else
        logo=("M   M  III   AAA   RRRR    CCC  H   H"
              "MM MM   I   A   A  R   R  C     H   H"
              "M M M   I   AAAAA  RRRR   C     HHHHH"
              "M   M   I   A   A  R  R   C     H   H"
              "M   M  III  A   A  R   R   CCC  H   H")
    fi
    echo
    for i in "${!logo[@]}"; do
        local col="${UI_DEGRADE[$i]:-}" esc=""
        if [ -n "$C_ACENTO" ]; then
            case "${COLORTERM:-}" in
                truecolor|24bit) esc=$'\033[38;2;'"${col//,/;}"'m' ;;
                *) case "${TERM:-}" in *256color*) esc=$'\033[38;5;'"$col"'m' ;; *) esc=$'\033[35m' ;; esac ;;
            esac
        fi
        printf '  %s%s%s\n' "$esc" "${logo[$i]}" "$C_R"
        sleep 0.06
    done
    printf '\n  %s%s%s\n' "$C_TENUE" "Arch Linux + Hyprland   ·   ${ver:-instalador}${sub:+   ·   $sub}" "$C_R"
    printf '  %s%salejandro-xoxo / Miarch%s   %sgithub.com/alejandro-xoxo/Miarch%s\n\n' "$C_LAVANDA" "$C_NEG" "$C_R" "$C_TENUE" "$C_R"
}

# ---- barra del total ----
ui_barra() {   # $1 = porcentaje
    local pct="$1" ancho=36 lleno
    lleno=$(( pct * ancho / 100 ))
    printf '%s%s%s%s%s' "$C_ACENTO" "$(ui_repetir "$lleno" "$S_LLENO")" "$C_TENUE" "$(ui_repetir $(( ancho - lleno )) "$S_VACIO")" "$C_R"
}
# título de una sección que no cuenta como etapa (por ejemplo, la revisión previa)
ui_titulo() {
    if [ "$UI_TTY" = 0 ]; then printf '\n==> %s\n' "$*"; return; fi
    printf '\n  %s%s%s %s%s%s\n' "$C_ACENTO" "$S_ETAPA" "$C_R" "$C_NEG" "$*" "$C_R"
}
ui_etapa() {
    local msg="$*" pct paso
    # modo compacto: un script lanzado por miarch-update no dibuja su propia barra (ya hay una del actualizador)
    if [ -n "${MIARCH_UI_COMPACTO:-}" ]; then printf '\n  %s· %s%s\n' "$C_TENUE" "$msg" "$C_R"; return; fi
    UI_ACTUAL=$(( UI_ACTUAL + 1 ))
    [ "$UI_TOTAL" -gt 0 ] || UI_TOTAL=1
    pct=$(( UI_ACTUAL * 100 / UI_TOTAL )); [ "$pct" -gt 100 ] && pct=100
    if [ "$UI_TTY" = 0 ]; then
        printf '\n[%s] %3d%%  (%d/%d)\n==> %s\n' "$(ui_repetir $((pct * 30 / 100)) '#')$(ui_repetir $((30 - pct * 30 / 100)) '-')" "$pct" "$UI_ACTUAL" "$UI_TOTAL" "$msg"
        return
    fi
    printf '\n  %s%s%s %s%d/%d%s  %s%s%s\n' "$C_ACENTO" "$S_ETAPA" "$C_R" "$C_NEG" "$UI_ACTUAL" "$UI_TOTAL" "$C_R" "$C_NEG" "$msg" "$C_R"
    # la barra se llena de forma suave desde el valor anterior
    for paso in 1 2 3 4 5 6; do
        printf '\r  %s  %3d%%' "$(ui_barra $(( UI_PCT_ANT + (pct - UI_PCT_ANT) * paso / 6 )))" $(( UI_PCT_ANT + (pct - UI_PCT_ANT) * paso / 6 ))
        sleep 0.025
    done
    printf '\n'
    UI_PCT_ANT="$pct"
}

# ---- líneas de estado ----
ui_ok()    { printf '  %s%s%s %s\n' "$C_OK" "$S_OK" "$C_R" "$*"; }
ui_info()  { printf '  %s%s%s %s%s%s\n' "$C_TENUE" "$S_INFO" "$C_R" "$C_TENUE" "$*" "$C_R"; }
ui_aviso() { ui_registrar aviso; printf '  %s%s%s %s\n' "$C_AVISO" "$S_AVISO" "$C_R" "$*"; }
ui_error() { ui_registrar fallo; printf '  %s%s%s %s\n' "$C_ERR" "$S_ERR" "$C_R" "$*" >&2; }

# ui_ejecutar "Mensaje" comando args...  → devuelve el código de salida del comando
ui_ejecutar() {
    local msg="$1"; shift
    local inicio rc=0 pid i=0 ultima ancho disp seg desde puntos t tmp fijo vmsg libre
    inicio=$(date +%s)
    printf '\n=== %s | %s\n' "$(date '+%F %T')" "$msg" >> "$UI_LOG"
    desde="$(wc -c < "$UI_LOG")"
    if [ "$UI_TTY" = 0 ]; then                       # sin terminal (registros, pruebas): sin animación
        echo "   ... $msg"
        "$@" >> "$UI_LOG" 2>&1 < /dev/null && rc=0 || rc=$?
    else
        "$@" >> "$UI_LOG" 2>&1 < /dev/null &
        pid=$!
        ancho="$(ui_ancho)"
        trap 'ancho="$(ui_ancho)"' WINCH        # si cambias el tamaño de la ventana, se vuelve a medir al instante
        while kill -0 "$pid" 2>/dev/null; do
            seg=$(( $(date +%s) - inicio ))
            ultima="$(tail -c 400 "$UI_LOG" 2>/dev/null | tr '\r' '\n' | tr -d '\000-\010\013\014\016-\037' | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' | grep -a -v '^[[:space:]]*$' | tail -n 1)"   # sin bytes de control: un instalador que imprime binario no ensucia el spinner
            tmp="$(ui_tiempo "$seg")"
            # texto fijo = "  ⠋  mensaje  (12s)  ": si no cabe entero, se recorta el mensaje; lo que sobra se usa para la última línea de salida
            fijo=$(( 2 + 1 + 2 + ${#tmp} + 4 + 2 ))
            vmsg="$msg"; [ $(( ${#msg} + fijo )) -gt "$ancho" ] && vmsg="${msg:0:$(( ancho - fijo - 1 > 4 ? ancho - fijo - 1 : 4 ))}…"
            libre=$(( ancho - fijo - ${#vmsg} ))
            disp=""; [ "$libre" -gt 6 ] && disp="${ultima:0:$libre}"
            printf '\r\033[K  %s%s%s  %s  (%s)  %s%s%s' "$C_ACENTO" "${UI_GIRO[i % ${#UI_GIRO[@]}]}" "$C_R" "$vmsg" "$tmp" "$C_TENUE" "$disp" "$C_R"
            i=$(( i + 1 )); sleep 0.1
        done
        wait "$pid" && rc=0 || rc=$?
        trap - WINCH
        printf '\r\033[K'
    fi
    t="$(ui_tiempo $(( $(date +%s) - inicio )))"
    ancho="$(ui_ancho)"
    if [ "$rc" -eq 0 ]; then
        ui_registrar ok
        vmsg="$(ui_recortar "$msg" $(( ancho - ${#S_OK} - ${#t} - 9 )))"       # una sola fila aunque la ventana sea estrecha
        puntos=$(( ancho - ${#S_OK} - ${#vmsg} - ${#t} - 8 )); [ "$puntos" -ge 2 ] || puntos=2
        printf '  %s%s%s %s %s%s%s %s\n' "$C_OK" "$S_OK" "$C_R" "$vmsg" "$C_TENUE" "$(ui_repetir "$puntos" '.')" "$C_R" "$t"
    else
        ui_registrar fallo
        vmsg="$(ui_recortar "$msg" $(( ancho - ${#S_ERR} - ${#t} - 20 )))"
        printf '  %s%s%s %s  (código %d, %s)\n' "$C_ERR" "$S_ERR" "$C_R" "$vmsg" "$rc" "$t"
        tail -c +"$(( desde + 1 ))" "$UI_LOG" | tr '\r' '\n' | tr -d '\000-\010\013\014\016-\037' | grep -a -v '^[[:space:]]*$' | tail -n 8 | sed "s/^/      ${C_TENUE}/; s/\$/${C_R}/"
        printf '      %sRegistro completo: %s%s\n' "$C_TENUE" "$UI_LOG" "$C_R"
    fi
    return "$rc"
}

# ---- recuadro y resumen ----
ui_caja() {   # una línea por argumento
    local max=0 l ancho
    for l in "$@"; do [ "${#l}" -gt "$max" ] && max="${#l}"; done
    ancho=$(( max + 4 ))
    printf '  %s%s%s%s%s\n' "$C_ACENTO" "$B_TL" "$(ui_repetir "$ancho" "$B_H")" "$B_TR" "$C_R"
    for l in "$@"; do
        printf '  %s%s%s  %s%*s  %s%s%s\n' "$C_ACENTO" "$B_V" "$C_R" "$l" $(( max - ${#l} )) "" "$C_ACENTO" "$B_V" "$C_R"
    done
    printf '  %s%s%s%s%s\n' "$C_ACENTO" "$B_BL" "$(ui_repetir "$ancho" "$B_H")" "$B_BR" "$C_R"
}
ui_resumen() {
    local titulo="${1:-Listo}" oks=0 fallos=0 avisos=0 seg
    oks="$(grep -c '^ok$' "$UI_STATS" 2>/dev/null || true)"; fallos="$(grep -c '^fallo$' "$UI_STATS" 2>/dev/null || true)"; avisos="$(grep -c '^aviso$' "$UI_STATS" 2>/dev/null || true)"
    seg=$(( $(date +%s) - UI_INICIO ))
    printf '\n'
    local po="pasos correctos" pf=errores pa=avisos
    [ "${oks:-0}" = 1 ] && po="paso correcto";  [ "${fallos:-0}" = 1 ] && pf=error;  [ "${avisos:-0}" = 1 ] && pa=aviso
    ui_caja "$titulo" "${oks:-0} $po  ·  $(ui_tiempo "$seg")  ·  ${fallos:-0} $pf  ·  ${avisos:-0} $pa"
    printf '\n'
}

# ui_sudo: pide la contraseña UNA vez y la mantiene viva mientras dure el script (las animaciones ocultan
# cualquier aviso de sudo, así que hay que tenerla antes). Si setup.sh ya lo hizo, no repite.
UI_KEEPALIVE=""
ui_sudo() {
    sudo -v || { ui_error "No se pudo obtener permiso de administrador (sudo)."; exit 1; }
    if [ -z "${MIARCH_SUDO_VIVO:-}" ]; then
        ( while true; do sudo -n true; sleep 45; kill -0 "$$" 2>/dev/null || exit; done ) &
        UI_KEEPALIVE=$!
        trap '[ -z "$UI_KEEPALIVE" ] || kill "$UI_KEEPALIVE" 2>/dev/null || true' EXIT
    fi
}
