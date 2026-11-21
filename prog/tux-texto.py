# SPDX-License-Identifier: GPL-3.0-or-later
# Tux hecho con LETRAS de terminal (grupos de caracteres variados por tono) a todo color, como un logo de fastfetch, con tres líneas de texto normal a la derecha:
# "Miarch", "Arch Linux" y "alejandro-xoxo". Lee tux.png (Tux de Larry Ewing, Simon Budig y Garrett LeSage, Wikimedia Commons).
# Sin datos personales. Se redibuja al cambiar el tamaño de la ventana.
import colorsys, os, signal, sys, time
from PIL import Image
IMG = os.path.expanduser("~/demo-miarch/tux.png")
# (texto, estilo, escala): el texto sigue siendo texto normal de terminal; kitty lo agranda con su protocolo de tamaño de texto (OSC 66)
LINEAS = [("Miarch", "1;38;2;255;255;255", 3), ("By", "38;2;215;215;220", 2), ("alejandro-xoxo", "38;2;215;215;220", 2)]
base = Image.open(IMG).convert("RGBA")
ASPECT = base.width / base.height
cambio = [True]
signal.signal(signal.SIGWINCH, lambda *a: cambio.__setitem__(0, True))

def color(r, g, b):
    """Colores del Tux, fuertes: amarillo y naranja vivos en pico y pies, barriga blanca y cuerpo en gris carbón azulado."""
    L = 0.299 * r + 0.587 * g + 0.114 * b
    if L < 70: return 92, 100, 132
    h, sat, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
    sat = min(sat * 1.6, 1.0); v = min(v * 1.15 + 0.1, 1.0)
    r2, g2, b2 = colorsys.hsv_to_rgb(h, sat, v)
    return int(r2 * 255), int(g2 * 255), int(b2 * 255)

# Grupos de caracteres por tono (de más claro a más oscuro). La elección dentro del grupo es fija por posición, así no parpadea.
GRUPOS = [(215, "@&$%WMB8"), (150, "OQ0GDUC"), (85, "oxcsaekn"), (45, "+=*:~i!"), (0, "#%H[]{}")]

def letra(r, g, b, al, x, y):
    if al < 110: return None
    L = 0.299 * r + 0.587 * g + 0.114 * b
    if al < 190:                                       # borde: gris claro alrededor del cuerpo, para marcar la silueta
        return (".", 190, 197, 215) if L < 90 else (random_char(".,'`;:", x, y),) + color(r, g, b)
    for minimo, chars in GRUPOS:
        if L > minimo: return (random_char(chars, x, y),) + color(r, g, b)

def random_char(chars, x, y):
    return chars[(x * 7 + y * 13 + (x * y) % 5) % len(chars)]

# Tamaños del texto de más grande a más pequeño (escala de cada línea). () = sin texto.
DISENOS = [(3, 2, 2), (2, 1, 1), (1, 1, 1), ()]
PRIORIDAD = 0.75      # el pingüino debe conservar al menos el 75 % del alto que tendría con la ventana entera

def plan(filas, cols):
    """Devuelve (alto del pingüino, escalas del texto). El pingüino tiene prioridad: primero se encoge el texto y, si ni así
    el pingüino llega al 75 % de su alto máximo, el texto desaparece y el pingüino ocupa todo lo que pueda."""
    tope = min(max(filas - 2, 6), max(int((cols - 2) / (2 * ASPECT)), 4))          # alto máximo posible (por filas y por ancho)
    for esc in DISENOS:
        if esc and any(len(t) * e > cols - 2 for (t, _, _), e in zip(LINEAS, esc)): continue    # el texto no cabe de ancho
        bajo = sum(esc) + 2 if esc else 0
        h = min(max(filas - bajo - 2, 4), tope)
        if not esc or h >= PRIORIDAD * tope: return h, esc
    return tope, ()

def dibujar():
    try: cols, filas = os.get_terminal_size()
    except OSError: cols, filas = 120, 40
    h, esc = plan(filas, cols)                               # alto del Tux y tamaño del texto (el Tux tiene prioridad)
    w = int(h * 2 * ASPECT)                                  # una celda mide ~1:2
    if w > cols - 2: w = cols - 2; h = max(int(w / (2 * ASPECT)), 4)
    im = base.convert("RGBa").resize((w, h), Image.LANCZOS).convert("RGBA")   # sin halos oscuros en los bordes
    px = im.load()
    total = h + (1 + sum(esc) if esc else 0); arriba = max((filas - total) // 2, 0); izq = (cols - w) // 2
    out = ["\x1b[2J\x1b[?25l"]
    for y in range(h):
        s = [f"\x1b[{arriba + y + 1};{izq + 1}H\x1b[1m"]
        for x in range(w):
            c = letra(*px[x, y], x, y)
            s.append(" " if c is None else f"\x1b[38;2;{c[1]};{c[2]};{c[3]}m{c[0]}")
        s.append("\x1b[0m"); out.append("".join(s))
    fila = arriba + h + 2                                    # texto normal, agrandado, centrado debajo del Tux
    for (t, est, _), e in zip(LINEAS, esc):
        col = max((cols - len(t) * e) // 2, 0) + 1
        out.append(f"\x1b[{fila};{col}H\x1b[{est}m\x1b]66;s={e};{t}\x1b\\\x1b[0m")
        fila += e
    sys.stdout.write("".join(out)); sys.stdout.flush()

if __name__ == "__main__":
  time.sleep(0.6)
  while True:
      if cambio[0]:
          cambio[0] = False; dibujar()
      time.sleep(0.2)
