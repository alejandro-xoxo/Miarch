# Zsh

`packages.sh` clona Oh My Zsh con `git` (no ejecuta ningún script descargado), cambia tu shell a zsh y clona los plugins. `install.sh` copia `home/.zshrc`.

## Oh My Zsh
- **Tema:** `afowler` (el prompt real lo define `.zshrc`, con los colores del escritorio).
- **Plugins:**

| Plugin | Qué hace |
|---|---|
| `git` | Alias de git |
| `zsh-autosuggestions` | Sugiere comandos según tu historial |
| `zsh-syntax-highlighting` | Colorea el comando mientras lo escribes |
| `zsh-history-substring-search` | Busca en el historial con las flechas |

## Prompt
Usuario, carpeta (con ícono) y rama de git, con el acento y el neutro del wallpaper. El símbolo final se pone rojo si el último comando falló.

## Alias
| Alias | Hace |
|---|---|
| `l` · `ls` · `ll` · `lt` | `eza` en distintos formatos (`ll` con git, `lt` en árbol) |
| `n` | `nvim` |
| `v` | `code` |
| `wall` | Cambia el wallpaper y los colores |
| `ff` | Vuelve a mostrar fastfetch adaptado a la ventana |

## Al abrir una terminal
Se muestra `miarch-fetch`. Si cambias el tamaño de la ventana antes de escribir tu primer comando, se redibuja a la medida nueva; después no toca nada.
