# Novedades de Miarch

Una entrada por cosa importante, la más nueva arriba. La ventana de actualización (la nube de la barra) muestra las que aún no has visto.
Formato de cada título: `## AAAA-MM-DD.NN · Título` (el número NN sube dentro del mismo día).

## 2026-11-20.29 · La entrada suena a teclado
La secuencia de entrada elimina la línea blanca y despide la tarjeta de música con un desplazamiento suave. Mientras se teclea el log del sistema suenan pulsaciones de teclado mecánico.

## 2026-11-20.28 · Ajustes: pantallas
Nueva página en Ajustes para ver las pantallas conectadas con dibujo a escala, intercambiarlas de lado con un solo clic, elegir el monitor principal e identificarlas visualmente.

## 2026-11-20.27 · Crunchyroll en el lanzador
Crunchyroll ya está disponible en el lanzador de aplicaciones (`Super + Espacio`) en una ventana propia de Chrome con aceleración y Widevine. Inicia sesión con tu cuenta la primera vez.

## 2026-11-20.26 · Wi-Fi y Bluetooth más simples
Los paneles de Wi-Fi y Bluetooth ahora muestran de forma directa lo que hay cerca y lo que el equipo ya conoce, sin esconder dispositivos emparejados tras botones ni requerir formularios de red oculta.

## 2026-11-20.25 · Entrada sin luz blanca y sin la tarjeta de música encima
Al desbloquear o iniciar sesión se elimina el resplandor blanco que cubría la pantalla, y la tarjeta de música ahora se desvanece de inmediato para no tapar la animación de entrada.

## 2026-11-20.24 · Emparejamiento Bluetooth robusto
El panel de Bluetooth ya no deja colgado al servicio ni falla al emparejar dispositivos nuevos: ahora utiliza el script mediador `miarch-bluetooth` con un agente de BlueZ propio (`NoInputNoOutput`), asegurando y conectando el periférico en un solo flujo. Solo se permite un emparejamiento simultáneo, muestra "Emparejando…" mientras dura el proceso, cancela limpiamente si pasan 30 segundos sin respuesta y activa el modo emparejable del adaptador al abrir el panel.

## 2026-11-20.23 · Licencia GPL 3.0
El proyecto pasa a distribuirse bajo la licencia GPL-3.0-or-later. El código sigue siendo completamente abierto para usar y modificar, y las versiones derivadas que se distribuyan deberán mantenerse abiertas bajo esta misma licencia, con el código fuente disponible y conservando el aviso de autoría original.

## 2026-11-20.22 · Licencia Apache 2.0 y avisos de copyright
El repositorio se publica bajo licencia Apache-2.0: se incluye el archivo `NOTICE` con derechos de autor y atribución a componentes de terceros (iconos de LobeHub), identificadores SPDX en los scripts y configuraciones del sistema, y la sección de licencia en el README clarificando los términos y la titularidad de marcas registradas.

## 2026-11-20.20 · Apps Electron nítidas de inmediato en Wayland
ChatGPT (Codex App), Claude Desktop y Antigravity ahora se lanzan nítidas sobre Wayland nativo sin depender de reiniciar sesión: el menú de IA (Super + C) y las sobrescrituras de lanzadores (.desktop) para el menú de apps (Super + Espacio) pasan explícitamente `--ozone-platform=wayland --enable-wayland-ime`. Si ya tenías alguna abierta, solo ciérrala y vuelve a abrirla.

## 2026-11-20.19 · Reintentos y tolerancia a cortes de red en Hermes Desktop
La instalación de Hermes Desktop en `packages.sh` ahora aguanta cortes temporales de red: antes de lanzar el instalador comprueba la conectividad con el servidor de assets (hasta 4 intentos con espera de 15 s) y reintenta la instalación hasta 3 veces (con pausas de 20 s), avisando y posponiendo el reintento para la siguiente actualización sin romper el proceso.

## 2026-11-20.18 · Aplicaciones Electron y XWayland nítidas
Las aplicaciones de Electron y Chromium (VS Code, Claude Desktop, ChatGPT, Antigravity) ya no se ven borrosas ni pixeladas en pantallas con escala: ahora corren en Wayland nativo con flags dedicados y las que usen XWayland aprovechan el escalado nítido con `force_zero_scaling`.

## 2026-11-20.17 · Steam y juegos opcionales
Steam y las herramientas de juego ahora son opcionales: al instalar con `setup.sh` se pregunta si se desean instalar, y en cualquier momento se pueden omitir con `touch ~/.config/miarch/sin-juegos`, evitando la instalación de Steam, multilib y controladores adicionales.

## 2026-11-20.16 · Entrada limpia después del login
Al terminar la animación del inicio de sesión, la consola de texto que aparecía unos instantes (con el cursor parpadeando y texto de arranque) ahora sale en negro y sin cursor; el texto de arranque va al registro `~/.cache/miarch/sesion.log`.

## 2026-11-20.15 · Miarch 1.0
Primera versión estable. Reúne todo lo de estos días: menú de IA (Super + C), Steam y juegos, Wi-Fi completo, notificaciones nuevas, barra de volumen con sonido, pantalla de inicio de sesión propia, bloqueo y entrada de cine con firma, actualizador más robusto y la skill para agentes de IA.

## 2026-11-20.14 · Revisión del actualizador
Se corrigieron varios fallos del actualizador: Ollama ya no se rompe cuando sus modelos van a /home, Docker no esconde los datos que ya tiene, el instalador del login no se detiene si el fondo anotado desapareció, y el escritorio se recarga al final (con los paquetes ya actualizados) en vez de al principio.

## 2026-11-20.13 · Actualizador más robusto
El actualizador ya no se llena de avisos cuando un instalador (como el de Hermes) imprime caracteres raros, mantiene viva la contraseña de administrador mientras compila apps largas y corta el instalador de Hermes si pasa media hora sin terminar. También se cerró un fallo del bloqueo: si te autenticabas y se volvía a bloquear durante la animación, se podía desbloquear sin contraseña.

## 2026-11-20.12 · Barra de volumen sencilla
El volumen ya no usa una notificación (se quedaba pegada): ahora sale una barra pequeña abajo, sin animación, que se actualiza al pulsar y se va sola al segundo.

## 2026-11-20.11 · Arreglo: las teclas de volumen
Las teclas de volumen dejaron de funcionar con el cambio del pitido: Hyprland no encuentra los scripts sin su ruta completa. Ya suben, bajan y silencian otra vez.

## 2026-11-20.10 · Pantalla de inicio de sesión por defecto
Al actualizar (y en una instalación nueva), Miarch instala la pantalla de inicio de sesión gráfica con el estilo del bloqueo, para que al reiniciar no salga la terminal. Si falla, sigues entrando por la terminal. Si no la quieres: `touch ~/.config/miarch/sin-greeter`.

## 2026-11-20.09 · Sonido al subir y bajar el volumen
Las teclas de volumen ahora hacen un pitido corto y muestran una barra de volumen que se actualiza sin apilarse. En silencio no suena.

## 2026-11-20.08 · Desbloquear e iniciar sesión como en una película
Al desbloquear (y al iniciar sesión) se hace una secuencia de cine de unos 5,6 segundos: aparecen barras negras arriba y abajo, el fondo avanza despacio, sale el título MIARCH con las letras muy separadas, un destello de luz horizontal cruza la pantalla y todo se aclara suavemente hasta entrar a tu escritorio. Debajo del título aparece la firma "by alejandro-xoxo". Al desbloquear suena una música de tráiler (graves que crecen, un golpe y una cola larga) y se teclea el log real del sistema.

## 2026-11-20.06 · Notificaciones nuevas y menú de IA solo con apps
Las notificaciones ahora las dibuja el propio escritorio: salen deslizándose arriba a la derecha, con el estilo de los paneles, icono, nombre de la app, barra de progreso (volumen, brillo), botones de acción y una cuenta atrás que se pausa si pones el ratón encima. Las críticas se marcan en rojo mate y no se van solas. Clic cierra una, clic derecho las cierra todas. Miarch quita `dunst`, que ya no hace falta.
El menú de IA (Super + C) ahora es solo para apps de escritorio: Claude Desktop, Codex App, Antigravity y Hermes Desktop. Antigravity y Codex App se instalan al actualizar.

## 2026-11-20.05 · Menú de IA por niveles y solo lo que está a tu alcance
En el menú de IA (Super + C) eliges una herramienta y, si tiene varias formas de abrirse, salen sus opciones: Claude Code (terminal) o Claude Desktop, Codex CLI o la app de Codex (nueva, se instala al actualizar). Wi-Fi y Bluetooth ya no llenan la lista con redes o dispositivos guardados que no están cerca; en Bluetooth hay un botón para verlos.

## 2026-11-20.04 · Wi-Fi más despejado y menú de IA con logos
El panel de Wi-Fi tiene más aire: redes separadas en Conectada, Guardadas y Disponibles, con una línea que dice su estado; "Olvidar" aparece al pasar el ratón. Apagar el Wi-Fi y olvidar una red ahora se comprueban de verdad y no se pierden si pulsas rápido. En el menú de IA (Super + C) cada herramienta lleva su logo y una etiqueta APP o TERMINAL.

## 2026-11-20.03 · Menú de IA con Super + C
Super + C abre un menú solo con herramientas de IA: Claude Desktop y Claude en terminal, Antigravity, Codex, Hermes Desktop y Ollama. Las que no tengas instaladas salen apagadas.

## 2026-11-20.02 · Wi-Fi más completo
En el panel de Wi-Fi ahora puedes desconectar, olvidar redes (también las guardadas que están fuera de alcance), conectar a una red oculta y escribir la contraseña nueva si una red guardada la cambió. Cada acción avisa si falla.

## 2026-11-20.01 · Hermes Desktop, app de Ollama y limpieza
Al actualizar, Miarch desinstala paquetes que ya no recomienda (ahora, la ventana de Hermes WebUI, que no era la app oficial de Hermes) y la nube avisa si hay alguno pendiente.
Nuevo: Hermes Desktop (la app oficial) se instala al actualizar. Ollama no tiene app oficial para Linux (solo terminal y servicio), así que Miarch no instala clientes de terceros.

## 2026-11-19.13 · Skill para tu agente de IA
Si usas Claude Code, Codex o Antigravity, Miarch le instala una skill que le enseña a instalar y configurar cosas en tu sistema
de la mejor forma posible (la opción más ligera y nativa, midiendo cuando importa) y a dejar los cambios donde las actualizaciones no los borran.

## 2026-11-19.12 · Tus cambios personales no se pierden
Hay una carpeta solo tuya (~/.config/miarch/personal) para atajos, reglas, terminal y shell: ninguna actualización la borra.
Y cambiar algo en Ajustes ya no impide actualizar.

## 2026-11-19.11 · Pestaña de atajos en el menú de energía
Super + Shift + Esc ahora tiene dos pestañas: Energía y Atajos. Atajos lista todos los atajos de teclado, de más a menos útil, con lo que hace cada uno.

## 2026-11-19.10 · La actualización explica qué trae
Antes de pedirte confirmar, la ventana de actualización muestra en español qué trae cada novedad y qué partes de tu equipo cambian.
Verás solo lo que aún no has visto; las novedades se escriben en este archivo (NOVEDADES.md).

## 2026-11-19.09 · La nube cuenta configuraciones y paquetes pendientes
La nube de la barra ahora cuenta también las configuraciones de Miarch que tu equipo aún no tiene y los paquetes de Miarch que faltan,
no solo los cambios de GitHub y las actualizaciones del sistema.

## 2026-11-19.08 · Arreglos en la ventana de actualización
El indicador ya no repite el mensaje en ventanas estrechas. La duración del resumen ya no se acumula entre actualizaciones.
Se detectan configuraciones del repositorio que tu equipo aún no tiene (por ejemplo las de GameMode y MangoHud).

## 2026-11-19.07 · Steam y juegos (GameMode, MangoHud, FSR)
Se instala Steam con los controladores Vulkan de tu tarjeta, GameMode (sube el rendimiento mientras juegas), MangoHud (FPS y temperaturas),
Gamescope (reescalado FSR para gráficas integradas) y ProtonUp-Qt. Guía y opciones de lanzamiento en docs/juegos.md.

## 2026-11-19.06 · Chrome sigue el tema oscuro
Nuevo comando miarch-chrome-tema: quita un tema de color propio de Chrome (por ejemplo uno rojo que se ve marrón).
El sistema ahora avisa a Chrome de que es oscuro.

## 2026-11-19.05 · El actualizador revisa primero
Antes de hacer nada muestra qué hay pendiente (cambios de Miarch, paquetes que faltan, actualizaciones del sistema)
y pide una sola confirmación. Si no hay nada, lo dice y termina.

## 2026-11-19.04 · Instalación con aspecto nuevo
Los scripts tienen logo animado, barra del avance total, resultados con su duración y un resumen final, con la paleta morada del portafolio.

## 2026-11-19.03 · Menú de energía (Super + Shift + Esc)
Super + Shift + Esc abre un menú para bloquear, suspender, cerrar sesión, reiniciar y apagar. Super + Esc abre los Ajustes.

## 2026-11-19.02 · Actualizar con un clic en la nube
La nube de la barra avisa cuando hay novedades y, al hacer clic, las descarga y las aplica conservando tus ajustes y tu fondo.
