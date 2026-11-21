# SPDX-License-Identifier: GPL-3.0-or-later
import os, pty, select, sys, time
# Muestra la revisión del actualizador y cancela antes de cambiar nada.
pid, fd = pty.fork()
if pid == 0:
    os.execv(os.path.expanduser('~/.local/bin/miarch-update'), ['miarch-update'])
buf = b''; t0 = time.time(); enviado = False
def leer(seg):
    global buf
    r, _, _ = select.select([fd], [], [], seg)
    if r:
        try: d = os.read(fd, 4096)
        except OSError: return False
        if not d: return False
        os.write(1, d); buf += d
    return True
while time.time() - t0 < 40:
    if not leer(0.2): break
    if not enviado and (b'[S/n]' in buf or b'Enter para cerrar' in buf):
        time.sleep(3.5)
        os.write(fd, b'n\n' if b'[S/n]' in buf else b'\n'); enviado = True
        t0 = time.time() - 25
time.sleep(2)
try: os.write(fd, b'\n')
except OSError: pass
