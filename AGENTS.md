# Instrucciones para agentes de IA (Miarch)

Este repositorio es **Miarch**: Arch Linux + Hyprland con un escritorio propio en Quickshell, que se instala con `setup.sh` y se actualiza con `miarch-update`.

## Cuando te pidan instalar, configurar u optimizar algo
Sigue la skill **`skills/instalar-configurar/SKILL.md`** (y sus archivos de `references/`). Resumen: busca la forma mejor y más ligera de hacerlo en Linux (un ajuste que ya existe, paquete oficial, AUR, Flatpak; mide cuando el consumo decide), pide permiso antes de `sudo`, deja el cambio donde sobreviva a las actualizaciones (`~/.config/miarch/personal/` o `packages.sh`) y comprueba de verdad que funciona (`skills/instalar-configurar/scripts/check.sh`).

## Reglas del proyecto
- GitFlow: ramas `feat/*` o `fix/*` desde `develop`, commits pequeños (Conventional Commits, sin líneas de atribución de IA), fusión con `--no-ff`. Nada de `--force` salvo que se pida expresamente.
- Versión (merge a `main` + etiqueta) solo para hitos grandes o si el usuario lo pide.
- Un cambio que el usuario note lleva una entrada corta en español al principio de `NOVEDADES.md`.
- `docs/paquetes/` debe coincidir con `packages.sh`.
- Paleta mate (sin neón); el navegador es solo Chrome; responde corto y en el idioma del usuario.
- Al probar, no toques las ventanas del usuario ni captures su pantalla: usa un escritorio vacío y recorta a tu propia ventana.
