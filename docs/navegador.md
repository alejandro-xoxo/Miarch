# Navegador: por qué Chrome

Miarch usa **Google Chrome** (`Super + B`). Antes de decidirlo se midió contra Chromium y Firefox en el equipo de pruebas (Intel Core i5 de 8.ª generación): las mismas 6 páginas (Wikipedia, archlinux.org, kernel.org, wiki de Hyprland, Hacker News, mozilla.org), perfil nuevo y sin extensiones, esperando 110 s a que se asentara. La RAM es **PSS** (memoria real, sin contar dos veces lo compartido entre procesos); la CPU es en reposo.

| Navegador | Procesos | RAM real | CPU en reposo |
|---|---|---|---|
| **Google Chrome** (AUR) | 17 | **488 MB** | 2,1 % de un núcleo |
| Chromium (repos oficiales) | 15 | 600 MB | 2,0 % |
| Firefox (repos oficiales) | 19 | 1038 MB | 10,2 % |

- **Chrome** fue el que menos RAM usó y, con Chromium, el de menos CPU. Su aislamiento entre sitios es además el más maduro. Contra: viene de AUR (el paquete descarga el instalador oficial de Google y no está firmado por Arch).
- **Chromium** gasta ~110 MB más pero está en los repos oficiales (firmado por Arch). Si prefieres eso, cambia `google-chrome` por `chromium` en `packages.sh` y `google-chrome-stable` por `chromium` en `config/hypr/hyprland.lua`.
- **Firefox** gastó el doble de RAM y cinco veces más CPU en esta prueba. Es más privado, pero no más liviano aquí.

Es una prueba con 6 pestañas y un perfil limpio: con extensiones, muchas pestañas o páginas pesadas (por ejemplo Teams) los números cambian. Lo que más consume en el día a día son esas páginas, no el navegador.
