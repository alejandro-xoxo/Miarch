# Tareas pendientes para agy (hoja de instrucciones)

Ejecuta esto con agy desde ~/Miarch, aprobando cada acción cuando te la pida. Haz las tareas EN ORDEN. Al terminar cada una, di en una línea qué hiciste y qué no pudiste probar.

## Reglas del proyecto (obligatorias)
- GitFlow: rama `feat/*` o `fix/*` desde `develop`, commits pequeños con Conventional Commits en inglés, fusión con `git merge --no-ff`, luego `git push origin develop`. Nada de `--force`.
- NUNCA pongas marcas de IA en commits: ni `Co-Authored-By`, ni "Generated with", ni mencionar herramientas de IA en el mensaje. El commit debe parecer escrito por el usuario.
- Cada cambio que el usuario note lleva una entrada nueva en español al principio de `NOVEDADES.md` (formato `## AAAA-MM-DD.NN · Título`, el NN sube; la más nueva arriba; 1-3 líneas).
- `docs/paquetes/` debe coincidir con `packages.sh`.
- No hagas release (no merge a `main`, no etiquetas nuevas) salvo que el usuario lo pida.
- No captures la pantalla del usuario.
- Respuestas y textos de la interfaz en español.

## Tarea 1 — Borrar las 14 etiquetas viejas (el usuario ya lo aprobó)
Borrar: v0.2.0 v0.3.0 v0.3.1 v0.3.2 v0.3.3 v0.3.4 v0.3.5 v0.3.6 v0.3.7 v0.4.0 v0.6.0 v0.6.1 v0.7.0 v0.8.0.
Conservar: v0.1.0 v0.5.0 v0.9.0 v0.9.1 v0.9.2 v0.9.3 v0.9.4 v0.9.5 v1.0.0.
1. Antes, guarda la lista `nombre -> commit` en `~/.cache/miarch/tags-borradas.txt`.
2. Borra en local (`git tag -d`) y en remoto (`git push origin :refs/tags/NOMBRE`).
3. Comprueba con `git ls-remote --tags origin` que solo quedan las que se conservan.

## Tarea 2 — Subir la skill workflow-orquestar al repositorio de skills del usuario
Repositorio: https://github.com/alejandro-xoxo/agent-skills (rama `develop`).
1. Clónalo en una carpeta temporal nueva (NO dentro de ~/Miarch). Usa la identidad de git de ~/Miarch (`git -C ~/Miarch config user.name` y `user.email`) solo en ese clon.
2. Copia desde `~/.claude/skills/workflow-orquestar/` los archivos `wf.py`, `selftest.py` y `SKILL.md` a `skills/workflow-orquestar/` del clon. No toques otras skills.
3. Ejecuta `python3 selftest.py` en esa carpeta; deben pasar todas las pruebas.
4. Rama `feat/workflow-agy-codex-medio` desde `develop`; commit `feat(workflow-orquestar): default to agy then codex at medium effort`; fusiona con `--no-ff` en `develop` y `git push origin develop`.
Resumen de lo que cambió en la skill: el orden por defecto de trabajadores es agy y luego codex (opencode es opcional con `WF_WORKERS`), el nivel por defecto es medio (`gemini-3.8-flash-medium` en agy; esfuerzo `medium` en codex con `-c model_reasoning_effort`), y el valor de codex por nivel es `modelo:esfuerzo` (por ejemplo `default:medium`).

## Tarea 3 — Steam y juegos opcionales
Hoy `packages.sh` instala siempre Steam y las herramientas de juego. Hazlo opcional con una marca, igual que `sin-greeter`:
1. Si existe `~/.config/miarch/sin-juegos`, `packages.sh` NO instala la lista `JUEGOS`, ni `gpu_juegos`, ni `habilitar_multilib`, ni `configurar_juegos`. Ajusta también `--faltantes` (que no pida esos paquetes), `--sobran` si hace falta y `--etapas` (el número de etapas debe seguir siendo exacto).
2. En `setup.sh`, antes de instalar, si hay terminal y no existe ni `sin-juegos` ni un archivo `~/.config/miarch/juegos-decidido`, pregunta "¿Instalar Steam y las herramientas para jugar? [S/n]"; con "n" crea `sin-juegos`. En ambos casos crea `juegos-decidido`. Sin terminal, no preguntes y deja el comportamiento actual (instalar).
3. `miarch-update` no debe ofrecer instalar los paquetes de juegos si existe `sin-juegos` (ya lo hará `--faltantes`; compruébalo).
4. Documenta en `docs/instalacion.md`, `docs/personalizar.md` (tabla "Cosas que puedes apagar") y `docs/juegos.md`; añade entrada en `NOVEDADES.md`.
5. Pruébalo en un entorno aislado: HOME temporal y `sudo`/`pacman`/`yay` simulados con scripts que solo hacen `exit 0`. Comprueba `bash packages.sh --faltantes` y `--etapas` con y sin la marca. No instales nada real.

## Tarea 4 — Preparar el script de capturas (sin ejecutarlo)
`scripts/tomar-capturas` toma las capturas del README en un escritorio vacío. Añade capturas de: el menú de IA (`qs -c miarch ipc call ia open`), una notificación de ejemplo (`notify-send`) y la barra de volumen (`qs -c miarch ipc call osd mostrar 60 "60%" 0`), guardándolas como `docs/screenshots/menu-ia.jpg`, `notificaciones.jpg` y `volumen.jpg`. NO ejecutes el script (el usuario lo hará él mismo). No cambies el README para referenciar imágenes que aún no existen. Explica el uso en `docs/capturas.md`.

## Al final
Haz `git status` y `git log --oneline -8` y muestra el resultado. Comprueba que `bash -n` pasa en todos los scripts modificados.
