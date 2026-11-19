# =============================================================================
# Miarch - Configuración Zsh (Clean & Minimal)
# =============================================================================

# --- [1] COLORES DINÁMICOS CON PYWAL ---
[[ -f ~/.cache/wal/sequences ]] && cat ~/.cache/wal/sequences
[[ -f ~/.cache/wal/colors-shell.sh ]] && source ~/.cache/wal/colors-shell.sh

# --- [2] OH MY ZSH ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="afowler"
ENABLE_CORRECTION="true"

plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-history-substring-search
)

source $ZSH/oh-my-zsh.sh

# --- [3] PROMPT PERSONALIZADO ---
# Dos colores, los mismos del resto del escritorio: acento y neutro (kitty los define como color16 y color17).
if [[ "$TERM" == xterm-kitty ]]; then
    _pa=16; _pn=17; _pt=8        # acento · neutro · tenue
else
    _pa=cyan; _pn=white; _pt=8
fi
function dir_icon {
    if [[ "$PWD" == "$HOME" ]]; then
        echo "%B%F{${_pt}}%f%b"
    else
        echo "%B%F{${_pa}}%f%b"
    fi
}

function parse_git_branch {
    local branch
    branch=$(git symbolic-ref --short HEAD 2> /dev/null)
    if [ -n "$branch" ]; then
        echo " [$branch]"
    fi
}

_pu='%n'; [[ -n "${MIARCH_DEMO:-}" ]] && _pu='usuario'   # MIARCH_DEMO=1 (capturas): oculta tu usuario
PROMPT='%F{${_pa}}󰣇 %f %F{${_pn}}${_pu}%f $(dir_icon) %F{${_pn}}%~%f %F{${_pt}}$(parse_git_branch)%f %(?.%B%F{${_pa}}.%F{red})%f%b '

# --- [4] ALIAS ÚTILES ---
alias l="eza -lh --icons=auto --group-directories-first"
alias ls="eza -ha --icons=auto --sort=name --group-directories-first"
alias ll="eza -lah --icons=auto --git"
alias lt="eza --tree --level=2 --icons"
alias n="nvim"
alias v="code"
alias wall="~/.local/bin/wallpaper.sh"

# --- [5] INICIO AUTOMÁTICO ---
# fastfetch adaptado al tamaño de la ventana (con "ff" lo vuelves a mostrar si la redimensionas)
if [[ -x "$HOME/.local/bin/miarch-fetch" ]]; then
    "$HOME/.local/bin/miarch-fetch"
elif command -v fastfetch > /dev/null; then
    fastfetch
fi
alias ff="$HOME/.local/bin/miarch-fetch"

# Si cambias el tamaño de la ventana ANTES de escribir tu primer comando (por ejemplo, al abrirse otra
# ventana al lado), el resumen se vuelve a dibujar a la medida nueva. Después del primer comando ya no
# toca nada, así que nunca te borra lo que estés haciendo.
typeset -g _miarch_fetch_vivo=1
_miarch_fetch_apagar() { _miarch_fetch_vivo=0 }
autoload -Uz add-zsh-hook
add-zsh-hook preexec _miarch_fetch_apagar
TRAPWINCH() {
    (( _miarch_fetch_vivo )) || return 0
    [[ -x "$HOME/.local/bin/miarch-fetch" ]] || return 0
    zle -I 2>/dev/null                    # avisa al editor de línea de que se va a escribir en pantalla
    print -n '\e[H\e[2J\e[3J'            # limpia la pantalla y el historial de la ventana
    "$HOME/.local/bin/miarch-fetch"
    print                                 # zle sube una línea al redibujar: este salto evita que pise la última
    zle && zle redisplay                  # redibuja el prompt si ya estaba esperando
    return 0
}

# --- [6] VARIABLES DE ENTORNO ---
# (el idioma lo define /etc/locale.conf; no forzar en_US si no está generado)

# Asegurar que ~/.local/bin esté en el PATH
export PATH="$HOME/.local/bin:$PATH"
