#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Demo v9 — orden final de la demo. Uso: demo-v9.sh LOG [--seco|--prueba]
S=$HOME/demo-miarch
LOG=${1:-/tmp/miarch-demo-v9.log}; PRUEBA=0; SECO=0
[ "${2:-}" = "--prueba" ] && PRUEBA=1
[ "${2:-}" = "--seco" ] && SECO=1
MIARCH_DEMO_MUSICA=; MIARCH_DEMO_PASS=; MIARCH_DEMO_PANTALLA=HDMI-A-1; MIARCH_DEMO_BLOQUEO_SEG=3
if [ "$SECO" = 0 ] && [ "$PRUEBA" = 0 ]; then [ -f ~/.config/miarch/personal/demo.env ] && . ~/.config/miarch/personal/demo.env; fi
PANT=$MIARCH_DEMO_PANTALLA; EDP=$(hyprctl monitors -j | python3 -c "import json,sys; print(next((m['name'] for m in json.load(sys.stdin) if m['name']!='$PANT'),''))")
RITMO=1; [ $PRUEBA = 1 ] && RITMO=0.25
V=$HOME/Vídeos/miarch-demo-$(date +%Y%m%d-%H%M%S).mp4; BRUTO=$V.bruto.mp4
WP=$HOME/Imágenes/Wallpapers; FALLOS=0
# Orden de fondos: verde (hombre en la silla) → azul (ciudad) → blanco (mujer). Acaba en el blanco.
FONDO_VERDE=$WP/a_man_sitting_in_a_chair.png; FONDO_AZUL=$WP/city.gif; FONDO_BLANCO=$WP/a_woman_with_long_hair_wearing_sunglasses.png; FONDO_FINAL=$FONDO_BLANCO
log() { echo "$*" >> $LOG; }
esp() { sleep $(awk "BEGIN{print $1*$RITMO}"); }
q() { qs -c miarch ipc call "$@" >/dev/null 2>&1; }
cambiar_fondo() { if command -v wallpaper.sh >/dev/null 2>&1; then wallpaper.sh "$@"; else "$HOME/.local/bin/wallpaper.sh" "$@"; fi; }
hy() { hyprctl dispatch "$1" >/dev/null 2>&1; }
estado_lock() { qs -c miarch ipc call lock estado 2>/dev/null; }
comprobar() { if eval "$2"; then log "  ok    $1"; return 0; else log "  FALLO $1"; FALLOS=$((FALLOS+1)); return 1; fi; }
cerrar_un_panel() { local obj=$1; if q "$obj" close; then log "  ok    IPC $obj close enviado"; else log "  FALLO IPC $obj close"; FALLOS=$((FALLOS+1)); fi; }
cerrar_paneles() { cerrar_un_panel launcher; cerrar_un_panel ia; cerrar_un_panel settings; cerrar_un_panel power; sleep 0.2; }
abrir_panel() { local obj=$1 nombre=$2; foco_pant; if q "$obj" open; then log "  ok    $nombre: IPC $obj open enviado"; else log "  FALLO IPC $obj open"; FALLOS=$((FALLOS+1)); fi; sleep 0.3; }
medir_escena() { ESCENA_INICIO=$(date +%s); }
fin_escena() { local dur=$(( $(date +%s)-ESCENA_INICIO )); log "duración escena $1: ${dur}s"; }
# El cursor se aparca en la esquina inferior derecha del monitor grabado (dentro de él, para que el foco no salte al portátil)
park() { local g; g=$(hyprctl monitors -j | python3 -c "import json,sys; m=next(m for m in json.load(sys.stdin) if m['name']=='$PANT'); print(m['x']+int(m['width']/m['scale'])-1, m['y']+int(m['height']/m['scale'])-1)"); hy "hl.dsp.cursor.move({ x = ${g% *}, y = ${g#* } })"; }
foco_pant() { hy "hl.dsp.focus({ monitor = \"$PANT\" })"; park; sleep 0.25; local f; f=$(hyprctl monitors -j | python3 -c "import json,sys; print(next(m['name'] for m in json.load(sys.stdin) if m['focused']))"); if [ "$f" = "$PANT" ]; then log "  ok    foco en $PANT"; else log "  FALLO el foco está en $f, no en $PANT"; FALLOS=$((FALLOS+1)); fi; }
activo() { hyprctl monitors -j | python3 -c "import json,sys; print(next(m['activeWorkspace']['id'] for m in json.load(sys.stdin) if m['name']=='$PANT'))"; }
ws() { hy "hl.dsp.focus({ monitor = \"$PANT\" })"; hy "hl.dsp.focus({ workspace = \"$1\" })"; park; sleep 0.4; [ "$(activo)" = "$1" ] || { sleep 0.6; hy "hl.dsp.focus({ monitor = \"$PANT\" })"; hy "hl.dsp.focus({ workspace = \"$1\" })"; park; }; comprobar "el monitor $PANT muestra el escritorio $1" "[ \"\$(activo)\" = \"$1\" ]"; }

nvent() { hyprctl clients -j | python3 -c "import json,sys; print(sum(1 for c in json.load(sys.stdin) if c['class']=='miarch-demo' and c['workspace']['id']==$1 and c['monitor']==$(hyprctl monitors -j | python3 -c "import json,sys; print(next(m['id'] for m in json.load(sys.stdin) if m['name']=='$PANT'))")))"; }
nvent_titulo() { local nombre=$1 escritorio=${2:-1}; hyprctl clients -j | python3 -c "import json,sys; print(sum(1 for c in json.load(sys.stdin) if c.get('class')=='miarch-demo' and c.get('title')=='$nombre' and c['workspace']['id']==$escritorio))"; }
abrir() {
  local nombre=$1 opciones=$2 intento antes despues
  antes=$(direcciones_demo)
  for intento in 1 2; do
    hy "hl.dsp.exec_cmd(\"[monitor $PANT; workspace 1 silent] kitty --class miarch-demo --title $nombre $opciones -e $S/prog/run-$nombre.sh\")"
    sleep 1.4
    despues=$(direcciones_demo)
    if [ "$despues" != "$antes" ] && [ "$(nvent_titulo "$nombre")" -gt 0 ]; then registrar_demos_nuevos "$antes"; comprobar "ventana $nombre abierta" true; return; fi
  done
  comprobar "ventana $nombre abierta tras un reintento" false
}
DEMO_ADDRS=()
MUSIC_ADDRS=()
TERMINAL_ADDR=
direcciones_demo() { hyprctl clients -j | python3 -c "import json,sys; print(' '.join(c['address'] for c in json.load(sys.stdin) if c.get('class')=='miarch-demo'))"; }
registrar_demos_nuevos() { local antes=$1 a; local despues; despues=$(direcciones_demo); for a in $despues; do case " $antes " in *" $a "*) ;; *) DEMO_ADDRS+=("$a");; esac; done; }
direccion_titulo() { local nombre=$1 escritorio=${2:-1}; hyprctl clients -j | python3 -c "import json,sys; print(next((c['address'] for c in json.load(sys.stdin) if c.get('class')=='miarch-demo' and c.get('title')=='$nombre' and c['workspace']['id']==$escritorio),''))"; }
registrar_musica() { local nombre=$1 a; a=$(direccion_titulo "$nombre" 2); [ -n "$a" ] && MUSIC_ADDRS+=("$a"); }
cerrar_direcciones() { local a x; for a in "$@"; do [ -n "$a" ] || continue; hy "hl.dsp.window.close({ window = \"address:$a\" })"; for x in "${!DEMO_ADDRS[@]}"; do [ "${DEMO_ADDRS[$x]}" = "$a" ] && unset 'DEMO_ADDRS[x]'; done; done; sleep 0.8; }
cerrar_demo() { [ "${#DEMO_ADDRS[@]}" -gt 0 ] && cerrar_direcciones "${DEMO_ADDRS[@]}"; }
if [ "$SECO" = 1 ]; then
  log "modo seco: plan; tiempos relativos en segundos"
  for c in hyprctl qs wtype paplay playerctl gpu-screen-recorder notify-send kitty python3 ffmpeg pgrep pkill setsid awk cat date du cut grep head seq sleep tr mv rm kill; do
    command -v "$c" >/dev/null 2>&1 && log "  comando disponible: $c" || log "  FALLO falta comando: $c"
  done
  if command -v wallpaper.sh >/dev/null 2>&1 || command -v "$HOME/.local/bin/wallpaper.sh" >/dev/null 2>&1; then log "  comando disponible: wallpaper.sh"; else log "  FALLO falta comando: wallpaper.sh"; fi
  [ -x "$S/prog/run-tux.sh" ] && log "  lanzador disponible: prog/run-tux.sh" || log "  FALLO falta lanzador: prog/run-tux.sh"
  IPC=$(qs -c miarch ipc show 2>/dev/null)
  for obj in launcher settings power ia lock notif; do
    printf '%s\n' "$IPC" | grep -q "$obj" && log "  IPC disponible: $obj" || log "  FALLO falta IPC: $obj"
  done
  cat >>"$LOG" <<'PLAN'
  00s Preparar: fondo inicial verde (hombre) si no lo es; Quickshell en modo demo; cerrar solo ventanas miarch-demo antiguas
  08s Escena 0: bloqueo y entrada de cine (espera humana excluida)
  27s Escena 1: escritorio 1 con fondo verde, música en pausa, 4 s
  31s Escena 2: terminal Tux, 4 s
  35s Escena 3: escritorio 2; crear cava → play → resto; página de música (~13 s)
  48s Escena 4: escritorio 1; cerrar solo Tux; música sigue abierta (~2 s)
  50s Escena a-b-c: escritorio 2 (2 s), cambios 1→2→1 (1 s cada uno), fondo verde → azul (3 s)  ≈ 9 s
  59s Escena d-e: cambios 2→1, fondo azul → blanco  ≈ 6 s
  65s Escena g: juego de terminales: 3 terminales, redimensionar, flotante, división, cerrar (~12 s)
  77s Escenas f,7,8,9: buscador, IA, energía y ajustes (~35 s)
  112s Escena 10: actualizador simulado (~16 s)
  128s Escena 11: escritorio 2; el volumen de la música baja en 4 s → bloqueo final (se oyen las teclas) → al salir MIARCH se pausa la canción → plano congelado 3 s
  Fondo final: blanco (mujer). Música en pausa al terminar.
PLAN
  exit 0
fi
CUR=$(hyprctl cursorpos | tr -d " "); REC=""; FONDO=$(cat ~/.cache/miarch-wallpaper 2>/dev/null); ESTADO=$(playerctl status 2>/dev/null)
VOL_ORIG=$(playerctl volume 2>/dev/null)
# Baja el volumen de Spotify (solo su reproductor por MPRIS, nunca el del sistema) hasta casi 0 en ~4 s.
# Música propia (MIARCH_DEMO_MUSICA=ruta en demo.env): se reproduce con paplay en vez de Spotify (pw-play no llega a la grabación), así cava va a la par y el audio del vídeo queda libre de derechos.
id_flujo_musica() { pw-dump 2>/dev/null | python3 -c "
import json,sys
for o in json.load(sys.stdin):
    p=o.get('info',{}).get('props',{})
    if p.get('media.class')=='Stream/Output/Audio' and 'paplay' in (p.get('application.name','')+p.get('application.process.binary','')): print(o['id']); break"; }
bajar_volumen_archivo() { local id i; id=$(id_flujo_musica); [ -n "$id" ] || { log "aviso: no se encontró el flujo de la música propia"; return; }; for i in $(seq 1 16); do wpctl set-volume "$id" "$(awk "BEGIN{printf \"%.3f\", 0.9*(1-$i/16)}")" 2>/dev/null; sleep 0.25; done; log "música propia bajada gradualmente"; }
bajar_volumen() { if [ -n "${MUSICA_PID:-}" ] && kill -0 "$MUSICA_PID" 2>/dev/null; then bajar_volumen_archivo; return; fi; local v0=${VOL_ORIG:-0.9} i pasos=16 v; for ((i=1;i<=pasos;i++)); do v=$(awk "BEGIN{printf \"%.3f\", $v0*(1-$i/$pasos)}"); playerctl volume "$v" 2>/dev/null; sleep 0.25; done; log "volumen de la música bajado gradualmente (original $v0)"; }
restaurar_volumen() { [ -n "$VOL_ORIG" ] && playerctl volume "$VOL_ORIG" 2>/dev/null; }
limpiar() {
  cerrar_paneles; q notif cerrar
  if [ -n "$REC" ]; then
    kill -INT "$REC" 2>/dev/null
    for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$REC" 2>/dev/null || break; sleep 0.2; done
    kill -0 "$REC" 2>/dev/null && kill -TERM "$REC" 2>/dev/null
    sleep 0.2
    kill -0 "$REC" 2>/dev/null && kill -KILL "$REC" 2>/dev/null
    wait "$REC" 2>/dev/null
    REC=""
  fi
  # Una ventana puede aparecer justo antes de una interrupción, antes del siguiente sondeo.
  registrar_demos_nuevos ""
  cerrar_demo
  [ "$ESTADO" != "Playing" ] && playerctl pause 2>/dev/null
  [ -n "${MUSICA_PID:-}" ] && kill "$MUSICA_PID" 2>/dev/null
  restaurar_volumen
  cambiar_fondo "$FONDO_FINAL" >/dev/null 2>&1; log "limpieza: fondo final blanco (mujer)"
  pkill -x qs 2>/dev/null; sleep 1; (setsid -f qs -c miarch >/dev/null 2>&1 </dev/null)
  [ -n "$EDP" ] && { hy "hl.dsp.focus({ monitor = \"$EDP\" })"; hy "hl.dsp.focus({ workspace = \"10\" })"; }
  hy "hl.dsp.cursor.move({ x = ${CUR%,*}, y = ${CUR#*,} })"
  hy "hl.dsp.focus({ monitor = \"$PANT\" })"; hy "hl.dsp.focus({ workspace = \"1\" })"
  if [ -f "$BRUTO" ]; then recortar; fi
  log "FIN $(date +%T) · fallos: $FALLOS · vídeo: $V ($(du -h "$V" 2>/dev/null | cut -f1))"
}
recortar() {
  # quita las esperas de contraseña (conserva N s de cada bloqueo) y congela el último plano 3 s
  if [ -n "${T_LOCK:-}" ] && [ -n "${T_UNLOCK:-}" ] && [ -n "${T_LOCK2:-}" ] && [ -n "${T_UNLOCK2:-}" ] && [ -n "${T_FIN:-}" ] && [ "$MIARCH_DEMO_BLOQUEO_SEG" != 0 ]; then
    r() { awk "BEGIN{print $1-$T_REC}"; }
    L1=$(awk "BEGIN{print $(r $T_LOCK)+$MIARCH_DEMO_BLOQUEO_SEG}"); U1=$(awk "BEGIN{print $(r $T_UNLOCK)-0.4}")
    L2=$(awk "BEGIN{print $(r $T_LOCK2)+$MIARCH_DEMO_BLOQUEO_SEG}"); U2=$(awk "BEGIN{print $(r $T_UNLOCK2)-0.4}"); F=$(r $T_FIN)
    ffmpeg -v error -y -i "$BRUTO" -filter_complex "[0:v]trim=0:$L1,setpts=PTS-STARTPTS[v1];[0:a]atrim=0:$L1,asetpts=PTS-STARTPTS[a1];[0:v]trim=$U1:$L2,setpts=PTS-STARTPTS[v2];[0:a]atrim=$U1:$L2,asetpts=PTS-STARTPTS[a2];[0:v]trim=$U2:$F,setpts=PTS-STARTPTS,tpad=stop_mode=clone:stop_duration=3[v3];[0:a]atrim=$U2:$F,asetpts=PTS-STARTPTS,apad=pad_dur=3[a3];[v1][a1][v2][a2][v3][a3]concat=n=3:v=1:a=1[v][a]" -map "[v]" -map "[a]" -c:v libx264 -preset fast -crf 18 -c:a aac "$V" 2>>$LOG && rm -f "$BRUTO" && { log "recortado: bloqueos $L1→$U1 y $L2→$U2; congelado final 3 s"; if [ -n "${T_PLAY:-}" ]; then SEG=$(awk "BEGIN{printf \"%.1f\", ($T_PLAY-$T_REC)-($U1-$L1)}"); log "SINCRONIZAR: la canción empieza en el segundo $SEG del vídeo final. En TikTok pon el sonido desde ahí, desde el principio de la canción"; fi; } || { mv "$BRUTO" "$V"; log "no se pudo recortar; vídeo sin recortar"; }
  else mv "$BRUTO" "$V"; fi
}
trap limpiar EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
log "inicio $(date +%T) · prueba=$PRUEBA · pantalla=$PANT · portátil=$EDP · fondo=$(basename "$FONDO") · música=$ESTADO"
# Bloquea con IPC, confirma el estado y solo entonces puede escribir la clave.
bloquear_y_esperar() {
  local etiqueta=$1 estado="" sonido=0 confirmable=0 intento
  for intento in 1 2; do
    q lock lock
    sleep 1
    estado=$(estado_lock)
    if [ "$estado" = bloqueado ]; then confirmable=1; break; fi
    log "  aviso: lock $etiqueta no confirmado (estado=${estado:-sin respuesta}); reintento $intento/2"
  done
  if [ "$confirmable" = 0 ]; then
    if [ -z "$estado" ]; then
      log "  aviso: IPC lock estado no existe; no se escribió contraseña; se espera sonido de desbloqueo (máx. 150 s)"
      local i
      for ((i=0; i<300; i++)); do
        if pgrep -f '(paplay|pw-play).*desbloqueo' >/dev/null 2>&1; then log "desbloqueo detectado por sonido (respaldo)"; return 0; fi
        sleep 0.5
      done
      log "ERROR: sin estado IPC ni sonido de desbloqueo tras 150 s; se requiere intervención manual"
      return 1
    fi
    log "ERROR: no se confirmó el bloqueo $etiqueta (estado libre); no se escribió contraseña"
    return 1
  fi
  log "bloqueado $etiqueta $(date +%T) · atajo representado: Super+L"
  if [ -n "$MIARCH_DEMO_PASS" ] && command -v wtype >/dev/null 2>&1; then
    sleep 3.5
    if [ "$(estado_lock)" = bloqueado ]; then wtype "$MIARCH_DEMO_PASS"; sleep 0.3; wtype -k Return; log "contraseña enviada tras confirmar bloqueo";
    else log "contraseña omitida: el estado dejó de ser bloqueado"; fi
  else log "sin clave automatizable; se espera entrada manual sin escribir contraseña"
  fi
  local i
  for ((i=0; i<300; i++)); do
    estado=$(estado_lock)
    [ "$estado" = libre ] && { log "desbloqueo confirmado por estado IPC"; return 0; }
    if pgrep -f '(paplay|pw-play).*desbloqueo' >/dev/null 2>&1; then sonido=1; fi
    [ "$sonido" = 1 ] && { log "desbloqueo detectado por sonido (señal secundaria)"; return 0; }
    sleep 0.5
  done
  log "ERROR: tiempo agotado (150 s) esperando desbloqueo $etiqueta; limpieza de grabador y restauración"
  if [ "$(estado_lock)" = bloqueado ] && [ -n "$MIARCH_DEMO_PASS" ] && command -v wtype >/dev/null 2>&1; then
    log "  recuperación: estado confirma bloqueo; se reintenta la clave una vez para no dejar la sesión bloqueada"
    wtype "$MIARCH_DEMO_PASS"; sleep 0.3; wtype -k Return
    for _ in 1 2 3 4 5 6 7 8 9 10; do [ "$(estado_lock)" = libre ] && break; sleep 0.5; done
    [ "$(estado_lock)" = libre ] && log "  recuperación: sesión libre confirmada" || log "  ERROR: sesión aún bloqueada; se requiere entrada manual"
  else
    log "  no se envía clave sin confirmar bloqueo; compruebe manualmente el estado de sesión"
  fi
  return 1
}
# --- preparación: elimina únicamente ventanas viejas de la clase de demo.
ANTES_DEMO=$(direcciones_demo)
for a in $ANTES_DEMO; do hy "hl.dsp.window.close({ window = \"address:$a\" })"; done
sleep 0.8
comprobar "ventanas antiguas miarch-demo cerradas" "[ -z \"\$(direcciones_demo)\" ]"
# El script mira el fondo actual y, si no es el verde, lo cambia antes de grabar para empezar en ese orden.
if [ "$(cat ~/.cache/miarch-wallpaper 2>/dev/null)" != "$FONDO_VERDE" ]; then cambiar_fondo "$FONDO_VERDE" >/dev/null 2>&1; sleep 3.5; log "fondo inicial cambiado a verde (antes: $(basename "$FONDO"))"; else log "fondo inicial ya era verde"; fi
comprobar "el fondo inicial es el verde" "[ \"\$(cat ~/.cache/miarch-wallpaper)\" = \"$FONDO_VERDE\" ]"
hy "hl.dsp.focus({ monitor = \"$PANT\" })"; hy "hl.dsp.focus({ workspace = \"1\" })"
[ -n "$EDP" ] && { hy "hl.dsp.focus({ monitor = \"$EDP\" })"; hy "hl.dsp.focus({ workspace = \"10\" })"; }
pkill -x qs; sleep 1; (MIARCH_DEMO=1 setsid -f qs -c miarch >/dev/null 2>&1 </dev/null); sleep 4
comprobar "quickshell en modo demo (redes ocultas)" "tr '\0' '\n' < /proc/\$(pgrep -x qs | head -1)/environ | grep -q MIARCH_DEMO=1"
ws 1
medir_escena; log "escena 0: bloqueo y entrada (secuencia v6 conservada)"
if [ $PRUEBA = 0 ]; then
  notify-send -a Miarch "Demo en 5 s" "Escribe tu contraseña cuando salga el bloqueo. No toques nada más."; sleep 6; q notif cerrar; sleep 1
  gpu-screen-recorder -w $PANT -f 60 -a default_output -q high -o "$BRUTO" >> $LOG 2>&1 &
  REC=$!; T_REC=$(date +%s.%N); sleep 3; kill -0 $REC 2>/dev/null || { log "ERROR: el grabador no arrancó"; exit 1; }
  # 0 bloqueo
  T_LOCK=$(date +%s.%N); bloquear_y_esperar inicial || exit 1
  T_UNLOCK=$(date +%s.%N); log "desbloqueado $(date +%T)"; sleep 3
fi
fin_escena 0
# 1 tras el desbloqueo inicial: escritorio 1, tarjeta visible y canción en pausa.
medir_escena; log "escena 1: escritorio 1, tarjeta de música en pausa"; ws 1; playerctl pause 2>/dev/null; sleep 4; fin_escena 1
# 2 terminal Tux: el lanzador muestra fastfetch seguro y luego abre zsh -f.
medir_escena; log "escena 2: terminal Tux · atajo representado: Super+Enter"
ANTES_TERM=$(direcciones_demo)
hy "hl.dsp.focus({ monitor = \"$PANT\" })"; hy "hl.dsp.exec_cmd(\"[monitor $PANT; workspace 1 silent] kitty --class miarch-demo --title demo-terminal -e $S/prog/run-tux.sh\")"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  registrar_demos_nuevos "$ANTES_TERM"
  TERMINAL_ADDR=$(direccion_titulo demo-terminal 1)
  [ -n "$TERMINAL_ADDR" ] && break
  sleep 0.2
done
comprobar "terminal Tux abierta en escritorio 1 con dirección guardada" "[ -n \"$TERMINAL_ADDR\" ]"
sleep 3; fin_escena 2
# 3 música creada ahora, secuencialmente: cava debe existir antes de reanudar.
medir_escena; log "escena 3: escritorio 2, página de música en vivo · atajo: Super+2"; ws 2
abrir_musica() {
  local nombre=$1 geometria=$2 antes intento
  antes=$(direcciones_demo)
  hy "hl.dsp.exec_cmd(\"[monitor $PANT; workspace 2 silent; float; $geometria] kitty --class miarch-demo --title $nombre -e $S/prog/run-$nombre.sh\")"
  for intento in 1 2 3 4 5 6 7 8 9 10; do
    [ "$(nvent_titulo "$nombre" 2)" -gt 0 ] && break
    sleep 0.2
  done
  registrar_demos_nuevos "$antes"
  registrar_musica "$nombre"
  comprobar "ventana musical $nombre abierta en escritorio 2" "[ \"\$(nvent_titulo '$nombre' 2)\" -gt 0 ]"
}
abrir_musica cava "size 1250 880; move 22 68"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  registrar_demos_nuevos "$(direcciones_demo)"
  [ "$(nvent_titulo cava 2)" -gt 0 ] && break
  sleep 0.2
done
  if [ "$(nvent_titulo cava 2)" -gt 0 ]; then if [ -n "${MIARCH_DEMO_MUSICA:-}" ] && [ -f "$MIARCH_DEMO_MUSICA" ] && command -v pw-play >/dev/null 2>&1; then F="$MIARCH_DEMO_MUSICA"; case "$F" in *.wav|*.ogg|*.flac) ;; *) ffmpeg -v error -y -i "$F" /tmp/miarch-demo-musica.wav 2>/dev/null && F=/tmp/miarch-demo-musica.wav;; esac   # paplay lee wav/ogg/flac
  paplay --volume=58982 "$F" >/dev/null 2>&1 & MUSICA_PID=$!; log "cava visible; música propia en marcha: $(basename "$MIARCH_DEMO_MUSICA")"; else playerctl position 0 2>/dev/null; playerctl play 2>/dev/null; log "cava visible; canción reiniciada desde el principio y en marcha (para sincronizar cava)"; fi; T_PLAY=$(date +%s.%N); else comprobar "cava visible antes de reanudar" false; fi
abrir_musica sptlrx "size 1250 98; move 22 960"
abrir_musica peaclock "size 608 230; move 1290 68"
abrir_musica cbonsai "size 608 420; move 1290 310"
abrir_musica pipes "size 608 316; move 1290 742"
sleep 7; fin_escena 3
# 4 retorno al escritorio 1: cierra solo Tux; la música queda viva en escritorio 2.
medir_escena; log "escena 4: vuelta al escritorio 1 · atajo representado: Super+1"; ws 1
[ -n "$TERMINAL_ADDR" ] && cerrar_direcciones "$TERMINAL_ADDR"
TERMINAL_ADDR=
comprobar "terminal Tux cerrada al volver al escritorio 1" "[ \"$(nvent_titulo demo-terminal 1)\" = 0 ]"
comprobar "ventanas musicales siguen abiertas tras cerrar Tux" "[ \"$(nvent 2)\" -ge 5 ]"
sleep 0.3; fin_escena 4
# a: la página musical permanece viva en escritorio 2.
medir_escena; log "escena a: música en escritorio 2 · atajo representado: Super+2"; ws 2; sleep 1.6; fin_escena a
# b: alternancia visible, con foco HDMI antes de cada cambio.
medir_escena; log "escena b: alternancia visible de escritorios"
ws 1; sleep 1; ws 2; sleep 1; ws 1; sleep 1; fin_escena b
# c: verde → azul (ciudad); wallpaper.sh aplica también la paleta del sistema.
medir_escena; log "escena c: fondo verde → azul"
cambiar_fondo "$FONDO_AZUL" >/dev/null 2>&1; sleep 3; fin_escena c
# d: otra alternancia mientras la página musical sigue abierta en escritorio 2.
medir_escena; log "escena d: alternancia de escritorios"
ws 2; sleep 1; ws 1; sleep 1; fin_escena d
# e: azul → blanco (mujer): queda como fondo final.
medir_escena; log "escena e: fondo azul → blanco"
cambiar_fondo "$FONDO_BLANCO" >/dev/null 2>&1; sleep 3
comprobar "el fondo es el blanco" "[ \"\$(cat ~/.cache/miarch-wallpaper)\" = \"$FONDO_BLANCO\" ]"; fin_escena e
# g: juego de terminales (tras los cambios de fondo): 3 terminales normales, redimensionadas, flotante y cambio de división.
medir_escena; log "escena g: juego de terminales · atajos representados: Super+Enter, Super+F, Super+J"
JUEGO_ADDRS=()
ws 1
nueva_terminal() {
  local n=$1 antes a
  antes=$(direcciones_demo)
  hy "hl.dsp.focus({ monitor = \"$PANT\" })"
  hy "hl.dsp.exec_cmd(\"kitty --class miarch-demo --title juego-$n\")"
  for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do [ "$(nvent_titulo "juego-$n" 1)" -gt 0 ] && break; sleep 0.2; done
  registrar_demos_nuevos "$antes"
  a=$(direccion_titulo "juego-$n" 1); [ -n "$a" ] && JUEGO_ADDRS+=("$a")
  park; sleep 0.5
}
redimensionar() { local d R; for d in 150 -150 110 -110; do R=$(hyprctl dispatch "hl.dsp.window.resize({ x = $d, y = 0, relative = true })" 2>&1); case "$R" in *rror*) log "  FALLO redimensionar: $R"; FALLOS=$((FALLOS+1)); return;; esac; sleep 0.3; done; }
nueva_terminal 1; redimensionar
nueva_terminal 2; redimensionar
nueva_terminal 3; redimensionar
comprobar "3 terminales del juego abiertas" "[ \"\${#JUEGO_ADDRS[@]}\" = 3 ]"
hy 'hl.dsp.window.float({ action = "toggle" })'; sleep 1.2; hy 'hl.dsp.window.float({ action = "toggle" })'; sleep 0.8
hy 'hl.dsp.layout("togglesplit")'; sleep 1.2
cerrar_direcciones "${JUEGO_ADDRS[@]}"; JUEGO_ADDRS=()
comprobar "terminales del juego cerradas" "[ \"\$(nvent 1)\" = 0 ]"
fin_escena g
# Cada escena de panel parte de estado cerrado; nunca se usa toggle.
medir_escena; cerrar_paneles; log "escena f: buscador · atajo representado: Super+Espacio"; abrir_panel launcher buscador
for t in steam spotify; do
  if command -v wtype >/dev/null; then wtype -d 170 "$t"; esp 2; wtype -M ctrl -k a -m ctrl; wtype -k BackSpace
  else q launcher search "$t"; esp 2; fi
done
q launcher close; fin_escena f
medir_escena; cerrar_paneles; log "escena 7: menú de IA · atajo representado: Super+C"; abrir_panel ia "panel de IA"; sleep 4; q ia close; fin_escena 7
medir_escena; cerrar_paneles; log "escena 8: energía · atajo representado: Super+Shift+Escape"; abrir_panel power "panel de energía"; sleep 2; q power atajos; sleep 4; q power close; fin_escena 8
medir_escena; cerrar_paneles; log "escena 9: ajustes · atajo representado: Super+Escape"; abrir_panel settings "panel de ajustes"
for p in sonido pantallas pantalla apariencia entrada accesibilidad energia; do q settings page "$p"; sleep 2; done
q settings close; fin_escena 9
# 10 actualizador en ventana completa durante 14 s.
medir_escena; log "escena 10: actualizador (simulación)"
abrir actualizador "--start-as=fullscreen -o font_size=13"
comprobar "terminal del actualizador abierta" "[ \"\$(nvent 1)\" = 1 ]"
sleep 14
ACTUALIZADOR_ADDR=$(direccion_titulo actualizador 1)
[ -n "$ACTUALIZADOR_ADDR" ] && cerrar_direcciones "$ACTUALIZADOR_ADDR"
comprobar "actualizador cerrado sin cerrar música" "[ \"$(nvent_titulo actualizador 1)\" = 0 ]"
comprobar "ventanas musicales siguen abiertas tras el circuito" "[ \"$(nvent 2)\" -ge 5 ]"
fin_escena 10
# 11 final: vuelve a bloquear y desbloquear; congela el plano cuando se lee "MIARCH · by alejandro-xoxo"
medir_escena; log "escena 11: escritorio 2, música visible 4 s y bloqueo final"; ws 2
comprobar "música visible en escritorio 2 antes del bloqueo final" "[ \"$(nvent 2)\" -ge 5 ]"
bajar_volumen   # ~4 s con la página de música a la vista; para cuando empieza el login casi no se oye
if [ $PRUEBA = 0 ]; then
  for i in $(seq 1 40); do pgrep -f '(paplay|pw-play).*desbloqueo' >/dev/null || break; sleep 0.5; done
  comprobar "bloqueo final emitido estando en escritorio 2" "[ \"$(activo)\" = 2 ]"
  T_LOCK2=$(date +%s.%N); bloquear_y_esperar final || exit 1
  T_UNLOCK2=$(date +%s.%N); log "desbloqueado (final) $(date +%T)"
  # El título MIARCH empieza a aparecer a los ~2,6 s de la entrada: en ese momento se pausa la canción y se restaura su volumen
  sleep 2.6; playerctl pause 2>/dev/null; [ -n "${MUSICA_PID:-}" ] && kill "$MUSICA_PID" 2>/dev/null; restaurar_volumen; log "música pausada al aparecer MIARCH"
  cerrar_direcciones "${MUSIC_ADDRS[@]}"
  MUSIC_ADDRS=()
  sleep 1.0   # el título y la firma ya están completos (la firma llega al 100 % a los ~3,8 s)
  T_FIN=$(date +%s.%N)
fi
fin_escena 11
exit 0
