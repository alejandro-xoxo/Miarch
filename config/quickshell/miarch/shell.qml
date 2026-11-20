// Miarch · escritorio propio con Quickshell
// v1: sin barra. Reloj grande + anillos de datos sobre el wallpaper. Colores mate.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

ShellRoot {
    id: root

    // ── Paleta mate: sale del wallpaper (miarch-colors) y cambia con transición suave ──
    property color arenaBase: "#cfc6b4"
    property color arena:     contrasteAlto ? (claro ? "#0a0a0a" : "#fafafa") : arenaBase
    property real esc: 1.0
    property bool contrasteAlto: false
    property color salvia:    "#8c9c88"
    property color terracota: "#b97b62"
    property color pizarra:   "#7d8aa0"
    property color fondo:     "#12141a"
    Behavior on arena     { ColorAnimation { duration: 300 } }
    Behavior on salvia    { ColorAnimation { duration: 300 } }
    Behavior on terracota { ColorAnimation { duration: 300 } }
    Behavior on pizarra   { ColorAnimation { duration: 300 } }
    Behavior on fondo     { ColorAnimation { duration: 300 } }
    property bool claro: false
    readonly property color pista: claro ? Qt.rgba(0, 0, 0, 0.13) : Qt.rgba(1, 1, 1, 0.09)
    readonly property string fuente: "JetBrainsMono Nerd Font"
    // Modo demo (solo para capturas de pantalla): MIARCH_DEMO=1 qs -c miarch  → oculta el nombre de tu red
    readonly property bool demo: Quickshell.env("MIARCH_DEMO") === "1"

    FileView {
        id: fColores
        path: Quickshell.env("HOME") + "/.cache/miarch/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const c = JSON.parse(text())
                root.arenaBase = c.arena; root.salvia = c.salvia; root.terracota = c.terracota
                root.pizarra = c.pizarra; root.fondo = c.fondo; root.claro = c.claro === true
            } catch (e) { console.warn("colors.json inválido:", e) }
        }
    }

    // ── Datos del sistema (0..1) ──
    property real cpu: 0
    property real ram: 0
    property real bateria: 0
    property bool cargando: false
    property var _cpuPrev: null

    SystemClock { id: reloj; precision: SystemClock.Minutes }

    FileView {
        id: fStat; path: "/proc/stat"
        onLoaded: {
            const p = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number)
            const idle = p[3] + p[4]
            const total = p.reduce((a, b) => a + b, 0)
            if (root._cpuPrev) {
                const v = 1 - (idle - root._cpuPrev.idle) / Math.max(1, total - root._cpuPrev.total)
                const q = Math.round(v * 50) / 50            // pasos del 2 %: el anillo no se mueve por ruido
                if (q !== root.cpu) root.cpu = q
            }
            root._cpuPrev = { idle: idle, total: total }
        }
    }
    FileView {
        id: fMem; path: "/proc/meminfo"
        onLoaded: {
            const t = text()
            const total = Number(/MemTotal:\s+(\d+)/.exec(t)[1])
            const disp  = Number(/MemAvailable:\s+(\d+)/.exec(t)[1])
            const q = Math.round((1 - disp / total) * 100) / 100
            if (q !== root.ram) root.ram = q
        }
    }
    FileView { id: fBat; path: "/sys/class/power_supply/BAT0/capacity"; onLoaded: root.bateria = Number(text()) / 100 }
    FileView { id: fSt;  path: "/sys/class/power_supply/BAT0/status";   onLoaded: root.cargando = text().trim() === "Charging" }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { fStat.reload(); fMem.reload(); fBat.reload(); fSt.reload() }
    }

    // ── Una ventana de fondo por monitor ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "miarch-escritorio"

            Item {
                id: lienzo
                anchors.fill: parent

                // Todo el bloque entra deslizando con rebote
                property real entrada: 0
                Component.onCompleted: entrada = 1
                Behavior on entrada { NumberAnimation { duration: 1400; easing.type: Easing.OutQuint } }

                Column {
                    id: bloque
                    x: parent.width * 0.05
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: (1 - lienzo.entrada) * 60
                    opacity: Math.min(1, lienzo.entrada)
                    spacing: 6

                    // Hora y fecha, con sombra suave. Solo se redibujan cuando cambia el minuto.
                    Column {
                        spacing: 6
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: root.claro ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.6)
                            shadowBlur: 0.8
                            shadowVerticalOffset: 2
                            shadowHorizontalOffset: 0
                        }

                        // Hora
                        Text {
                            text: Qt.formatDateTime(reloj.date, "HH:mm")
                            color: root.arena
                            font { family: root.fuente; pixelSize: Math.round(lienzo.height * 0.12); weight: Font.Thin }
                            renderType: Text.NativeRendering
                        }
                        // Fecha
                        Text {
                            text: Qt.locale("es_CO").toString(reloj.date, "dddd d 'de' MMMM").toUpperCase()
                            color: root.terracota
                            font { family: root.fuente; pixelSize: Math.round(lienzo.height * 0.024); weight: Font.Medium; letterSpacing: 6 }
                            leftPadding: 6
                        }
                    }
                    Item { width: 1; height: lienzo.height * 0.05 }

                    // Anillos
                    Row {
                        spacing: lienzo.height * 0.045
                        leftPadding: 4
                        Anillo { etiqueta: "CPU"; valor: root.cpu;     color: root.pizarra;   tam: lienzo.height * 0.13 }
                        Anillo { etiqueta: "RAM"; valor: root.ram;     color: root.salvia;    tam: lienzo.height * 0.13 }
                        Anillo { etiqueta: root.cargando ? "CARGA" : "BAT"; valor: root.bateria; color: root.terracota; tam: lienzo.height * 0.13 }
                    }
                }

                // ── Música: aparece sola cuando hay un reproductor (Spotify, el navegador…) ──
                Item {
                    id: musica
                    readonly property var p: root.jugador
                    readonly property real avance: (p && p.length > 0) ? Math.min(1, p.position / p.length) : 0
                    x: bloque.x
                    y: bloque.y + bloque.height + lienzo.height * 0.045 + (1 - opacity) * 14
                    width: Math.min(lienzo.width * 0.32, 480)
                    height: 92
                    opacity: p ? Math.min(1, lienzo.entrada) : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                    Rectangle {   // velo suave: la letra se lee sobre cualquier fondo
                        x: -14; y: -10; width: parent.width + 28; height: parent.height + 20
                        radius: 14
                        color: Qt.alpha(root.fondo, 0.5)
                        Behavior on color { ColorAnimation { duration: 300 } }
                    }

                    // la posición no se actualiza sola: se pide una vez por segundo, y solo mientras suena
                    Timer {
                        running: musica.visible && musica.p !== null && musica.p.isPlaying
                        interval: 1000; repeat: true
                        onTriggered: musica.p.positionChanged()
                    }

                    Rectangle {   // portada
                        id: portada
                        width: 92; height: 92
                        color: Qt.alpha(root.arena, 0.08)
                        border.width: 1; border.color: Qt.alpha(root.arena, 0.15)
                        Image {
                            id: imgPortada
                            anchors.fill: parent
                            source: musica.p ? root.portadaGrande(musica.p.trackArtUrl) : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true
                            // calidad: se decodifica al doble de lo que se ve y la GPU la reduce con mipmaps
                            // (antes: 160 px reducidos a ~97 sin suavizar → bordes dentados)
                            sourceSize.width: 400; sourceSize.height: 400
                            smooth: true; mipmap: true
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: imgPortada.status !== Image.Ready
                            text: ""
                            color: Qt.alpha(root.arena, 0.4)
                            font { family: root.fuente; pixelSize: 26 * root.esc }
                        }
                    }
                    Column {
                        x: portada.width + 18
                        width: parent.width - x
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: musica.p ? (musica.p.trackTitle || "Sin título") : ""
                            color: root.arena
                            opacity: (musica.p && musica.p.isPlaying) ? 1 : 0.55
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            font { family: root.fuente; pixelSize: 17 * root.esc; weight: Font.Medium }
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: musica.p ? (musica.p.trackArtist || "").toUpperCase() : ""
                            color: root.terracota
                            font { family: root.fuente; pixelSize: 11 * root.esc; weight: Font.Medium; letterSpacing: 3 }
                        }
                        Item {   // barra de progreso (clic para saltar)
                            width: parent.width; height: 14
                            Rectangle {
                                y: 6; width: parent.width; height: 3; radius: 1.5; color: Qt.alpha(root.arena, 0.22)
                                Rectangle { width: parent.width * musica.avance; height: parent.height; radius: 1.5; color: root.terracota }
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: musica.p !== null && musica.p.canSeek
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: mouse => { musica.p.position = (mouse.x / width) * musica.p.length; musica.p.positionChanged() }
                            }
                        }
                        Row {
                            spacing: 18
                            Repeater {
                                model: [ { g: "", a: "previous" }, { g: "play", a: "toggle" }, { g: "", a: "next" } ]
                                Text {
                                    required property var modelData
                                    text: modelData.g === "play" ? ((musica.p && musica.p.isPlaying) ? "" : "") : modelData.g
                                    color: modelData.a === "toggle" ? root.terracota : Qt.alpha(root.arena, 0.8)
                                    font { family: root.fuente; pixelSize: 14 * root.esc }
                                    MouseArea {
                                        anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (!musica.p) return
                                            if (modelData.a === "toggle") musica.p.togglePlaying()
                                            else if (modelData.a === "next") musica.p.next()
                                            else musica.p.previous() }
                                    }
                                }
                            }
                            Item { width: 6; height: 1 }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: musica.p ? (root.fmtTiempo(musica.p.position) + " / " + root.fmtTiempo(musica.p.length)) : ""
                                color: Qt.alpha(root.arena, 0.5)
                                font { family: root.fuente; pixelSize: 11 * root.esc; weight: Font.Light }
                            }
                        }
                    }
                }
            }
        }
    }

    // ═════════════════ BARRA ═════════════════
    property int actualizaciones: 0
    property string wifiNombre: ""
    property bool wifiConectado: false

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var salida: Pipewire.defaultAudioSink
    readonly property real volumen: salida && salida.audio ? salida.audio.volume : 0
    readonly property bool silenciado: salida && salida.audio ? salida.audio.muted : false
    // El reproductor que está sonando; si ninguno suena, el primero (Spotify, navegador, etc.)
    readonly property var jugador: {
        const v = Mpris.players.values
        return v.find(x => x.isPlaying) || v[0] || null
    }
    // Spotify publica la misma portada en 64, 300 y 640 px (solo cambia el prefijo del identificador).
    // Se pide siempre la de 640 para que nunca se vea pixelada al agrandarla.
    function portadaGrande(url) {
        return (url || "").replace(/(i\.scdn\.co\/image\/)ab67616d0000(?:4851|1e02)/, "$1ab67616d0000b273")
    }
    function fmtTiempo(seg) {
        seg = Math.max(0, Math.floor(seg || 0))
        return Math.floor(seg / 60) + ":" + String(seg % 60).padStart(2, "0")
    }
    readonly property var adaptadorBt: Bluetooth.defaultAdapter

    // actualizaciones pendientes = repos oficiales (checkupdates) + AUR (yay -Qua; checkupdates no cuenta AUR)
    Process {
        id: pActualiz
        command: ["sh", "-c", "o=$(if command -v checkupdates >/dev/null; then checkupdates 2>/dev/null | wc -l; else pacman -Qu 2>/dev/null | wc -l; fi); a=0; command -v yay >/dev/null && a=$(timeout 40 yay -Qua 2>/dev/null | wc -l); echo $((o + a))"]
        stdout: StdioCollector { onStreamFinished: root.actualizaciones = parseInt(text.trim()) || 0 }
    }
    Timer { interval: 1200000; running: true; repeat: true; triggeredOnStart: true; onTriggered: pActualiz.running = true }

    // Pendientes de Miarch (lo mismo que revisa miarch-update): commits nuevos en GitHub + configuraciones sin aplicar + paquetes que
    // faltan. Se revisa una vez al encender el sistema (y se reintenta si aún no hay internet).
    // El clic en la nube abre miarch-update, que los baja y los aplica.
    property int cambiosRepo: 0
    property int _intentosRepo: 0
    readonly property int pendientes: root.actualizaciones + root.cambiosRepo
    Process {
        id: pRepo
        command: ["sh", "-c", "d=\"${MIARCH_DIR:-$HOME/Miarch}\"; [ -d \"$d/.git\" ] || { echo 0; exit; }; " +
                  "git -C \"$d\" fetch -q origin 2>/dev/null || { echo x; exit; }; " +
                  "u=$(git -C \"$d\" rev-parse -q --verify '@{u}' 2>/dev/null || echo \"origin/$(git -C \"$d\" rev-parse --abbrev-ref HEAD)\"); " +
                  "n=$(git -C \"$d\" rev-list --count \"HEAD..$u\" 2>/dev/null || echo 0); " +
                  // configuraciones del repo aún sin aplicar en este equipo (miarch-update guarda el commit que aplicó)
                  "c=1; m=$(cat \"$HOME/.cache/miarch/configs-aplicadas\" 2>/dev/null); " +
                  "[ -n \"$m\" ] && git -C \"$d\" cat-file -e \"$m^{commit}\" 2>/dev/null && " +
                  "git -C \"$d\" diff --quiet \"$m\" HEAD -- config scripts home lib install.sh setup.sh packages.sh skills AGENTS.md && c=0; " +
                  // paquetes de Miarch que faltan en este equipo
                  "f=0; grep -q -- --faltantes \"$d/packages.sh\" 2>/dev/null && f=$(bash \"$d/packages.sh\" --faltantes 2>/dev/null | grep -c .); " +
                  // paquetes que Miarch ya no usa y siguen instalados (se quitan al actualizar)
                  "s=0; grep -q -- --sobran \"$d/packages.sh\" 2>/dev/null && s=$(bash \"$d/packages.sh\" --sobran 2>/dev/null | grep -c .); " +
                  // pantalla de inicio de sesión de Miarch (greetd) aún sin instalar, salvo que se haya rechazado
                  "g=0; [ -e \"$HOME/.config/miarch/sin-greeter\" ] || [ \"$(systemctl is-enabled greetd 2>/dev/null)\" = enabled ] || g=1; " +
                  "echo $((n + c + f + s + g))"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                if (t === "x") { if (root._intentosRepo < 5) tReintentoRepo.restart(); return }   // sin internet todavía
                const n = parseInt(t) || 0
                if (n > 0 && root.cambiosRepo === 0)
                    Quickshell.execDetached(["sh", "-c", "command -v notify-send >/dev/null && notify-send -a Miarch 'Miarch tiene novedades' 'Haz clic en la nube de la barra para revisarlas y aplicarlas.'"])
                root.cambiosRepo = n
            }
        }
    }
    Timer { id: tInicioRepo; interval: 20000; running: true; onTriggered: { root._intentosRepo++; pRepo.running = true } }
    Timer { id: tReintentoRepo; interval: 60000; onTriggered: { root._intentosRepo++; pRepo.running = true } }

    Process {
        id: pWifi
        command: ["sh", "-c", "iwctl station wlan0 show 2>/dev/null | sed 's/\\x1b\\[[0-9;]*m//g' | awk '/Connected network/ { sub(/.*Connected network[ ]+/, \"\"); print }'"]
        stdout: StdioCollector {
            onStreamFinished: { root.wifiNombre = text.trim(); root.wifiConectado = root.wifiNombre.length > 0 }
        }
    }
    Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: pWifi.running = true }

    function lanzar(cmd) { Quickshell.execDetached(cmd) }
    function irAEscritorio(n) { Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + n + " })"]) }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: 46
            color: "transparent"
            WlrLayershell.namespace: "miarch-barra"

            Item {
                id: barra
                anchors.fill: parent
                property real entrada: 0
                Component.onCompleted: entrada = 1
                Behavior on entrada { NumberAnimation {
                    duration: root.animBarra === "ninguna" ? 0 : (root.animBarra === "fundido" ? 900 : 1000)
                    easing.type: root.animBarra === "rebote" ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: 1.5
                } }

                opacity: Math.min(1, barra.entrada)
                transform: Translate { y: (root.animBarra === "deslizar" || root.animBarra === "rebote") ? (1 - barra.entrada) * -40 : 0 }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.claro ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(0, 0, 0, 0.6)
                    shadowBlur: 0.7
                    shadowVerticalOffset: 1
                }

                // ── Izquierda: escritorios con indicador que se desliza ──
                Item {
                    id: escritorios
                    x: parent.width * 0.025
                    anchors.verticalCenter: parent.verticalCenter
                    height: 30; width: 5 * 30
                    readonly property int activo: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1

                    Rectangle {
                        id: marca
                        y: parent.height - 3
                        width: 16; height: 3; radius: 2
                        color: root.terracota
                        x: (escritorios.activo - 1) * 30 + 7
                        visible: escritorios.activo >= 1 && escritorios.activo <= 5
                        Behavior on x { NumberAnimation {
                            duration: root.animBarra === "ninguna" ? 0 : 420
                            easing.type: root.animBarra === "rebote" ? Easing.OutBack : Easing.OutCubic
                            easing.overshoot: 1.8
                        } }
                        Behavior on color { ColorAnimation { duration: 800 } }
                    }
                    Repeater {
                        model: 5
                        Item {
                            required property int index
                            readonly property int n: index + 1
                            readonly property bool ocupado: Hyprland.workspaces.values.some(w => w.id === n)
                            x: index * 30; width: 30; height: 30
                            Text {
                                anchors.centerIn: parent
                                text: n
                                color: escritorios.activo === n ? root.arena : Qt.alpha(root.arena, ocupado ? 0.6 : 0.28)
                                font { family: root.fuente; pixelSize: 15 * root.esc; weight: escritorios.activo === n ? Font.Medium : Font.Light }
                                scale: (escritorios.activo === n && root.animBarra === "rebote") ? 1.18 : 1
                                Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: 300 } }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.irAEscritorio(n) }
                        }
                    }
                }

                // ── Derecha: módulos ──
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: parent.width * 0.025
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 26

                    Modulo {   // música
                        visible: root.jugador !== null
                        icono: ""; acento: root.arena
                        texto: root.jugador ? (root.jugador.trackTitle || "") .substring(0, 28) : ""
                        atenuado: root.jugador ? !root.jugador.isPlaying : false
                        onClic: if (root.jugador) root.jugador.togglePlaying()
                        onClicDerecho: if (root.jugador) root.jugador.next()
                    }
                    Modulo {   // actualizaciones
                        icono: ""; acento: root.pendientes > 0 ? root.terracota : root.arena
                        texto: root.pendientes.toString()
                        atenuado: root.pendientes === 0
                        onClic: root.lanzar(["kitty", "--class", "miarch-update", Quickshell.env("HOME") + "/.local/bin/miarch-update"])
                        onClicDerecho: root.lanzar(["kitty", "--class", "miarch-update", Quickshell.env("HOME") + "/.local/bin/miarch-update", "--forzar"])
                    }
                    Modulo {   // bluetooth
                        icono: ""
                        acento: root.arena
                        readonly property var conectados: root.adaptadorBt ? root.adaptadorBt.devices.values.filter(d => d.connected) : []
                        texto: conectados.length > 0 ? (conectados[0].name || conectados[0].deviceName || "") : ""
                        atenuado: !(root.adaptadorBt && root.adaptadorBt.enabled)
                        onClic: root.abrirConexiones("bt")
                    }
                    Modulo {   // wifi
                        icono: ""; acento: root.arena
                        texto: root.wifiConectado ? (root.demo ? "Mi red" : root.wifiNombre.substring(0, 16)) : "sin red"
                        atenuado: !root.wifiConectado
                        onClic: root.abrirConexiones("wifi")
                    }
                    Modulo {   // volumen
                        icono: root.silenciado ? "" : ""; acento: root.arena
                        texto: Math.round(root.volumen * 100) + "%"
                        atenuado: root.silenciado
                        onClic: root.lanzar(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                        onRueda: dir => root.lanzar(["wpctl", "set-volume", "-l", "1", "@DEFAULT_AUDIO_SINK@", dir > 0 ? "5%+" : "5%-"])
                    }
                    Modulo {   // batería
                        icono: root.cargando ? "" : (root.bateria > 0.85 ? "" : root.bateria > 0.6 ? "" : root.bateria > 0.35 ? "" : root.bateria > 0.12 ? "" : "")
                        acento: root.bateria < 0.2 && !root.cargando ? root.terracota : root.arena
                        texto: Math.round(root.bateria * 100) + "%"
                    }
                    Row {      // bandeja del sistema
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter
                        visible: SystemTray.items.values.length > 0
                        Repeater {
                            model: SystemTray.items
                            IconImage {
                                required property var modelData
                                source: modelData.icon
                                implicitWidth: 16; implicitHeight: 16
                                MouseArea {
                                    anchors.fill: parent; acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: mouse => mouse.button === Qt.LeftButton ? modelData.activate() : modelData.secondaryActivate()
                                }
                            }
                        }
                    }
                    Modulo {   // ajustes
                        icono: "\uf013"; acento: root.arena
                        texto: ""
                        onClic: root.ajustesAbierto = !root.ajustesAbierto
                    }
                    Modulo {   // bloquear
                        icono: ""; acento: root.arena
                        texto: ""
                        onClic: root.lanzar(["qs", "-c", "miarch", "ipc", "call", "lock", "lock"])
                    }
                }
            }
        }
    }

    // ═════════════════ PANEL DE CONEXIONES (Wi-Fi + Bluetooth) ═════════════════
    property bool conexionesAbierto: false
    property string conexionesModo: "wifi"          // "wifi" | "bt"
    property var redes: []
    property bool wifiEncendido: true
    property bool wifiOcupado: false
    property string wifiMensaje: ""
    property string redClave: ""                     // red que está pidiendo contraseña
    property string wifiClave: ""                    // lo que se lleva escrito (no se pierde al refrescar)
    property bool ocultaAbierta: false               // formulario para conectar a una red oculta
    property string ocultaNombre: ""
    property string _redesJson: ""
    property var btLista: []
    property var btPendiente: null
    readonly property string wifiBin: Quickshell.env("HOME") + "/.local/bin/miarch-wifi"

    function abrirConexiones(modo) {
        if (root.conexionesAbierto && root.conexionesModo === modo) { root.conexionesAbierto = false; return }
        root.conexionesModo = modo
        root.conexionesAbierto = true
    }

    // ---- Wi-Fi (iwd, vía miarch-wifi) ----
    Process {
        id: pLista
        command: [root.wifiBin, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    root.wifiEncendido = d.power
                    if (root.redClave !== "" || root.wifiOcupado) return      // no tocar la lista mientras se escribe
                    const j = JSON.stringify(d.redes)
                    if (j !== root._redesJson) { root._redesJson = j; root.redes = d.redes }
                } catch (e) {}
            }
        }
    }
    Process { id: pEscaneo; command: [root.wifiBin, "scan"] }
    Process {
        id: pAccion
        property string accion: ""
        property string arg: ""
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiOcupado = false
                try {
                    const d = JSON.parse(text)
                    if (pAccion.accion === "connect" || pAccion.accion === "connect-hidden") {
                        root.wifiMensaje = d.ok ? "" : (d.msg || "No se pudo conectar")
                        if (d.ok) { root.redClave = ""; root.ocultaAbierta = false; root.wifiClave = "" }
                        // red guardada con la contraseña cambiada: se abre el campo para escribir la nueva
                        else if (d.pedir_clave) { root.wifiClave = ""; root.redClave = pAccion.arg }
                    } else if (pAccion.accion === "forget") {
                        root.wifiMensaje = d.ok ? "Red olvidada" : "No se pudo olvidar la red"
                        if (d.ok && root.redClave === pAccion.arg) root.redClave = ""
                    } else if (pAccion.accion === "disconnect") {
                        root.wifiMensaje = d.ok ? "" : "No se pudo desconectar"
                    } else if (pAccion.accion === "power") {
                        if (d.power !== undefined) root.wifiEncendido = d.power          // lo que dice iwd de verdad
                        root.wifiMensaje = d.ok ? "" : "No se pudo cambiar el Wi-Fi"
                    }
                } catch (e) { root.wifiMensaje = pAccion.accion === "forget" ? "No se pudo olvidar la red" : "No se pudo conectar" }
                pLista.running = true
            }
        }
    }
    function wifiAccion(accion, arg, clave) {
        if (pAccion.running) { root._pend = [accion, arg, clave]; tPend.restart(); return }   // no se pierde: espera su turno
        pAccion.accion = accion
        pAccion.arg = arg
        pAccion.environment = { "MIARCH_PASS": clave || "" }
        pAccion.command = arg !== "" ? [root.wifiBin, accion, arg] : [root.wifiBin, accion]
        if (accion === "connect" || accion === "connect-hidden") { root.wifiOcupado = true; root.wifiMensaje = "" }
        else if (accion === "disconnect") root.wifiMensaje = "Desconectando…"
        else if (accion === "forget") root.wifiMensaje = "Olvidando la red…"
        pAccion.running = true
    }
    function conectarRed(r, clave) {
        if (r.seguridad !== "open" && !r.conocida && !clave) { root.wifiClave = ""; root.redClave = r.nombre; root.wifiMensaje = ""; return }
        root.wifiAccion("connect", r.nombre, clave)
    }
    property var _pend: null
    Timer { id: tPend; interval: 300; onTriggered: {
        if (pAccion.running) { tPend.restart(); return }
        if (root._pend) { const q = root._pend; root._pend = null; root.wifiAccion(q[0], q[1], q[2]) } } }
    property int _ciclos: 0
    Timer {
        interval: 4000; repeat: true; triggeredOnStart: true
        running: root.conexionesAbierto && root.conexionesModo === "wifi" && root.redClave === ""
        onTriggered: {
            if (!pLista.running) pLista.running = true
            if (root._ciclos++ % 3 === 0 && !pEscaneo.running) pEscaneo.running = true
        }
    }

    // ---- Bluetooth (BlueZ nativo de Quickshell) ----
    property bool btMostrarSinNombre: false
    property bool btMostrarGuardados: false          // mostrar también los emparejados que no se detectan cerca
    property var btCerca: []                          // direcciones de los emparejados que BlueZ oye ahora mismo (tienen RSSI)
    property int btGuardadosLejos: 0
    property int btSinNombre: 0
    property string _btClave: ""
    // BlueZ usa la dirección MAC como "nombre" cuando el dispositivo no dice cómo se llama
    function btEsMac(n) { return /^([0-9a-f]{2}[-:]){5}[0-9a-f]{2}$/i.test(n || "") }
    function btNombre(d) {
        if (d.name && !root.btEsMac(d.name)) return d.name
        if (d.deviceName && !root.btEsMac(d.deviceName)) return d.deviceName
        return ""
    }
    function ordenarBt() {
        const a = root.adaptadorBt
        if (!a) { root.btLista = []; root._btClave = ""; return }
        const todos = a.devices.values.slice()
        root.btSinNombre = todos.filter(d => root.btNombre(d) === "" && !d.paired && !d.connected).length
        // solo lo que se puede usar ahora: conectados, emparejados que se oyen cerca, y los encontrados con nombre.
        // Los emparejados que no se detectan se esconden (botón al pie para verlos).
        root.btGuardadosLejos = todos.filter(d => d.paired && !d.connected && root.btCerca.indexOf(d.address) < 0).length
        const visibles = todos.filter(d => d.connected
            || (d.paired ? (root.btCerca.indexOf(d.address) >= 0 || root.btMostrarGuardados)
                         : (root.btNombre(d) !== "" || root.btMostrarSinNombre)))
        visibles.sort((x, y) =>
            (y.connected - x.connected) || (y.paired - x.paired) ||
            String(root.btNombre(x) || "~" + x.address).localeCompare(String(root.btNombre(y) || "~" + y.address)))
        // solo se reemplaza la lista si de verdad cambió algo (así las filas no parpadean cada segundo)
        const clave = root.btMostrarGuardados + "#" + visibles.map(d => d.address + "|" + root.btNombre(d) + "|" + d.connected + "|" + d.paired).join(";")
        if (clave !== root._btClave) { root._btClave = clave; root.btLista = visibles }
    }
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: root.conexionesAbierto && root.conexionesModo === "bt"
        onTriggered: root.ordenarBt()
    }
    // qué emparejados se oyen ahora: BlueZ les pone RSSI solo mientras los detecta
    Process {
        id: pBtCerca
        command: ["sh", "-c", "bluetoothctl devices Paired 2>/dev/null | awk '{print $2}' | while read m; do bluetoothctl info \"$m\" 2>/dev/null | grep -q RSSI && echo \"$m\"; done"]
        stdout: StdioCollector { onStreamFinished: { root.btCerca = text.trim() === "" ? [] : text.trim().split("\n"); root._btClave = ""; root.ordenarBt() } }
    }
    Timer {
        interval: 4000; repeat: true; triggeredOnStart: true
        running: root.conexionesAbierto && root.conexionesModo === "bt"
        onTriggered: { if (!pBtCerca.running) pBtCerca.running = true }
    }
    Timer { id: tPendiente; interval: 3500; onTriggered: { if (root.btPendiente && root.btPendiente.paired) root.btPendiente.connect(); root.btPendiente = null } }
    function btClic(d) {
        if (d.connected) d.disconnect()
        else if (d.paired) d.connect()
        else { d.trusted = true; d.pair(); root.btPendiente = d; tPendiente.restart() }
    }
    onConexionesAbiertoChanged: {
        if (root.adaptadorBt) root.adaptadorBt.discovering = root.conexionesAbierto && root.conexionesModo === "bt"
        if (!root.conexionesAbierto) { root.redClave = ""; root.wifiClave = ""; root.wifiMensaje = "" }
    }
    onConexionesModoChanged: {
        if (root.adaptadorBt) root.adaptadorBt.discovering = root.conexionesAbierto && root.conexionesModo === "bt"
        root.redClave = ""
    }

    IpcHandler {
        target: "connections"
        function wifi(): void { root.abrirConexiones("wifi") }
        function bluetooth(): void { root.abrirConexiones("bt") }
        function close(): void { root.conexionesAbierto = false }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            readonly property bool enEstaPantalla: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name : modelData === Quickshell.screens[0]
            visible: root.conexionesAbierto && enEstaPantalla
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "miarch-conexiones"
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Item {
                id: cx
                anchors.fill: parent
                focus: true
                property real entrada: 0
                Connections {
                    target: root
                    function onConexionesAbiertoChanged() { if (root.conexionesAbierto) { cx.entrada = 0; cx.entrada = 1; cx.forceActiveFocus() } }
                }
                Behavior on entrada { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                Keys.onEscapePressed: { if (root.redClave !== "") root.redClave = ""; else root.conexionesAbierto = false }

                MouseArea { anchors.fill: parent; onClicked: root.conexionesAbierto = false }

                Rectangle {
                    id: tarjeta
                    width: 440
                    height: Math.min(cuerpo.implicitHeight + 52, parent.height - 80)
                    x: parent.width - width - 16
                    y: 54 + (1 - cx.entrada) * -14
                    opacity: Math.min(1, cx.entrada)
                    radius: 22
                    color: Qt.alpha(root.fondo, 0.84)
                    border.width: 1
                    border.color: Qt.alpha(root.arena, 0.12)
                    MouseArea { anchors.fill: parent }   // que los clics dentro no cierren

                    Column {
                        id: cuerpo
                        x: 22; y: 22
                        width: parent.width - 44
                        spacing: 18

                        // Pestañas + interruptor de encendido
                        Item {
                            width: parent.width; height: 34
                            Row {
                                spacing: 24
                                Repeater {
                                    model: [ { m: "wifi", t: "WI-FI" }, { m: "bt", t: "BLUETOOTH" } ]
                                    Item {
                                        required property var modelData
                                        width: etq.implicitWidth; height: 34
                                        Text {
                                            id: etq
                                            text: modelData.t
                                            color: root.conexionesModo === modelData.m ? root.arena : Qt.alpha(root.arena, 0.4)
                                            font { family: root.fuente; pixelSize: 14 * root.esc; weight: Font.Medium; letterSpacing: 4 }
                                            Behavior on color { ColorAnimation { duration: 200 } }
                                        }
                                        Rectangle {
                                            y: 28; height: 2; radius: 1; color: root.terracota
                                            width: root.conexionesModo === modelData.m ? parent.width : 0
                                            Behavior on width { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.conexionesModo = modelData.m }
                                    }
                                }
                            }
                            Interruptor {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                encendido: root.conexionesModo === "wifi" ? root.wifiEncendido : (root.adaptadorBt ? root.adaptadorBt.enabled : false)
                                onAlternar: {
                                    if (root.conexionesModo === "wifi") { root.wifiEncendido = !root.wifiEncendido; root.wifiAccion("power", root.wifiEncendido ? "on" : "off", "") }
                                    else if (root.adaptadorBt) root.adaptadorBt.enabled = !root.adaptadorBt.enabled
                                }
                            }
                        }

                        // ───────────── WI-FI ─────────────
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: root.conexionesModo === "wifi"

                            Text {
                                visible: !root.wifiEncendido
                                text: "El Wi-Fi está apagado"
                                color: Qt.alpha(root.arena, 0.5)
                                font { family: root.fuente; pixelSize: 14 * root.esc; weight: Font.Light }
                                topPadding: 8; bottomPadding: 8
                            }
                            Text {
                                visible: root.wifiEncendido && root.redes.length === 0
                                text: "Buscando redes…"
                                color: Qt.alpha(root.arena, 0.5)
                                font { family: root.fuente; pixelSize: 14 * root.esc; weight: Font.Light }
                                topPadding: 8; bottomPadding: 8
                            }
                            Flickable {
                                id: listaWifi
                                width: parent.width
                                height: Math.min(filas.implicitHeight, 360)
                                contentHeight: filas.implicitHeight
                                clip: true
                                visible: root.wifiEncendido && root.redes.length > 0
                                boundsBehavior: Flickable.StopAtBounds
                                // al abrir el panel siempre se empieza arriba (la red conectada primero); antes conservaba
                                // el desplazamiento anterior y la red conectada quedaba oculta
                                Connections {
                                    target: root
                                    function onConexionesAbiertoChanged() { listaWifi.contentY = 0 }
                                    function onConexionesModoChanged() { listaWifi.contentY = 0 }
                                }
                                Column {
                                    id: filas
                                    width: parent.width
                                    spacing: 2
                                    Repeater {
                                        model: root.redes
                                        Column {
                                            required property var modelData
                                            required property int index
                                            width: filas.width
                                            spacing: 2
                                            // encabezado de grupo: CONECTADA / GUARDADAS / DISPONIBLES
                                            Text {
                                                readonly property int g: modelData.conectada ? 0 : (modelData.conocida ? 1 : 2)
                                                readonly property int gAnt: index === 0 ? -1 : (root.redes[index - 1].conectada ? 0 : (root.redes[index - 1].conocida ? 1 : 2))
                                                visible: g !== gAnt
                                                height: visible ? implicitHeight : 0
                                                topPadding: index === 0 ? 2 : 14; bottomPadding: 6; leftPadding: 4
                                                text: ["CONECTADA", "GUARDADAS", "DISPONIBLES"][g]
                                                color: Qt.alpha(root.arena, 0.4)
                                                font { family: root.fuente; pixelSize: 11 * root.esc; weight: Font.Medium; letterSpacing: 4 }
                                            }
                                            Item {
                                                id: fila
                                                width: parent.width; height: 60 * root.esc
                                                HoverHandler { id: hov }
                                                Rectangle {
                                                    anchors.fill: parent; radius: 14
                                                    color: modelData.conectada ? Qt.alpha(root.terracota, 0.10) : (hov.hovered ? Qt.alpha(root.arena, 0.07) : "transparent")
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: modelData.visible && !modelData.conectada ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                    onClicked: { if (modelData.visible && !modelData.conectada) root.conectarRed(modelData, "") }
                                                }
                                                Text {   // intensidad de la señal
                                                    x: 18; anchors.verticalCenter: parent.verticalCenter
                                                    text: ""
                                                    color: modelData.conectada ? root.terracota : root.arena
                                                    opacity: modelData.visible ? 0.3 + 0.175 * modelData.senal : 0.2
                                                    font { family: root.fuente; pixelSize: 18 * root.esc }
                                                }
                                                Column {
                                                    x: 56; anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 56 - (modelData.conectada ? 130 : (modelData.conocida ? 80 : 44))
                                                    spacing: 3
                                                    Text {
                                                        width: parent.width; elide: Text.ElideRight
                                                        text: modelData.nombre
                                                        color: root.arena
                                                        opacity: modelData.visible ? 1 : 0.6
                                                        font { family: root.fuente; pixelSize: 16 * root.esc; weight: modelData.conectada ? Font.Medium : Font.Light }
                                                    }
                                                    Text {
                                                        width: parent.width; elide: Text.ElideRight
                                                        text: modelData.conectada ? "Conectada" : (!modelData.visible ? "Guardada · fuera de alcance"
                                                              : (modelData.conocida ? "Guardada · toca para conectar" : (modelData.seguridad !== "open" ? "Con contraseña" : "Abierta")))
                                                        color: modelData.conectada ? root.terracota : root.arena
                                                        opacity: modelData.conectada ? 0.9 : 0.45
                                                        font { family: root.fuente; pixelSize: 12 * root.esc; weight: Font.Light }
                                                    }
                                                }
                                                Text {   // candado de las redes con contraseña que aún no conoces
                                                    anchors.right: parent.right; anchors.rightMargin: 18
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    visible: !modelData.conocida && modelData.seguridad !== "open"
                                                    text: ""
                                                    color: Qt.alpha(root.arena, 0.4)
                                                    font { family: root.fuente; pixelSize: 13 * root.esc }
                                                }
                                                // acciones: texto simple, sin cajas. "Olvidar" solo aparece al pasar el ratón
                                                Row {
                                                    anchors.right: parent.right; anchors.rightMargin: 16
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 18
                                                    Text {
                                                        visible: modelData.conectada
                                                        text: "Desconectar"
                                                        color: dz.containsMouse ? root.terracota : Qt.alpha(root.arena, 0.7)
                                                        font { family: root.fuente; pixelSize: 13 * root.esc; weight: Font.Medium }
                                                        MouseArea { id: dz; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                                    onClicked: root.wifiAccion("disconnect", "", "") }
                                                    }
                                                    Text {
                                                        visible: modelData.conocida && (hov.hovered || !modelData.visible || modelData.conectada)
                                                        text: "Olvidar"
                                                        color: oz.containsMouse ? root.terracota : Qt.alpha(root.arena, 0.45)
                                                        font { family: root.fuente; pixelSize: 13 * root.esc; weight: Font.Medium }
                                                        MouseArea { id: oz; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                                    onClicked: root.wifiAccion("forget", modelData.nombre, "") }
                                                    }
                                                }
                                            }
                                            // Contraseña (aparece bajo la red elegida)
                                            Item {
                                                visible: root.redClave === modelData.nombre
                                                width: parent.width; height: visible ? 86 : 0
                                                Rectangle {
                                                    id: caja
                                                    x: 8; width: parent.width - 16; height: 44; radius: 12
                                                    color: Qt.alpha(root.arena, 0.07)
                                                    border.width: 1; border.color: Qt.alpha(root.terracota, 0.6)
                                                    Text {
                                                        visible: clave.text.length === 0
                                                        x: 14; anchors.verticalCenter: parent.verticalCenter
                                                        text: "Contraseña"
                                                        color: Qt.alpha(root.arena, 0.35)
                                                        font { family: root.fuente; pixelSize: 14 * root.esc; weight: Font.Light }
                                                    }
                                                    TextInput {
                                                        id: clave
                                                        x: 14; width: parent.width - 120; anchors.verticalCenter: parent.verticalCenter
                                                        echoMode: TextInput.Password
                                                        passwordCharacter: "•"
                                                        color: root.arena
                                                        selectionColor: root.terracota
                                                        font { family: root.fuente; pixelSize: 15 * root.esc }
                                                        clip: true
                                                        enabled: !root.wifiOcupado
                                                        Component.onCompleted: { text = root.wifiClave; if (visible) forceActiveFocus() }
                                                        onTextChanged: root.wifiClave = text
                                                        onAccepted: if (text.length > 0) root.conectarRed(modelData, text)
                                                        Keys.onEscapePressed: root.redClave = ""
                                                        Connections {
                                                            target: root
                                                            function onWifiMensajeChanged() { if (root.wifiMensaje !== "") clave.forceActiveFocus() }
                                                            function onRedClaveChanged() { if (root.redClave === modelData.nombre) clave.forceActiveFocus() }
                                                        }
                                                    }
                                                    Opcion {
                                                        anchors.right: parent.right; anchors.rightMargin: 6
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        texto: root.wifiOcupado ? "…" : "Conectar"
                                                        activo: clave.text.length > 0
                                                        onClic: if (clave.text.length > 0) root.conectarRed(modelData, clave.text)
                                                    }
                                                }
                                                Text {
                                                    x: 12; y: 52
                                                    text: root.wifiOcupado ? "Conectando…" : root.wifiMensaje
                                                    color: root.wifiOcupado ? Qt.alpha(root.arena, 0.6) : root.terracota
                                                    font { family: root.fuente; pixelSize: 12 * root.esc; weight: Font.Medium; letterSpacing: 2 }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                visible: root.wifiOcupado && root.redClave === ""
                                text: "Conectando…"
                                color: Qt.alpha(root.arena, 0.6)
                                font { family: root.fuente; pixelSize: 12 * root.esc; weight: Font.Medium; letterSpacing: 2 }
                                topPadding: 6
                            }
                            Text {
                                visible: !root.wifiOcupado && root.redClave === "" && root.wifiMensaje !== "" && root.wifiEncendido && !root.ocultaAbierta
                                text: root.wifiMensaje
                                color: root.terracota
                                font { family: root.fuente; pixelSize: 12 * root.esc; weight: Font.Medium; letterSpacing: 2 }
                                topPadding: 6
                            }
                            // Red oculta: no sale en la lista; se conecta escribiendo su nombre (y la contraseña si lleva)
                            Opcion {
                                visible: root.wifiEncendido && !root.ocultaAbierta
                                texto: "Red oculta…"
                                onClic: { root.ocultaNombre = ""; root.wifiClave = ""; root.redClave = ""; root.wifiMensaje = ""; root.ocultaAbierta = true }
                            }
                            Column {
                                visible: root.wifiEncendido && root.ocultaAbierta
                                width: parent.width; spacing: 6; topPadding: 6
                                Rectangle {
                                    x: 8; width: parent.width - 16; height: 40; radius: 12
                                    color: Qt.alpha(root.arena, 0.07); border.width: 1; border.color: Qt.alpha(root.arena, 0.25)
                                    Text { visible: ocNombre.text.length === 0; x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Nombre de la red"
                                           color: Qt.alpha(root.arena, 0.35); font { family: root.fuente; pixelSize: 14 * root.esc; weight: Font.Light } }
                                    TextInput { id: ocNombre; x: 14; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter; clip: true
                                                color: root.arena; selectionColor: root.terracota; font { family: root.fuente; pixelSize: 15 * root.esc }
                                                enabled: !root.wifiOcupado; onTextChanged: root.ocultaNombre = text
                                                Component.onCompleted: forceActiveFocus()
                                                Keys.onEscapePressed: root.ocultaAbierta = false }
                                }
                                Rectangle {
                                    x: 8; width: parent.width - 16; height: 40; radius: 12
                                    color: Qt.alpha(root.arena, 0.07); border.width: 1; border.color: Qt.alpha(root.arena, 0.25)
                                    Text { visible: ocClave.text.length === 0; x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Contraseña (vacía si es abierta)"
                                           color: Qt.alpha(root.arena, 0.35); font { family: root.fuente; pixelSize: 14 * root.esc; weight: Font.Light } }
                                    TextInput { id: ocClave; x: 14; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter; clip: true
                                                echoMode: TextInput.Password; passwordCharacter: "•"
                                                color: root.arena; selectionColor: root.terracota; font { family: root.fuente; pixelSize: 15 * root.esc }
                                                enabled: !root.wifiOcupado; Keys.onEscapePressed: root.ocultaAbierta = false
                                                onAccepted: if (ocNombre.text.length > 0) root.wifiAccion("connect-hidden", ocNombre.text, ocClave.text) }
                                }
                                Row {
                                    x: 8; spacing: 8
                                    Opcion { activo: ocNombre.text.length > 0; texto: root.wifiOcupado ? "…" : "Conectar"
                                             onClic: if (ocNombre.text.length > 0) root.wifiAccion("connect-hidden", ocNombre.text, ocClave.text) }
                                    Opcion { texto: "Cancelar"; onClic: root.ocultaAbierta = false }
                                }
                                Text {
                                    visible: root.wifiOcupado || root.wifiMensaje !== ""
                                    x: 12; text: root.wifiOcupado ? "Conectando…" : root.wifiMensaje
                                    color: root.wifiOcupado ? Qt.alpha(root.arena, 0.6) : root.terracota
                                    font { family: root.fuente; pixelSize: 12 * root.esc; weight: Font.Medium; letterSpacing: 2 }
                                }
                            }
                        }

                        // ───────────── BLUETOOTH ─────────────
                        Column {
                            width: parent.width
                            spacing: 6
                            visible: root.conexionesModo === "bt"

                            Text {
                                visible: !root.adaptadorBt
                                text: "No se encontró un adaptador Bluetooth"
                                color: Qt.alpha(root.arena, 0.5)
                                font { family: root.fuente; pixelSize: 14 * root.esc; weight: Font.Light }
                                topPadding: 8; bottomPadding: 8
                            }
                            Text {
                                visible: root.adaptadorBt && !root.adaptadorBt.enabled
                                text: "El Bluetooth está apagado"
                                color: Qt.alpha(root.arena, 0.5)
                                font { family: root.fuente; pixelSize: 14 * root.esc; weight: Font.Light }
                                topPadding: 8; bottomPadding: 8
                            }
                            Flickable {
                                width: parent.width
                                height: Math.min(filasBt.implicitHeight, 360)
                                contentHeight: filasBt.implicitHeight
                                clip: true
                                visible: root.adaptadorBt && root.adaptadorBt.enabled
                                boundsBehavior: Flickable.StopAtBounds
                                Column {
                                    id: filasBt
                                    width: parent.width
                                    spacing: 2
                                    Repeater {
                                        model: root.btLista
                                        Item {
                                            required property var modelData
                                            width: filasBt.width; height: 50
                                            Rectangle {
                                                anchors.fill: parent; radius: 12
                                                color: btZona.containsMouse ? Qt.alpha(root.arena, 0.08) : "transparent"
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                            }
                                            Text {
                                                x: 12; anchors.verticalCenter: parent.verticalCenter
                                                text: {
                                                    const i = String(modelData.icon || "")
                                                    return i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0 ? ""
                                                         : i.indexOf("keyboard") >= 0 ? ""
                                                         : i.indexOf("mouse") >= 0 ? ""
                                                         : i.indexOf("phone") >= 0 ? ""
                                                         : i.indexOf("audio") >= 0 || i.indexOf("speaker") >= 0 ? "" : ""
                                                }
                                                color: modelData.connected ? root.terracota : root.arena
                                                opacity: modelData.paired || modelData.connected ? 1 : 0.5
                                                font { family: root.fuente; pixelSize: 16 * root.esc }
                                            }
                                            Column {
                                                x: 46; anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 120
                                                spacing: 1
                                                Text {
                                                    width: parent.width; elide: Text.ElideRight
                                                    text: root.btNombre(modelData) || ("Dispositivo " + modelData.address)
                                                    color: root.arena
                                                    font { family: root.fuente; pixelSize: 15 * root.esc; weight: modelData.connected ? Font.Medium : Font.Light }
                                                }
                                                Text {
                                                    text: modelData.connected ? "Conectado" : (modelData.paired ? "Emparejado" : "Toca para emparejar")
                                                    color: modelData.connected ? root.terracota : Qt.alpha(root.arena, 0.4)
                                                    font { family: root.fuente; pixelSize: 11 * root.esc; weight: Font.Medium; letterSpacing: 2 }
                                                }
                                            }
                                            Text {
                                                anchors.right: parent.right; anchors.rightMargin: 14
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: modelData.connected
                                                text: modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : ""
                                                color: Qt.alpha(root.arena, 0.6)
                                                font { family: root.fuente; pixelSize: 13 * root.esc }
                                            }
                                            MouseArea {
                                                id: btZona
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: root.btClic(modelData)
                                            }
                                        }
                                    }
                                }
                            }
                            Text {
                                visible: root.adaptadorBt && root.adaptadorBt.enabled
                                text: root.adaptadorBt && root.adaptadorBt.discovering ? "Buscando dispositivos…" : ""
                                color: Qt.alpha(root.arena, 0.45)
                                font { family: root.fuente; pixelSize: 12 * root.esc; weight: Font.Medium; letterSpacing: 2 }
                                topPadding: 8
                            }
                            Text {
                                visible: root.adaptadorBt && root.adaptadorBt.enabled && (root.btGuardadosLejos > 0 || root.btMostrarGuardados)
                                text: root.btMostrarGuardados ? "Ocultar los guardados que no están cerca" : ("Mostrar " + root.btGuardadosLejos + " guardado(s) que no se detectan")
                                color: Qt.alpha(root.arena, 0.5)
                                font { family: root.fuente; pixelSize: 12 * root.esc; weight: Font.Medium; letterSpacing: 1 }
                                topPadding: 4
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.btMostrarGuardados = !root.btMostrarGuardados; root._btClave = ""; root.ordenarBt() } }
                            }
                            Text {
                                visible: root.adaptadorBt && root.adaptadorBt.enabled && (root.btSinNombre > 0 || root.btMostrarSinNombre)
                                text: root.btMostrarSinNombre ? "Ocultar dispositivos sin nombre" : ("Mostrar " + root.btSinNombre + " dispositivo(s) sin nombre")
                                color: root.terracota
                                font { family: root.fuente; pixelSize: 12 * root.esc; weight: Font.Medium; letterSpacing: 1 }
                                topPadding: 4
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.btMostrarSinNombre = !root.btMostrarSinNombre; root._btClave = ""; root.ordenarBt() } }
                            }
                        }
                    }
                }
            }
        }
    }

    // ═════════════════ PANEL DE AJUSTES (todo el equipo) ═════════════════
    property bool ajustesAbierto: false
    property string ajustesPagina: "apariencia"
    property string animActual: "slide"
    property string blurActual: "fuerte"
    property string animBarra: "fundido"
    property string gifActual: "off"
    property string escalaActual: "auto"
    property string tecladoActual: "latam"
    property bool scrollNatActual: false
    property bool tapActual: true
    property string sensActual: "0"
    property string cursorActual: "24"
    property bool movimientoActual: true
    property string perfilActual: "balanced"
    property var infoSistema: ({})
    property var monitoresInfo: []
    property var fondos: []

    FileView {
        id: fHypr
        path: Quickshell.env("HOME") + "/.config/hypr/hyprland.lua"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const t = text()
            const g = n => { const m = new RegExp('^local ' + n + ' *= *"([^"]*)"', 'm').exec(t); return m ? m[1] : null }
            root.animActual = g("ANIM") || root.animActual
            root.blurActual = g("BLUR") || root.blurActual
            root.escalaActual = g("ESCALA") || root.escalaActual
            root.tecladoActual = g("KB") || root.tecladoActual
            root.scrollNatActual = (g("NATURAL") || "off") === "on"
            root.tapActual = (g("TAP") || "on") === "on"
            root.sensActual = g("SENS") || root.sensActual
            root.cursorActual = g("CURSOR") || root.cursorActual
            root.movimientoActual = (g("MOVIMIENTO") || "on") === "on"
        }
    }
    FileView {
        id: fAjustes
        path: Quickshell.env("HOME") + "/.config/miarch/ajustes.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const d = JSON.parse(text())
                root.animBarra = d.barra || "fundido"
                root.gifActual = d.gif || "off"
                root.esc = parseFloat(d.texto) || 1.0
                root.contrasteAlto = d.contraste === "on"
            } catch (e) {}
        }
    }
    FileView { id: fBrillo;    path: "/sys/class/backlight/intel_backlight/brightness";     onLoaded: root._brilloAct = Number(text()) }
    FileView { id: fBrilloMax; path: "/sys/class/backlight/intel_backlight/max_brightness"; onLoaded: root._brilloMax = Number(text()) }
    property real _brilloAct: 0
    property real _brilloMax: 1
    readonly property real brillo: Math.min(1, root._brilloAct / Math.max(1, root._brilloMax))
    Timer {   // mientras la página Pantalla está abierta, relee el brillo
        interval: 700; repeat: true
        running: root.ajustesAbierto && root.ajustesPagina === "pantalla"
        onTriggered: fBrillo.reload()
    }

    Process {
        id: pInfo
        command: [Quickshell.env("HOME") + "/.local/bin/miarch-info"]
        stdout: StdioCollector { onStreamFinished: { try { const d = JSON.parse(text); root.infoSistema = d; root.perfilActual = d.perfil || root.perfilActual } catch (e) {} } }
    }
    Process {
        id: pMonitores
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { root.monitoresInfo = JSON.parse(text) } catch (e) {} } }
    }
    Process {
        id: pFondos
        command: ["sh", "-c", "find \"$(xdg-user-dir PICTURES 2>/dev/null || echo \"$HOME/Pictures\")/Wallpapers\" -maxdepth 1 -type f \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \\) | sort"]
        stdout: StdioCollector { onStreamFinished: root.fondos = text.trim().split("\n").filter(x => x.length > 0) }
    }
    function refrescarAjustes() {
        fHypr.reload(); fAjustes.reload(); fBrillo.reload(); fBrilloMax.reload()
        if (!pInfo.running) pInfo.running = true
        if (!pMonitores.running) pMonitores.running = true
        if (!pFondos.running) pFondos.running = true
    }

    // Audio: hay que "seguir" los nodos para poder leer su volumen
    PwObjectTracker { objects: Pipewire.nodes.values }
    readonly property var salidas: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
    readonly property var entradas: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio)

    property var _confirmar: ""
    function aplicar(c, v) {
        if (c === "anim") root.animActual = v
        else if (c === "blur") root.blurActual = v
        else if (c === "barra") root.animBarra = v
        else if (c === "gif") root.gifActual = v
        else if (c === "escala") root.escalaActual = v
        else if (c === "teclado") root.tecladoActual = v
        else if (c === "scrollnat") root.scrollNatActual = v === "on"
        else if (c === "tap") root.tapActual = v === "on"
        else if (c === "sens") root.sensActual = v
        else if (c === "cursor") root.cursorActual = v
        else if (c === "movimiento") { root.movimientoActual = v === "on"; if (v === "off") root.animBarra = "ninguna" }
        else if (c === "texto") root.esc = parseFloat(v)
        else if (c === "contraste") root.contrasteAlto = v === "on"
        else if (c === "perfil") root.perfilActual = v
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/miarch-set", c, v])
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.ajustesAbierto = !root.ajustesAbierto }
        function open(): void { root.ajustesAbierto = true }
        function close(): void { root.ajustesAbierto = false }
        function page(nombre: string): void { root.ajustesPagina = nombre; root.ajustesAbierto = true }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            readonly property bool enEstaPantalla: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name : modelData === Quickshell.screens[0]
            visible: root.ajustesAbierto && enEstaPantalla
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "miarch-ajustes"
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Item {
                id: aj
                anchors.fill: parent
                focus: true
                property real entrada: 0
                Connections {
                    target: root
                    function onAjustesAbiertoChanged() {
                        if (root.ajustesAbierto) { aj.entrada = 0; aj.entrada = 1; aj.forceActiveFocus(); root.refrescarAjustes() }
                    }
                }
                Behavior on entrada { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }
                Keys.onEscapePressed: root.ajustesAbierto = false

                Rectangle { anchors.fill: parent; color: root.fondo; opacity: Math.min(1, aj.entrada) * (root.contrasteAlto ? 0.9 : 0.62) }
                MouseArea { anchors.fill: parent; onClicked: root.ajustesAbierto = false }

                Rectangle {
                    id: ventana
                    width: Math.min(parent.width * 0.92, 1080)
                    height: Math.min(parent.height * 0.88, 720)
                    x: (parent.width - width) / 2
                    y: (parent.height - height) / 2 + (1 - aj.entrada) * 20
                    opacity: Math.min(1, aj.entrada)
                    radius: 24
                    color: Qt.alpha(root.fondo, root.contrasteAlto ? 0.98 : 0.88)
                    border.width: root.contrasteAlto ? 2 : 1
                    border.color: Qt.alpha(root.arena, root.contrasteAlto ? 0.7 : 0.12)
                    clip: true
                    MouseArea { anchors.fill: parent }

                    // ───────── Menú lateral ─────────
                    Item {
                        id: lateral
                        width: 240; height: parent.height
                        Text {
                            x: 28; y: 26
                            text: "AJUSTES"
                            color: root.arena
                            font { family: root.fuente; pixelSize: 20 * root.esc; weight: Font.Thin; letterSpacing: 8 }
                        }
                        Column {
                            x: 12; y: 78
                            width: parent.width - 24
                            spacing: 4
                            Repeater {
                                model: [
                                    { id: "red",           t: "Red",              i: "" },
                                    { id: "sonido",        t: "Sonido",           i: "" },
                                    { id: "pantalla",      t: "Pantalla",         i: "" },
                                    { id: "apariencia",    t: "Apariencia",       i: "" },
                                    { id: "entrada",       t: "Teclado y ratón",  i: "" },
                                    { id: "accesibilidad", t: "Accesibilidad",    i: "" },
                                    { id: "energia",       t: "Energía",          i: "" },
                                    { id: "sistema",       t: "Sistema",          i: "" }
                                ]
                                Item {
                                    required property var modelData
                                    readonly property bool sel: root.ajustesPagina === modelData.id
                                    width: parent.width; height: 44
                                    Rectangle {
                                        anchors.fill: parent; radius: 12
                                        color: sel ? Qt.alpha(root.arena, 0.12) : (mz.containsMouse ? Qt.alpha(root.arena, 0.06) : "transparent")
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }
                                    Rectangle {
                                        x: 0; anchors.verticalCenter: parent.verticalCenter
                                        width: 3; height: sel ? 22 : 0; radius: 2; color: root.terracota
                                        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                                    }
                                    Text {
                                        x: 18; anchors.verticalCenter: parent.verticalCenter
                                        width: 22; horizontalAlignment: Text.AlignHCenter
                                        text: modelData.i
                                        color: sel ? root.terracota : Qt.alpha(root.arena, 0.7)
                                        font { family: root.fuente; pixelSize: 16 * root.esc }
                                    }
                                    Text {
                                        x: 54; anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.t
                                        color: sel ? root.arena : Qt.alpha(root.arena, 0.7)
                                        font { family: root.fuente; pixelSize: 14 * root.esc; weight: sel ? Font.Medium : Font.Light }
                                    }
                                    MouseArea { id: mz; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.ajustesPagina = modelData.id }
                                }
                            }
                        }
                        Text {
                            x: 28; y: parent.height - 40
                            text: "Esc para cerrar"
                            color: Qt.alpha(root.arena, 0.3)
                            font { family: root.fuente; pixelSize: 11 * root.esc; weight: Font.Light; letterSpacing: 3 }
                        }
                    }
                    Rectangle { x: 240; y: 24; width: 1; height: parent.height - 48; color: Qt.alpha(root.arena, 0.1) }

                    // ───────── Contenido ─────────
                    Item {
                        id: contenido
                        x: 241; width: parent.width - 241; height: parent.height

                        // ═══ RED ═══
                        Pagina {
                            visible: root.ajustesPagina === "red"
                            Titulo { texto: "Red" }
                            Tarjeta {
                                titulo: "WI-FI"
                                detalle: root.wifiConectado ? ("Conectado a " + root.wifiNombre) : "Sin conexión"
                                boton: "Abrir Wi-Fi"
                                onClic: { root.ajustesAbierto = false; root.abrirConexiones("wifi") }
                            }
                            Tarjeta {
                                titulo: "BLUETOOTH"
                                detalle: !root.adaptadorBt ? "Sin adaptador" : (root.adaptadorBt.enabled ? (root.adaptadorBt.devices.values.filter(d => d.connected).length + " dispositivo(s) conectado(s)") : "Apagado")
                                boton: "Abrir Bluetooth"
                                onClic: { root.ajustesAbierto = false; root.abrirConexiones("bt") }
                            }
                        }

                        // ═══ SONIDO ═══
                        Pagina {
                            visible: root.ajustesPagina === "sonido"
                            Titulo { texto: "Sonido" }
                            Etiqueta { texto: "SALIDA" }
                            Repeater {
                                model: root.salidas
                                Fila {
                                    required property var modelData
                                    etiqueta: modelData.description || modelData.nickname || modelData.name
                                    detalle: Pipewire.defaultAudioSink === modelData ? "En uso" : ""
                                    Opcion {
                                        texto: Pipewire.defaultAudioSink === modelData ? "Activa" : "Usar"
                                        activo: Pipewire.defaultAudioSink === modelData
                                        onClic: Pipewire.preferredDefaultAudioSink = modelData
                                    }
                                }
                            }
                            Fila {
                                etiqueta: "Volumen"
                                detalle: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%" : ""
                                Deslizador {
                                    valor: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Math.min(1, Pipewire.defaultAudioSink.audio.volume) : 0
                                    onMovido: v => { if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.volume = v }
                                }
                                Interruptor {
                                    encendido: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? !Pipewire.defaultAudioSink.audio.muted : true
                                    onAlternar: if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                                }
                            }
                            Etiqueta { texto: "ENTRADA (MICRÓFONO)" }
                            Repeater {
                                model: root.entradas
                                Fila {
                                    required property var modelData
                                    etiqueta: modelData.description || modelData.nickname || modelData.name
                                    detalle: Pipewire.defaultAudioSource === modelData ? "En uso" : ""
                                    Opcion {
                                        texto: Pipewire.defaultAudioSource === modelData ? "Activo" : "Usar"
                                        activo: Pipewire.defaultAudioSource === modelData
                                        onClic: Pipewire.preferredDefaultAudioSource = modelData
                                    }
                                }
                            }
                            Fila {
                                etiqueta: "Volumen del micrófono"
                                detalle: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Math.round(Pipewire.defaultAudioSource.audio.volume * 100) + "%" : ""
                                Deslizador {
                                    valor: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? Math.min(1, Pipewire.defaultAudioSource.audio.volume) : 0
                                    onMovido: v => { if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) Pipewire.defaultAudioSource.audio.volume = v }
                                }
                                Interruptor {
                                    encendido: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio ? !Pipewire.defaultAudioSource.audio.muted : true
                                    onAlternar: if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
                                }
                            }
                        }

                        // ═══ PANTALLA ═══
                        Pagina {
                            visible: root.ajustesPagina === "pantalla"
                            Titulo { texto: "Pantalla" }
                            Fila {
                                etiqueta: "Brillo"
                                detalle: Math.round(root.brillo * 100) + "%"
                                Deslizador {
                                    valor: root.brillo
                                    onMovido: v => { Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/miarch-set", "brillo", String(Math.max(1, Math.round(v * 100)))]) }
                                }
                            }
                            Seccion {
                                titulo: "ESCALA (TAMAÑO DE TODO)"; clave: "escala"; actual: root.escalaActual
                                opciones: [ { v: "auto", t: "Automática" }, { v: "1", t: "100%" }, { v: "1.25", t: "125%" }, { v: "1.5", t: "150%" }, { v: "2", t: "200%" } ]
                            }
                            Etiqueta { texto: "MONITORES CONECTADOS" }
                            Repeater {
                                model: root.monitoresInfo
                                Fila {
                                    required property var modelData
                                    etiqueta: modelData.name + (modelData.description ? "  ·  " + modelData.description : "")
                                    detalle: modelData.width + "×" + modelData.height + "  ·  " + Math.round(modelData.refreshRate) + " Hz  ·  escala " + modelData.scale
                                }
                            }
                        }

                        // ═══ APARIENCIA ═══
                        Pagina {
                            visible: root.ajustesPagina === "apariencia"
                            Titulo { texto: "Apariencia" }
                            Etiqueta { texto: "FONDO DE PANTALLA" }
                            Flow {
                                width: parent.width
                                spacing: 12
                                Repeater {
                                    model: root.fondos
                                    Item {
                                        required property var modelData
                                        width: 150; height: 92
                                        Image {
                                            anchors.fill: parent
                                            source: "file://" + encodeURI(modelData)
                                            sourceSize.width: 300; sourceSize.height: 184
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            opacity: mzf.containsMouse ? 1 : 0.85
                                            Behavior on opacity { NumberAnimation { duration: 150 } }
                                        }
                                        Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: mzf.containsMouse ? root.terracota : Qt.alpha(root.arena, 0.15) }
                                        MouseArea {
                                            id: mzf; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/wallpaper.sh", modelData])
                                        }
                                    }
                                }
                            }
                            Row {
                                spacing: 10
                                Opcion { texto: "Aleatorio"; onClic: Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/wallpaper.sh"]) }
                            }
                            Seccion {
                                titulo: "FONDOS ANIMADOS (GIF)"; clave: "gif"; actual: root.gifActual
                                opciones: [ { v: "off", t: "Imagen fija (más fluido)" }, { v: "on", t: "Animados (gasta fluidez)" } ]
                            }
                            Etiqueta { texto: "PALETA (SALE DEL FONDO)" }
                            Row {
                                spacing: 12
                                Repeater {
                                    model: [ root.arena, root.terracota, root.salvia, root.pizarra ]
                                    Rectangle { required property color modelData; width: 38; height: 38; radius: 19; color: modelData; border.width: 1; border.color: Qt.alpha(root.arena, 0.25) }
                                }
                            }
                            Seccion {
                                titulo: "ANIMACIÓN DE VENTANAS"; clave: "anim"; actual: root.animActual
                                opciones: [ { v: "slide", t: "Deslizar" }, { v: "zoom", t: "Zoom" }, { v: "suave", t: "Suave" }, { v: "elastico", t: "Elástico" }, { v: "original", t: "Original" } ]
                            }
                            Seccion {
                                titulo: "DESENFOQUE (BLUR)"; clave: "blur"; actual: root.blurActual
                                opciones: [ { v: "ninguno", t: "Ninguno" }, { v: "suave", t: "Suave" }, { v: "medio", t: "Medio" }, { v: "fuerte", t: "Fuerte" }, { v: "extremo", t: "Extremo" } ]
                            }
                            Seccion {
                                titulo: "ANIMACIÓN DE LA BARRA"; clave: "barra"; actual: root.animBarra
                                opciones: [ { v: "ninguna", t: "Ninguna" }, { v: "fundido", t: "Fundido" }, { v: "deslizar", t: "Deslizar" }, { v: "rebote", t: "Rebote" } ]
                            }
                        }

                        // ═══ TECLADO Y RATÓN ═══
                        Pagina {
                            visible: root.ajustesPagina === "entrada"
                            Titulo { texto: "Teclado y ratón" }
                            Seccion {
                                titulo: "DISTRIBUCIÓN DEL TECLADO"; clave: "teclado"; actual: root.tecladoActual
                                opciones: [ { v: "latam", t: "Latinoamericano" }, { v: "us", t: "Inglés (EE. UU.)" }, { v: "es", t: "Español (España)" } ]
                            }
                            Etiqueta { texto: "TOUCHPAD" }
                            Fila {
                                etiqueta: "Desplazamiento natural"
                                detalle: "El contenido se mueve en la dirección de tus dedos"
                                Interruptor { encendido: root.scrollNatActual; onAlternar: root.aplicar("scrollnat", root.scrollNatActual ? "off" : "on") }
                            }
                            Fila {
                                etiqueta: "Tocar para hacer clic"
                                detalle: "Un toque en el touchpad equivale a un clic"
                                Interruptor { encendido: root.tapActual; onAlternar: root.aplicar("tap", root.tapActual ? "off" : "on") }
                            }
                            Seccion {
                                titulo: "VELOCIDAD DEL PUNTERO"; clave: "sens"; actual: root.sensActual
                                opciones: [ { v: "-0.5", t: "Muy lenta" }, { v: "-0.25", t: "Lenta" }, { v: "0", t: "Normal" }, { v: "0.25", t: "Rápida" }, { v: "0.5", t: "Muy rápida" } ]
                            }
                        }

                        // ═══ ACCESIBILIDAD ═══
                        Pagina {
                            visible: root.ajustesPagina === "accesibilidad"
                            Titulo { texto: "Accesibilidad" }
                            Seccion {
                                titulo: "TAMAÑO DEL TEXTO"; clave: "texto"; actual: String(root.esc)
                                opciones: [ { v: "1", t: "Normal" }, { v: "1.15", t: "Grande" }, { v: "1.3", t: "Muy grande" }, { v: "1.5", t: "Enorme" } ]
                            }
                            Seccion {
                                titulo: "TAMAÑO DEL CURSOR"; clave: "cursor"; actual: root.cursorActual
                                opciones: [ { v: "24", t: "Normal" }, { v: "32", t: "Grande" }, { v: "40", t: "Muy grande" }, { v: "48", t: "Enorme" } ]
                            }
                            Fila {
                                etiqueta: "Alto contraste"
                                detalle: "Texto en blanco o negro puro y paneles opacos"
                                Interruptor { encendido: root.contrasteAlto; onAlternar: root.aplicar("contraste", root.contrasteAlto ? "off" : "on") }
                            }
                            Fila {
                                etiqueta: "Reducir movimiento"
                                detalle: "Quita las animaciones de ventanas y de la barra"
                                Interruptor { encendido: !root.movimientoActual; onAlternar: root.aplicar("movimiento", root.movimientoActual ? "off" : "on") }
                            }
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap
                                text: "El tamaño del cursor se aplica del todo al abrir una app nueva."
                                color: Qt.alpha(root.arena, 0.4)
                                font { family: root.fuente; pixelSize: 12 * root.esc; weight: Font.Light }
                            }
                        }

                        // ═══ ENERGÍA ═══
                        Pagina {
                            visible: root.ajustesPagina === "energia"
                            Titulo { texto: "Energía" }
                            Fila {
                                etiqueta: "Batería"
                                detalle: root.cargando ? "Cargando" : "Descargando"
                                Text {
                                    text: Math.round(root.bateria * 100) + "%"
                                    color: root.bateria < 0.2 && !root.cargando ? root.terracota : root.arena
                                    font { family: root.fuente; pixelSize: 22 * root.esc; weight: Font.Light }
                                }
                            }
                            Seccion {
                                titulo: "MODO DE ENERGÍA"; clave: "perfil"; actual: root.perfilActual
                                opciones: [ { v: "power-saver", t: "Ahorro" }, { v: "balanced", t: "Equilibrado" }, { v: "performance", t: "Rendimiento" } ]
                            }
                            Etiqueta { texto: "SESIÓN" }
                            Flow {
                                width: parent.width
                                spacing: 10
                                Opcion { texto: "Bloquear"; onClic: { root.ajustesAbierto = false; Quickshell.execDetached(["qs", "-c", "miarch", "ipc", "call", "lock", "lock"]) } }
                                Confirmar { texto: "Suspender"; onConfirmado: Quickshell.execDetached(["systemctl", "suspend"]) }
                                Confirmar { texto: "Cerrar sesión"; onConfirmado: Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.exit()"]) }
                                Confirmar { texto: "Reiniciar"; onConfirmado: Quickshell.execDetached(["systemctl", "reboot"]) }
                                Confirmar { texto: "Apagar"; onConfirmado: Quickshell.execDetached(["systemctl", "poweroff"]) }
                            }
                            Text {
                                width: parent.width; wrapMode: Text.WordWrap
                                text: "Reiniciar, apagar y cerrar sesión piden una segunda pulsación para confirmar."
                                color: Qt.alpha(root.arena, 0.4)
                                font { family: root.fuente; pixelSize: 12 * root.esc; weight: Font.Light }
                            }
                        }

                        // ═══ SISTEMA ═══
                        Pagina {
                            visible: root.ajustesPagina === "sistema"
                            Titulo { texto: "Sistema" }
                            Fila { etiqueta: "Equipo"; detalle: (root.infoSistema.equipo || "") + "  ·  " + (root.infoSistema.usuario || "") }
                            Fila { etiqueta: "Sistema operativo"; detalle: (root.infoSistema.sistema || "") + "  ·  kernel " + (root.infoSistema.kernel || "") }
                            Fila { etiqueta: "Procesador"; detalle: root.infoSistema.cpu || "" }
                            Fila { etiqueta: "Memoria"; detalle: (root.infoSistema.ram_usada || 0) + " de " + (root.infoSistema.ram_total || 0) + " GB en uso" }
                            Fila { etiqueta: "Disco"; detalle: (root.infoSistema.disco_usado || 0) + " de " + (root.infoSistema.disco_total || 0) + " GB usados" }
                            Fila { etiqueta: "Encendido hace"; detalle: root.infoSistema.encendido || "" }
                            Fila { etiqueta: "Zona horaria"; detalle: root.infoSistema.zona || "" }
                            Fila { etiqueta: "Idioma"; detalle: root.infoSistema.idioma || "" }
                            Etiqueta { texto: "MANTENIMIENTO" }
                            Row {
                                spacing: 10
                                Opcion { texto: "Actualizar el sistema"; onClic: Quickshell.execDetached(["kitty", "sh", "-c", "yay -Syu; echo; echo 'Listo. Enter para cerrar'; read"]) }
                            }
                        }
                    }
                }
            }
        }
    }

    // ═════════════════ LANZADOR DE APPS ═════════════════
    property bool lanzadorAbierto: false
    property string consultaLanz: ""
    property var usoApps: ({})          // veces que has abierto cada app (para ordenar por uso)

    // Apps que no tiene sentido ofrecer (herramientas técnicas o que no aplican a este equipo)
    readonly property var appsOcultas: ["nm-connection-editor", "qv4l2", "qvidcap", "xgps", "xgpsspeed", "rofi-theme-selector"]

    FileView {
        path: Quickshell.env("HOME") + "/.config/miarch/uso.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.usoApps = JSON.parse(text()) } catch (e) {} }
    }

    // Índice de búsqueda: se calcula UNA vez (y solo cuando cambia la lista de apps), no en cada tecla
    readonly property var indiceApps: DesktopEntries.applications.values
        .filter(e => !e.noDisplay && root.appsOcultas.indexOf(e.id) < 0)
        .map(e => {
            const n = e.name.toLowerCase()
            return { e: e, id: e.id, n: n, pal: n.split(/[\s\-_.]+/),
                     x: ((e.genericName || "") + " " + (e.comment || "") + " " + (e.keywords || []).join(" ")).toLowerCase() }
        })

    // 0 = mejor coincidencia · -1 = no coincide
    function puntuarApp(it, q) {
        if (it.n === q) return 0
        if (it.n.startsWith(q)) return 1
        for (let k = 0; k < it.pal.length; k++) if (it.pal[k].startsWith(q)) return 2
        if (it.n.indexOf(q) >= 0) return 3
        if (it.x.indexOf(q) >= 0) return 4
        if (q.length < 3) return -1                 // las abreviaturas de 1-2 letras darían falsas coincidencias
        let i = 0                                   // abreviaturas: "gcr" → Google ChRome
        for (let k = 0; k < it.n.length && i < q.length; k++) if (it.n[k] === q[i]) i++
        return i === q.length ? 5 : -1
    }
    function filtrarApps(q) {
        q = q.trim().toLowerCase()
        const uso = root.usoApps
        const veces = it => uso[it.id] || 0
        let lista
        if (q === "") lista = root.indiceApps.map(it => ({ it: it, p: 0 }))
        else {
            lista = []
            for (const it of root.indiceApps) { const p = root.puntuarApp(it, q); if (p >= 0) lista.push({ it: it, p: p }) }
        }
        lista.sort((a, b) => (a.p - b.p) || (veces(b.it) - veces(a.it)) || (a.it.n < b.it.n ? -1 : a.it.n > b.it.n ? 1 : 0))
        return lista.slice(0, 7).map(x => x.it.e)
    }
    // Se calcula una sola vez (antes se repetía por cada monitor)
    readonly property var resultadosLanz: root.lanzadorAbierto ? root.filtrarApps(root.consultaLanz) : []

    function abrirApp(e) {
        if (!e) return
        root.usoApps = Object.assign({}, root.usoApps, { [e.id]: (root.usoApps[e.id] || 0) + 1 })
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/miarch-set", "uso", e.id])
        e.execute()
        root.lanzadorAbierto = false
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.lanzadorAbierto = !root.lanzadorAbierto }
        function open(): void { root.lanzadorAbierto = true }
        function close(): void { root.lanzadorAbierto = false }
        function search(texto: string): void { root.lanzadorAbierto = true; root.consultaLanz = texto }
    }

    // ═════════════════ BARRA DE VOLUMEN (sin animación: aparece, se actualiza y se va) ═════════════════
    // La llama miarch-volumen:  qs -c miarch ipc call osd mostrar <0-100> <texto> <1 si está en silencio>
    property bool osdVisible: false
    property int osdValor: 0
    property string osdTexto: ""
    property bool osdSilencio: false
    Timer { id: tOsd; interval: 1200; onTriggered: root.osdVisible = false }
    IpcHandler {
        target: "osd"
        function mostrar(valor: int, texto: string, silencio: int): void {
            root.osdValor = Math.max(0, Math.min(100, valor)); root.osdTexto = texto; root.osdSilencio = silencio === 1
            root.osdVisible = true; tOsd.restart()
        }
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            readonly property bool enEstaPantalla: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name : modelData === Quickshell.screens[0]
            visible: root.osdVisible && enEstaPantalla
            anchors { bottom: true }
            margins { bottom: 70 }
            implicitWidth: 300; implicitHeight: 52
            color: "transparent"
            mask: Region {}                                  // no captura el ratón
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "miarch-osd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            Rectangle {
                anchors.fill: parent; radius: 26
                color: Qt.alpha(Qt.lighter(root.fondo, 1.3), 0.95)
                border.width: 1; border.color: Qt.alpha(root.arena, 0.13)
                Text {
                    x: 22; anchors.verticalCenter: parent.verticalCenter
                    text: root.osdSilencio ? "MUDO" : "VOL"
                    color: root.osdSilencio ? Qt.alpha(root.arena, 0.5) : root.terracota
                    font { family: root.fuente; pixelSize: 11 * root.esc; weight: Font.Medium; letterSpacing: 3 }
                }
                Rectangle {
                    x: 78; width: parent.width - 78 - 66; height: 6; radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.alpha(root.arena, 0.14)
                    Rectangle {
                        width: parent.width * (root.osdSilencio ? 0 : root.osdValor) / 100; height: parent.height; radius: 3
                        color: root.terracota
                    }
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.osdTexto
                    color: root.arena
                    font { family: root.fuente; pixelSize: 13 * root.esc; weight: Font.Medium }
                }
            }
        }
    }

    // ═════════════════ NOTIFICACIONES ═════════════════
    // Quickshell es el servidor de notificaciones (reemplaza a dunst): arriba a la derecha, bajo la barra, con el mismo
    // estilo que los paneles. Se deslizan al entrar, muestran una cuenta atrás (se pausa con el ratón encima), barra de
    // progreso (volumen, brillo), botones de acción. Clic = abrir/cerrar, clic derecho = cerrar todas. Las críticas no se van solas.
    NotificationServer {
        id: servidorNotif
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => { n.tracked = true }
    }
    function notifCerrarTodas() { servidorNotif.trackedNotifications.values.slice().forEach(n => n.dismiss()) }
    IpcHandler { target: "notif"; function cerrar(): void { root.notifCerrarTodas() } }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            readonly property bool enEstaPantalla: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name : modelData === Quickshell.screens[0]
            visible: enEstaPantalla && servidorNotif.trackedNotifications.values.length > 0
            anchors { top: true; right: true }
            margins { top: 54; right: 16 }
            implicitWidth: 392
            implicitHeight: colNotif.implicitHeight
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "miarch-notif"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            Column {
                id: colNotif
                width: parent.width
                spacing: 10
                Repeater {
                    model: servidorNotif.trackedNotifications
                    Item {
                        id: tj
                        required property var modelData
                        required property int index
                        readonly property bool critica: modelData.urgency === NotificationUrgency.Critical
                        readonly property bool baja: modelData.urgency === NotificationUrgency.Low
                        readonly property int dur: critica ? 0 : (modelData.expireTimeout > 0 ? Math.round(modelData.expireTimeout * 1000) : (baja ? 4000 : 7000))
                        readonly property real valor: (modelData.hints && modelData.hints["value"] !== undefined) ? Number(modelData.hints["value"]) : -1
                        readonly property string rutaIcono: modelData.image !== "" ? modelData.image
                            : (modelData.appIcon === "" ? "" : (modelData.appIcon.startsWith("/") ? "file://" + modelData.appIcon : Quickshell.iconPath(modelData.appIcon, true)))
                        property real entrada: 0
                        property real resta: 1
                        visible: index < 5
                        width: colNotif.width
                        height: visible ? tarjeta.height : 0
                        Component.onCompleted: entrada = 1
                        Behavior on entrada { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                        NumberAnimation { id: cuenta; target: tj; property: "resta"; from: 1; to: 0; duration: Math.max(1, tj.dur)
                                          running: tj.dur > 0; paused: hov.hovered; onFinished: tj.modelData.expire() }
                        Connections {   // si la app reemplaza la notificación (volumen, brillo…), vuelve a empezar la cuenta atrás
                            target: tj.modelData
                            function onBodyChanged() { if (tj.dur > 0) cuenta.restart() }
                            function onSummaryChanged() { if (tj.dur > 0) cuenta.restart() }
                        }
                        HoverHandler { id: hov }

                        Rectangle {
                            id: tarjeta
                            width: parent.width
                            x: (1 - tj.entrada) * 80
                            opacity: Math.min(1, tj.entrada)
                            height: cuerpo.implicitHeight + 34
                            radius: 18
                            color: Qt.alpha(Qt.lighter(root.fondo, 1.3), 0.95)
                            border.width: 1
                            border.color: tj.critica ? Qt.alpha("#b8665f", 0.85) : Qt.alpha(root.arena, hov.hovered ? 0.28 : 0.13)
                            Behavior on border.color { ColorAnimation { duration: 200 } }
                            Rectangle {   // franja de color a la izquierda: acento, o rojo mate si es crítica
                                x: 0; y: 18; width: 3; height: parent.height - 36; radius: 1.5
                                color: tj.critica ? "#b8665f" : root.terracota
                                opacity: tj.baja ? 0.35 : 0.9
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) { root.notifCerrarTodas(); return }
                                    for (let i = 0; i < tj.modelData.actions.length; i++)
                                        if (tj.modelData.actions[i].identifier === "default") { tj.modelData.actions[i].invoke(); break }
                                    tj.modelData.dismiss()
                                }
                            }
                            Row {
                                id: cuerpo
                                x: 20; y: 17
                                width: parent.width - 36
                                spacing: 14
                                Rectangle {   // icono de la app (o su inicial)
                                    width: 46; height: 46; radius: 13
                                    color: Qt.alpha(root.arena, 0.08)
                                    Image {
                                        id: ico
                                        anchors.centerIn: parent
                                        width: 30; height: 30
                                        source: tj.rutaIcono
                                        sourceSize: Qt.size(64, 64)
                                        fillMode: Image.PreserveAspectFit; smooth: true
                                        visible: status === Image.Ready
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: !ico.visible
                                        text: tj.modelData.appName !== "" ? tj.modelData.appName.charAt(0).toUpperCase() : "!"
                                        color: tj.critica ? "#b8665f" : root.terracota
                                        font { family: root.fuente; pixelSize: 20 * root.esc; weight: Font.Medium }
                                    }
                                }
                                Column {
                                    width: parent.width - 46 - 14
                                    spacing: 4
                                    Item {
                                        width: parent.width; height: nombreApp.implicitHeight
                                        Text {
                                            id: nombreApp
                                            width: parent.width - 24; elide: Text.ElideRight
                                            text: tj.modelData.appName.toUpperCase()
                                            color: Qt.alpha(root.arena, 0.5)
                                            font { family: root.fuente; pixelSize: 10 * root.esc; weight: Font.Medium; letterSpacing: 3 }
                                        }
                                        Text {   // cerrar esta notificación
                                            anchors.right: parent.right
                                            text: "\u2715"
                                            color: xz.containsMouse ? root.terracota : Qt.alpha(root.arena, 0.4)
                                            font { family: root.fuente; pixelSize: 11 * root.esc }
                                            MouseArea { id: xz; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                        onClicked: tj.modelData.dismiss() }
                                        }
                                    }
                                    Text {
                                        width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                                        text: tj.modelData.summary
                                        color: root.arena
                                        font { family: root.fuente; pixelSize: 15 * root.esc; weight: Font.Medium }
                                    }
                                    Text {
                                        visible: tj.modelData.body !== ""
                                        width: parent.width; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                                        textFormat: Text.StyledText
                                        text: tj.modelData.body
                                        color: Qt.alpha(root.arena, 0.72)
                                        font { family: root.fuente; pixelSize: 13 * root.esc; weight: Font.Light }
                                    }
                                    Rectangle {   // barra de progreso (volumen, brillo…)
                                        visible: tj.valor >= 0
                                        width: parent.width; height: 6; radius: 3
                                        color: Qt.alpha(root.arena, 0.12)
                                        Rectangle {
                                            width: parent.width * Math.max(0, Math.min(100, tj.valor)) / 100; height: parent.height; radius: 3
                                            color: root.terracota
                                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                    Row {   // botones de acción
                                        spacing: 8
                                        topPadding: 4
                                        Repeater {
                                            model: tj.modelData.actions
                                            Rectangle {
                                                required property var modelData
                                                visible: modelData.identifier !== "default"
                                                width: visible ? etqAccion.implicitWidth + 24 : 0; height: visible ? 28 : 0; radius: 14
                                                color: az.containsMouse ? Qt.alpha(root.terracota, 0.25) : "transparent"
                                                border.width: 1; border.color: Qt.alpha(root.terracota, 0.7)
                                                Behavior on color { ColorAnimation { duration: 150 } }
                                                Text { id: etqAccion; anchors.centerIn: parent; text: modelData.text; color: root.arena
                                                       font { family: root.fuente; pixelSize: 12 * root.esc; weight: Font.Medium } }
                                                MouseArea { id: az; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                            onClicked: { modelData.invoke(); tj.modelData.dismiss() } }
                                            }
                                        }
                                    }
                                }
                            }
                            Rectangle {   // cuenta atrás: se vacía hasta que la notificación se va
                                visible: tj.dur > 0
                                x: 20; y: parent.height - 5
                                width: (parent.width - 40) * tj.resta; height: 2; radius: 1
                                color: Qt.alpha(root.terracota, hov.hovered ? 0.8 : 0.45)
                            }
                        }
                    }
                }
            }
        }
    }

    // ═════════════════ MENÚ DE IA (Super + C) ═════════════════
    // Primer nivel: una fila por herramienta. Si tiene varias formas de abrirse (terminal y app), al elegirla salen sus
    // opciones. Las de terminal se abren en kitty. Solo se pueden lanzar las que están instaladas.
    property bool iaAbierto: false
    property int iaNivel: 0            // 0 = herramientas, 1 = opciones de la herramienta elegida
    property int iaGrupo: 0
    property int iaSel: 0
    property var iaDisp: []
    readonly property var iaGrupos: [
        { t: "Claude Desktop", d: "La app de Claude, con ventana propia", logo: "claude", c: "#c8745a", m: "C", items: [
            { t: "Claude Desktop", d: "La app de Claude, con ventana propia", tipo: "APP", logo: "claude", c: "#c8745a", m: "C", bin: "claude-desktop", cmd: "claude-desktop" } ] },
        { t: "Codex App", d: "La app de ChatGPT con Codex (vista previa)", logo: "openai", c: "#86a595", m: "Cx", items: [
            { t: "Codex App", d: "La app de ChatGPT con Codex (vista previa)", tipo: "APP", logo: "openai", c: "#86a595", m: "Cx", bin: "chatgpt", cmd: "chatgpt" } ] },
        { t: "Antigravity", d: "La app de agentes de Google (2.0)", logo: "antigravity", c: "#7d9bc0", m: "A", items: [
            { t: "Antigravity", d: "La app de agentes de Google (2.0)", tipo: "APP", logo: "antigravity", c: "#7d9bc0", m: "A", bin: "antigravity", cmd: "antigravity" } ] },
        { t: "Hermes Desktop", d: "La app oficial de Hermes (Nous Research)", logo: "hermes", c: "#c0a06a", m: "H", items: [
            { t: "Hermes Desktop", d: "La app oficial de Hermes (Nous Research)", tipo: "APP", logo: "hermes", c: "#c0a06a", m: "H", bin: "hermes", cmd: "hermes desktop" } ] }
    ]
    // lo que se ve ahora: las herramientas o las opciones de la elegida
    readonly property var iaVisibles: root.iaNivel === 0 ? root.iaGrupos : root.iaGrupos[root.iaGrupo].items
    function iaHay(it) { return root.iaDisp.indexOf(it.bin) >= 0 }
    function iaHayGrupo(g) { return g.items.some(x => root.iaHay(x)) }
    function iaLanzar(it) {
        if (!root.iaHay(it)) return
        root.iaAbierto = false
        Quickshell.execDetached(["sh", "-c", "PATH=\"$HOME/.local/bin:$PATH\"; " + it.cmd])
    }
    function iaElegir(i) {
        if (root.iaNivel === 1) { root.iaLanzar(root.iaGrupos[root.iaGrupo].items[i]); return }
        const g = root.iaGrupos[i]
        if (g.items.length > 1) { root.iaGrupo = i; root.iaNivel = 1; root.iaSel = 0 }     // varias formas: se muestran
        else root.iaLanzar(g.items[0])
    }
    function iaAtras() { if (root.iaNivel === 1) { root.iaNivel = 0; root.iaSel = root.iaGrupo } else root.iaAbierto = false }
    Process {
        id: pIa
        command: ["sh", "-c", "PATH=\"$HOME/.local/bin:$PATH\"; for b in claude-desktop chatgpt antigravity hermes; do command -v $b >/dev/null 2>&1 && echo $b; done"]
        stdout: StdioCollector { onStreamFinished: root.iaDisp = text.trim().split("\n") }
    }
    onIaAbiertoChanged: { if (root.iaAbierto) { root.iaNivel = 0; root.iaSel = 0; pIa.running = true } }
    IpcHandler {
        target: "ia"
        function toggle(): void { root.iaAbierto = !root.iaAbierto }
        function open(): void { root.iaAbierto = true }
        function close(): void { root.iaAbierto = false }
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            readonly property bool enEstaPantalla: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name : modelData === Quickshell.screens[0]
            visible: root.iaAbierto && enEstaPantalla
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "miarch-ia"
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Item {
                id: iaVista
                anchors.fill: parent
                focus: true
                property real entrada: 0
                Connections {
                    target: root
                    function onIaAbiertoChanged() { if (root.iaAbierto) { iaVista.entrada = 0; iaVista.entrada = 1; iaVista.forceActiveFocus() } }
                }
                Behavior on entrada { NumberAnimation { duration: 750; easing.type: Easing.OutQuint } }
                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape || event.key === Qt.Key_Left || event.key === Qt.Key_Backspace) {
                        if (event.key === Qt.Key_Escape || root.iaNivel === 1) root.iaAtras()
                        else return
                    }
                    else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) root.iaSel = Math.min(root.iaSel + 1, root.iaVisibles.length - 1)
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) root.iaSel = Math.max(root.iaSel - 1, 0)
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Right) root.iaElegir(root.iaSel)
                    else return
                    event.accepted = true
                }
                Rectangle { anchors.fill: parent; color: root.fondo; opacity: Math.min(1, iaVista.entrada) * 0.8 }
                MouseArea { anchors.fill: parent; onClicked: root.iaAbierto = false }

                Column {
                    x: parent.width * 0.5 - width / 2
                    y: parent.height * 0.5 - height / 2 + (1 - iaVista.entrada) * 40
                    opacity: Math.min(1, iaVista.entrada)
                    width: Math.min(parent.width * 0.5, 640)
                    spacing: 4
                    Text {   // título: "IA", o el nombre de la herramienta con una flecha para volver
                        text: root.iaNivel === 0 ? "IA" : "\u2039  " + root.iaGrupos[root.iaGrupo].t.toUpperCase()
                        color: Qt.alpha(root.arena, 0.85)
                        font { family: root.fuente; pixelSize: 30 * root.esc; weight: Font.Thin; letterSpacing: 9 }
                        bottomPadding: 14
                        MouseArea { anchors.fill: parent; enabled: root.iaNivel === 1; cursorShape: Qt.PointingHandCursor; onClicked: root.iaAtras() }
                    }
                    Repeater {
                        model: root.iaVisibles
                        Item {
                            required property var modelData
                            required property int index
                            readonly property bool sel: root.iaSel === index
                            readonly property bool esGrupo: root.iaNivel === 0
                            readonly property bool varios: esGrupo && modelData.items.length > 1
                            readonly property bool hay: esGrupo ? root.iaHayGrupo(modelData) : root.iaHay(modelData)
                            width: parent.width; height: 74 * root.esc
                            Rectangle {   // fondo de la fila elegida
                                anchors.fill: parent; radius: 14
                                color: Qt.alpha(modelData.c, sel ? 0.12 : 0)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Rectangle {   // ficha: el logo real sobre un cuadro suave (la inicial es el respaldo)
                                id: ficha
                                x: 14; anchors.verticalCenter: parent.verticalCenter
                                width: 50 * root.esc; height: width; radius: 14
                                color: Qt.alpha(root.arena, sel ? 0.16 : 0.08)
                                border.width: 1; border.color: Qt.alpha(modelData.c, sel && hay ? 0.8 : 0.18)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                Image {
                                    id: icoImg
                                    anchors.centerIn: parent
                                    width: parent.width * 0.62; height: width
                                    source: Qt.resolvedUrl("icons/" + modelData.logo + ".svg")
                                    sourceSize: Qt.size(96, 96)
                                    visible: status === Image.Ready
                                    opacity: hay ? 1 : 0.3
                                    fillMode: Image.PreserveAspectFit; smooth: true
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: !icoImg.visible
                                    text: modelData.m
                                    color: Qt.alpha(modelData.c, hay ? 1 : 0.35)
                                    font { family: root.fuente; pixelSize: 22 * root.esc; weight: Font.Medium }
                                }
                            }
                            Rectangle {   // etiqueta: APP, TERMINAL, o la flecha de las que tienen varias opciones
                                id: etiqueta
                                anchors.right: parent.right; anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: etqTipo.implicitWidth + 20; height: 24 * root.esc; radius: height / 2
                                color: "transparent"; border.width: 1; border.color: Qt.alpha(modelData.c, hay ? 0.75 : 0.25)
                                Text {
                                    id: etqTipo
                                    anchors.centerIn: parent
                                    text: varios ? "2 OPCIONES  \u203a" : (esGrupo ? modelData.items[0].tipo : modelData.tipo)
                                    color: Qt.alpha(modelData.c, hay ? 1 : 0.4)
                                    font { family: root.fuente; pixelSize: 10 * root.esc; weight: Font.Medium; letterSpacing: 3 }
                                }
                            }
                            Column {
                                x: 14 + 50 * root.esc + 16; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - x - etiqueta.width - 30
                                spacing: 3
                                Text {
                                    width: parent.width; elide: Text.ElideRight
                                    text: modelData.t
                                    color: root.arena
                                    opacity: hay ? (sel ? 1 : 0.75) : 0.35
                                    font { family: root.fuente; pixelSize: 22 * root.esc; weight: sel ? Font.Normal : Font.Light }
                                }
                                Text {
                                    width: parent.width; elide: Text.ElideRight
                                    text: hay ? modelData.d : (varios ? "ninguna está instalada" : "no está instalada")
                                    color: root.arena
                                    opacity: hay ? 0.5 : 0.3
                                    font { family: root.fuente; pixelSize: 12 * root.esc; weight: Font.Light }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: hay ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onEntered: root.iaSel = index
                                onClicked: root.iaElegir(index)
                            }
                        }
                    }
                    Text {
                        text: root.iaNivel === 0 ? "\u2191 \u2193 elegir    ENTER abrir    ESC cerrar" : "\u2191 \u2193 elegir    ENTER abrir    \u2190 volver    ESC volver"
                        color: Qt.alpha(root.arena, 0.3)
                        font { family: root.fuente; pixelSize: 11 * root.esc; weight: Font.Medium; letterSpacing: 3 }
                        topPadding: 22
                    }
                }
            }
        }
    }

    // ═════════════════ MENÚ DE ENERGÍA (Super + Shift + Esc) ═════════════════
    property bool energiaAbierto: false
    property int energiaSel: 0
    property int energiaConfirmar: -1
    property int energiaPestana: 0      // 0 = Energía, 1 = Atajos de teclado
    // Todos los atajos, de más a menos útil (lo mismo que docs/atajos.md). Super = la tecla de Windows.
    readonly property var atajosLista: [
        { k: "Super + Espacio",           d: "Abrir el lanzador: escribe y abre cualquier programa" },
        { k: "Super + Enter",             d: "Abrir una terminal" },
        { k: "Super + Shift + Q",         d: "Cerrar la ventana en la que estás" },
        { k: "Super + 1 … 0",             d: "Ir a ese escritorio (hay 10)" },
        { k: "Super + Shift + 1 … 0",     d: "Mandar la ventana a ese escritorio" },
        { k: "Super + Esc",               d: "Ajustes: red, sonido, pantalla, apariencia…" },
        { k: "Super + L",                 d: "Bloquear la pantalla" },
        { k: "Super + B",                 d: "Abrir el navegador (Chrome)" },
        { k: "Super + E",                 d: "Abrir los archivos (Dolphin)" },
        { k: "Super + flechas",           d: "Pasar el foco a la ventana de al lado" },
        { k: "Super + F",                 d: "Poner o quitar la ventana flotante" },
        { k: "Super + .",                 d: "Captura de una zona al portapapeles" },
        { k: "Super + W",                 d: "Cambiar el fondo (y los colores del sistema)" },
        { k: "Super + V",                 d: "Abrir VS Code" },
        { k: "Super + C",                 d: "Menú de IA: apps de escritorio de Claude, Codex, Antigravity y Hermes" },
        { k: "Super + clic izq. y arrastrar", d: "Mover la ventana" },
        { k: "Super + clic der. y arrastrar", d: "Cambiar el tamaño de la ventana" },
        { k: "Super + rueda del ratón",   d: "Cambiar de escritorio" },
        { k: "Super + J  /  Super + P",   d: "Cambiar la división de ventanas / pseudo-mosaico" },
        { k: "Super + S  /  Super + Shift + S", d: "Escritorio escondido: mostrarlo / mandarle la ventana" },
        { k: "Super + Shift + Espacio",   d: "Lanzador de respaldo (rofi)" },
        { k: "Volumen, brillo, multimedia", d: "Las teclas del portátil funcionan, también con la pantalla bloqueada" },
        { k: "Super + Shift + Esc",       d: "Este menú: energía y atajos" },
        { k: "Super + Ctrl + Shift + M",  d: "Salida de emergencia: cierra el escritorio al instante" }
    ]
    readonly property var energiaOpciones: [
        { t: "Bloquear",      g: "", c: false, cmd: ["qs", "-c", "miarch", "ipc", "call", "lock", "lock"] },
        // al suspender se bloquea primero: al despertar pide la contraseña
        { t: "Suspender",     g: "", c: false, cmd: ["sh", "-c", "qs -c miarch ipc call lock lock; sleep 1; systemctl suspend"] },
        { t: "Cerrar sesión", g: "", c: true,  cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { t: "Reiniciar",     g: "", c: true,  cmd: ["systemctl", "reboot"] },
        { t: "Apagar",        g: "", c: true,  cmd: ["systemctl", "poweroff"] }
    ]
    // las opciones que cierran todo piden una segunda pulsación (Enter o clic) para confirmar
    function energiaEjecutar(i) {
        const o = root.energiaOpciones[i]
        if (o.c && root.energiaConfirmar !== i) { root.energiaSel = i; root.energiaConfirmar = i; return }
        root.energiaAbierto = false
        Quickshell.execDetached(o.cmd)
    }
    onEnergiaAbiertoChanged: { root.energiaSel = 0; root.energiaConfirmar = -1; root.energiaPestana = 0 }
    IpcHandler {
        target: "power"
        function toggle(): void { root.energiaAbierto = !root.energiaAbierto }
        function open(): void { root.energiaAbierto = true }
        function close(): void { root.energiaAbierto = false }
        function atajos(): void { root.energiaAbierto = true; root.energiaPestana = 1 }   // abre directo la pestaña de atajos
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            readonly property bool enEstaPantalla: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name : modelData === Quickshell.screens[0]
            visible: root.energiaAbierto && enEstaPantalla
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "miarch-energia"
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Item {
                id: en
                anchors.fill: parent
                focus: true
                property real entrada: 0
                Connections {
                    target: root
                    function onEnergiaAbiertoChanged() { if (root.energiaAbierto) { en.entrada = 0; en.entrada = 1; en.forceActiveFocus() } }
                }
                Behavior on entrada { NumberAnimation { duration: 750; easing.type: Easing.OutQuint } }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) { if (root.energiaConfirmar >= 0) root.energiaConfirmar = -1; else root.energiaAbierto = false }
                    else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) { root.energiaPestana = 1 - root.energiaPestana; root.energiaConfirmar = -1 }
                    else if (root.energiaPestana === 1 && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) { }
                    else if (root.energiaPestana === 1 && (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)) listaAtajos.contentY = Math.min(listaAtajos.contentY + 72, Math.max(0, listaAtajos.contentHeight - listaAtajos.height))
                    else if (root.energiaPestana === 1 && (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)) listaAtajos.contentY = Math.max(listaAtajos.contentY - 72, 0)
                    else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) { root.energiaSel = Math.min(root.energiaSel + 1, root.energiaOpciones.length - 1); root.energiaConfirmar = -1 }
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) { root.energiaSel = Math.max(root.energiaSel - 1, 0); root.energiaConfirmar = -1 }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.energiaEjecutar(root.energiaSel)
                    else return
                    event.accepted = true
                }

                // velo del color del fondo; clic fuera = cerrar
                Rectangle { anchors.fill: parent; color: root.fondo; opacity: Math.min(1, en.entrada) * 0.8 }
                MouseArea { anchors.fill: parent; onClicked: root.energiaAbierto = false }

                Column {
                    x: parent.width * 0.5 - width / 2
                    y: parent.height * 0.5 - height / 2 + (1 - en.entrada) * 40
                    opacity: Math.min(1, en.entrada)
                    width: root.energiaPestana === 1 ? Math.min(parent.width * 0.62, 820) : Math.min(parent.width * 0.4, 520)
                    spacing: 6

                    Item {   // pestañas: Energía | Atajos (← → o clic)
                        width: parent.width; height: 28 * root.esc * 1.5 + 22
                        Row {
                            spacing: 38
                            Repeater {
                                model: ["ENERGÍA", "ATAJOS"]
                                Text {
                                    required property string modelData
                                    required property int index
                                    text: modelData
                                    color: Qt.alpha(root.arena, root.energiaPestana === index ? 0.85 : 0.25)
                                    font { family: root.fuente; pixelSize: 30 * root.esc; weight: Font.Thin; letterSpacing: 9 }
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.energiaPestana = index; root.energiaConfirmar = -1 } }
                                }
                            }
                        }
                    }
                    Repeater {
                        model: root.energiaOpciones
                        Item {
                            required property var modelData
                            required property int index
                            readonly property bool sel: root.energiaSel === index
                            readonly property bool pideConfirmar: root.energiaConfirmar === index
                            visible: root.energiaPestana === 0
                            width: parent.width; height: visible ? 64 : 0
                            Rectangle {   // marca de la opción elegida
                                width: 3; height: parent.height - 18; radius: 1.5
                                anchors.verticalCenter: parent.verticalCenter
                                color: root.terracota
                                opacity: sel ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                            Text {
                                x: 26; anchors.verticalCenter: parent.verticalCenter
                                text: modelData.g
                                color: sel ? root.terracota : root.arena
                                opacity: sel ? 1 : 0.5
                                font { family: root.fuente; pixelSize: 26 * root.esc }
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            Text {
                                x: 78; anchors.verticalCenter: parent.verticalCenter
                                text: pideConfirmar ? "¿SEGURO?   ENTER PARA CONFIRMAR" : modelData.t
                                color: pideConfirmar ? root.terracota : root.arena
                                opacity: sel ? 1 : 0.5
                                font { family: root.fuente; pixelSize: (pideConfirmar ? 18 : 30) * root.esc; weight: pideConfirmar ? Font.Medium : Font.Light; letterSpacing: pideConfirmar ? 4 : 0 }
                            }
                            MouseArea {
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onEntered: { if (root.energiaSel !== index) { root.energiaSel = index; root.energiaConfirmar = -1 } }
                                onClicked: root.energiaEjecutar(index)
                            }
                        }
                    }
                    Flickable {   // pestaña Atajos
                        id: listaAtajos
                        visible: root.energiaPestana === 1
                        width: parent.width
                        height: visible ? Math.min(contentHeight, en.height * 0.6) : 0
                        contentHeight: colAtajos.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        Column {
                            id: colAtajos
                            width: parent.width
                            spacing: 2
                            Repeater {
                                model: root.atajosLista
                                Row {
                                    required property var modelData
                                    width: colAtajos.width
                                    height: 38 * root.esc
                                    spacing: 18
                                    Text {
                                        width: 270 * root.esc; anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                        text: modelData.k
                                        color: root.terracota
                                        font { family: root.fuente; pixelSize: 14 * root.esc; weight: Font.Medium }
                                    }
                                    Text {
                                        width: parent.width - 270 * root.esc - 18; anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                        text: modelData.d
                                        color: root.arena; opacity: 0.85
                                        font { family: root.fuente; pixelSize: 14 * root.esc; weight: Font.Light }
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        text: root.energiaPestana === 0 ? "↑ ↓ elegir    ENTER aceptar    ← → pestaña    ESC cerrar" : "↑ ↓ desplazar    ← → pestaña    ESC cerrar"
                        color: Qt.alpha(root.arena, 0.3)
                        font { family: root.fuente; pixelSize: 11 * root.esc; weight: Font.Medium; letterSpacing: 3 }
                        topPadding: 22
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: ventanaLanz
            required property var modelData
            screen: modelData
            readonly property bool enEstaPantalla: Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name === modelData.name : modelData === Quickshell.screens[0]
            visible: root.lanzadorAbierto && enEstaPantalla
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "miarch-lanzador"
            WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Item {
                id: lz
                anchors.fill: parent
                property int seleccion: 0
                readonly property var resultados: root.resultadosLanz
                property real entrada: 0

                Connections {
                    target: root
                    function onLanzadorAbiertoChanged() {
                        if (root.lanzadorAbierto) { root.consultaLanz = ""; campo.text = ""; lz.seleccion = 0; lz.entrada = 0; lz.entrada = 1; campo.forceActiveFocus() }
                    }
                    function onConsultaLanzChanged() { if (campo.text !== root.consultaLanz) campo.text = root.consultaLanz }
                }
                Behavior on entrada { NumberAnimation { duration: 700; easing.type: Easing.OutQuint } }

                // velo del color del fondo; clic fuera = cerrar
                Rectangle {
                    anchors.fill: parent
                    color: root.fondo
                    opacity: Math.min(1, lz.entrada) * 0.74
                }
                MouseArea { anchors.fill: parent; onClicked: root.lanzadorAbierto = false }

                Column {
                    x: parent.width * 0.5 - width / 2
                    y: parent.height * 0.24 + (1 - lz.entrada) * 50
                    opacity: Math.min(1, lz.entrada)
                    width: Math.min(parent.width * 0.5, 760)
                    spacing: 16

                    // Buscador: texto grande y fino, sin caja
                    Item {
                        width: parent.width; height: 74
                        Text {
                            visible: campo.text.length === 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: "BUSCAR"
                            color: Qt.alpha(root.arena, 0.3)
                            font { family: root.fuente; pixelSize: 40 * root.esc; weight: Font.Thin; letterSpacing: 12 }
                        }
                        TextInput {
                            id: campo
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            color: root.arena
                            selectionColor: root.terracota
                            font { family: root.fuente; pixelSize: 40 * root.esc; weight: Font.Thin }
                            clip: true
                            onTextChanged: { if (root.consultaLanz !== text) root.consultaLanz = text; lz.seleccion = 0 }
                            Keys.onEscapePressed: root.lanzadorAbierto = false
                            Keys.onDownPressed: lz.seleccion = Math.min(lz.seleccion + 1, lz.resultados.length - 1)
                            Keys.onUpPressed: lz.seleccion = Math.max(lz.seleccion - 1, 0)
                            Keys.onTabPressed: lz.seleccion = (lz.seleccion + 1) % Math.max(1, lz.resultados.length)
                            Keys.onReturnPressed: root.abrirApp(lz.resultados[lz.seleccion])
                        }
                    }
                    // línea que se estira al escribir
                    Rectangle {
                        height: 2; radius: 1
                        color: root.terracota
                        width: parent.width * Math.min(1, 0.12 + campo.text.length * 0.07)
                        Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutQuint } }
                        Behavior on color { ColorAnimation { duration: 800 } }
                    }
                    Item { width: 1; height: 8 }

                    // Resultados: 7 filas FIJAS que cambian de contenido (no se destruyen ni se recargan los íconos en cada tecla)
                    Item {
                        width: parent.width
                        height: lz.resultados.length * 58

                        Rectangle {   // marcador que se desliza
                            width: 3; height: 34; radius: 2
                            color: root.terracota
                            y: lz.seleccion * 58 + 12
                            visible: lz.resultados.length > 0
                            Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.OutQuint } }
                            Behavior on color { ColorAnimation { duration: 800 } }
                        }
                        Repeater {
                            model: 7
                            Item {
                                required property int index
                                readonly property var app: index < lz.resultados.length ? lz.resultados[index] : null
                                readonly property bool sel: index === lz.seleccion
                                visible: app !== null
                                y: index * 58; width: parent.width; height: 58
                                x: sel ? 14 : 0
                                Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutQuint } }

                                readonly property string rutaIcono: app ? Quickshell.iconPath(app.icon, true) : ""
                                IconImage {
                                    x: 18; anchors.verticalCenter: parent.verticalCenter
                                    implicitWidth: 30; implicitHeight: 30
                                    source: parent.rutaIcono
                                    visible: parent.rutaIcono !== ""
                                    opacity: sel ? 1 : 0.55
                                }
                                Rectangle {   // sin ícono en el tema: círculo con la inicial
                                    x: 18; anchors.verticalCenter: parent.verticalCenter
                                    width: 30; height: 30; radius: 15
                                    visible: parent.rutaIcono === ""
                                    color: Qt.alpha(root.terracota, sel ? 0.9 : 0.4)
                                    Text {
                                        anchors.centerIn: parent
                                        text: app ? app.name.charAt(0).toUpperCase() : ""
                                        color: root.fondo
                                        font { family: root.fuente; pixelSize: 15 * root.esc; weight: Font.Medium }
                                    }
                                }
                                Text {
                                    x: 70; anchors.verticalCenter: parent.verticalCenter
                                    text: app ? app.name : ""
                                    color: sel ? root.arena : Qt.alpha(root.arena, 0.5)
                                    font { family: root.fuente; pixelSize: 22 * root.esc; weight: sel ? Font.Normal : Font.Light }
                                    Behavior on color { ColorAnimation { duration: 250 } }
                                }
                                MouseArea {
                                    anchors.fill: parent; hoverEnabled: true
                                    onEntered: lz.seleccion = index
                                    onClicked: root.abrirApp(app)
                                }
                            }
                        }
                    }
                    Text {
                        visible: campo.text.length > 0 && lz.resultados.length === 0
                        text: "Sin resultados"
                        color: Qt.alpha(root.arena, 0.4)
                        font { family: root.fuente; pixelSize: 18 * root.esc; weight: Font.Light; letterSpacing: 3 }
                    }
                }
            }
        }
    }

    // ═════════════════ PANTALLA DE BLOQUEO ═════════════════
    property string clave: ""
    property bool verificando: false
    property bool errorClave: false
    property bool accesoOk: false                    // la contraseña fue correcta: suena, sale el log y se abre
    property real apertura: 0                        // 0 → 1 durante la secuencia de desbloqueo
    property var lineasLog: []
    property string wallpaperRuta: ""
    signal sacudir()

    FileView {
        id: fWall
        path: Quickshell.env("HOME") + "/.cache/miarch-wallpaper"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.wallpaperRuta = text().trim()
    }

    PamContext {
        id: pam
        config: "system-auth"
        onPamMessage: { if (pam.responseRequired) pam.respond(root.clave) }
        onCompleted: result => {
            root.verificando = false
            root.clave = ""
            if (result === PamResult.Success) {
                root.errorClave = false
                root.iniciarApertura()
            } else {
                root.errorClave = true
                root.sacudir()
            }
        }
        onError: err => { root.verificando = false; root.clave = ""; root.errorClave = true; root.sacudir() }
    }

    // Desbloqueo: suena, aparece el log real del sistema tecleándose y luego se despeja la pantalla (se ve el fondo nítido)
    function iniciarApertura() {
        if (root.accesoOk) return
        root.accesoOk = true
        root.apertura = 0
        Quickshell.execDetached(["pw-play", "--volume=0.6", Quickshell.env("HOME") + "/.config/quickshell/miarch/sonidos/desbloqueo.wav"])
        pLog.running = true
        tPorSiNoHayLog.start()
    }
    Process {
        id: pLog
        command: ["sh", "-c", "journalctl -b -n 26 --no-pager -o short-monotonic 2>/dev/null || journalctl --user -b -n 26 --no-pager -o short-monotonic 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n").map(x => x.trim()).filter(x => x.length > 0)
                root.lineasLog = l.length > 0 ? l : ["[    0.000000] miarch: sesión desbloqueada"]
                tPorSiNoHayLog.stop()
                animApertura.restart()
            }
        }
    }
    Timer { id: tPorSiNoHayLog; interval: 600; onTriggered: { if (!animApertura.running) { root.lineasLog = ["[    0.000000] miarch: sesión desbloqueada"]; animApertura.restart() } } }
    NumberAnimation {
        id: animApertura
        target: root; property: "apertura"; from: 0; to: 1; duration: 3600
        onFinished: { sesion.locked = false; root.accesoOk = false; root.apertura = 0 }
    }
    function intentar() {
        if (root.clave.length === 0 || root.verificando) return
        root.verificando = true
        if (!pam.start()) { root.verificando = false; root.errorClave = true; root.sacudir() }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.clave = ""; root.errorClave = false; root.accesoOk = false; root.apertura = 0; sesion.locked = true }
    }

    // Solo para pruebas: MIARCH_LOCK_TEST=1 qs -c miarch  → se desbloquea solo a los 9 s
    Timer {
        running: sesion.locked && Quickshell.env("MIARCH_LOCK_TEST") === "1"
        interval: 9000
        onTriggered: sesion.locked = false
    }

    WlSessionLock {
        id: sesion
        locked: false

        WlSessionLockSurface {
            color: root.fondo

            Item {
                id: candado
                anchors.fill: parent
                focus: true

                property real entrada: 0
                Component.onCompleted: { forceActiveFocus(); entrada = 1 }
                Behavior on entrada { NumberAnimation { duration: 1500; easing.type: Easing.OutQuint } }

                // 0 durante el log y 0→1 cuando la pantalla se despeja (último 38 % de la secuencia)
                // Secuencia de cine (3,6 s): p = progreso 0..1. El golpe del sonido cae en p = 0.76.
                readonly property real p: root.apertura
                function suave(x) { x = Math.max(0, Math.min(1, x)); return x * x * (3 - 2 * x) }
                readonly property real abre: suave((p - 0.80) / 0.20)             // llega el fondo nítido
                readonly property real barras: p < 0.86 ? suave(p / 0.12) : 1 - suave((p - 0.86) / 0.14)   // barras de cine

                Keys.onPressed: event => {
                    if (root.verificando || root.accesoOk) return
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.intentar(); return }
                    if (event.key === Qt.Key_Backspace) root.clave = root.clave.slice(0, -1)
                    else if (event.key === Qt.Key_Escape) root.clave = ""
                    else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32) root.clave += event.text
                    else return
                    root.errorClave = false
                }

                // Wallpaper desenfocado + velo del color de fondo
                Image {
                    id: imgFondo
                    anchors.fill: parent
                    source: root.wallpaperRuta !== "" ? "file://" + encodeURI(root.wallpaperRuta) : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    asynchronous: true
                }
                MultiEffect {
                    anchors.fill: parent
                    source: imgFondo
                    blurEnabled: true; blurMax: 64; blur: 1.0
                    opacity: 1 - candado.abre; scale: 1 + 0.12 * candado.p
                    autoPaddingEnabled: false
                }
                Rectangle { anchors.fill: parent; color: root.fondo; opacity: 0.58 * (1 - candado.abre) }
                // Al desbloquear el fondo se acerca y se enfoca, como si entraras en él: llega a escala 1, igual que el escritorio
                Image {
                    anchors.fill: parent
                    source: imgFondo.source
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: candado.abre > 0
                    opacity: candado.abre
                    scale: 1 + 0.12 * (1 - candado.abre)               // sigue el avance lento y se asienta en escala 1, igual que el escritorio
                }

                // ── Secuencia de cine ──
                // Viñeta: los bordes se oscurecen mientras dura
                Repeater {
                    model: [ { l: true }, { l: false } ]
                    Rectangle {
                        required property var modelData
                        visible: root.accesoOk
                        x: modelData.l ? 0 : parent.width - width; width: parent.width * 0.22; height: parent.height
                        opacity: 0.55 * candado.suave(candado.p / 0.2) * (1 - candado.abre)
                        gradient: Gradient { orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: modelData.l ? "black" : "transparent" }
                            GradientStop { position: 1; color: modelData.l ? "transparent" : "black" } }
                    }
                }
                // Título: MIARCH, letras muy separadas que se abren despacio
                Column {
                    visible: root.accesoOk && candado.p > 0.45
                    anchors.centerIn: parent
                    spacing: candado.height * 0.012
                    opacity: candado.suave((candado.p - 0.46) / 0.14) * (1 - candado.suave((candado.p - 0.84) / 0.08))
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "MIARCH"
                        color: root.arena
                        font { family: root.fuente; pixelSize: candado.height * 0.085; weight: Font.Thin
                               letterSpacing: candado.height * (0.012 + 0.03 * candado.suave((candado.p - 0.46) / 0.4)) }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "ACCESO CONCEDIDO"
                        color: root.terracota
                        opacity: 0.85
                        font { family: root.fuente; pixelSize: candado.height * 0.016; weight: Font.Medium; letterSpacing: 9 }
                    }
                }
                // Destello anamórfico: una línea de luz horizontal que cruza la pantalla en el golpe del sonido
                Item {
                    visible: candado.p > 0.66 && candado.p < 0.9
                    anchors.fill: parent
                    opacity: Math.sin(Math.PI * Math.max(0, Math.min(1, (candado.p - 0.66) / 0.22)))
                    Rectangle {   // resplandor suave
                        width: parent.width * candado.suave((candado.p - 0.66) / 0.16); height: candado.height * 0.07
                        x: (parent.width - width) / 2; y: parent.height / 2 - height / 2
                        gradient: Gradient { orientation: Gradient.Vertical
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 0.5; color: Qt.alpha("#ffe9c8", 0.22) }
                            GradientStop { position: 1; color: "transparent" } }
                    }
                    Rectangle {   // el filo brillante
                        width: parent.width * candado.suave((candado.p - 0.66) / 0.16); height: 3
                        x: (parent.width - width) / 2; y: parent.height / 2 - 1.5
                        gradient: Gradient { orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 0.5; color: "#fff3e0" }
                            GradientStop { position: 1; color: "transparent" } }
                    }
                }
                // Luz: todo se aclara tras el golpe y se disuelve en el escritorio
                Rectangle {
                    anchors.fill: parent
                    color: "#fff3e0"
                    visible: opacity > 0
                    opacity: 0.62 * candado.suave((candado.p - 0.76) / 0.12) * (1 - candado.suave((candado.p - 0.90) / 0.10))
                }
                // Barras de cine arriba y abajo
                Repeater {
                    model: [ true, false ]
                    Rectangle {
                        required property bool modelData
                        visible: candado.barras > 0
                        color: "black"
                        width: parent.width; height: candado.height * 0.128 * candado.barras
                        y: modelData ? 0 : parent.height - height
                    }
                }

                // Música (solo si hay un reproductor): tarjeta grande a la derecha del reloj
                Item {
                    id: musicaBloqueo
                    readonly property var p: root.jugador
                    readonly property real avance: (p && p.length > 0) ? Math.min(1, p.position / p.length) : 0
                    readonly property real lado: Math.min(candado.height * 0.30, candado.width * 0.2)
                    x: candado.width * 0.46
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -candado.height * 0.09 + (1 - candado.entrada) * 60
                    width: lado + candado.height * 0.04 + Math.min(candado.width * 0.24, 460)
                    height: lado
                    opacity: p ? Math.min(1, candado.entrada) : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                    Timer {
                        running: musicaBloqueo.visible && musicaBloqueo.p !== null && musicaBloqueo.p.isPlaying
                        interval: 1000; repeat: true
                        onTriggered: musicaBloqueo.p.positionChanged()
                    }

                    Rectangle {
                        id: portadaBloqueo
                        width: musicaBloqueo.lado; height: width
                        color: Qt.alpha(root.arena, 0.08)
                        border.width: 1; border.color: Qt.alpha(root.arena, 0.15)
                        Image {
                            id: imgPortadaBloqueo
                            anchors.fill: parent
                            source: musicaBloqueo.p ? root.portadaGrande(musicaBloqueo.p.trackArtUrl) : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true
                            sourceSize.width: 640; sourceSize.height: 640
                            smooth: true; mipmap: true
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: imgPortadaBloqueo.status !== Image.Ready
                            text: "\uf001"
                            color: Qt.alpha(root.arena, 0.4)
                            font { family: root.fuente; pixelSize: candado.height * 0.06 }
                        }
                    }
                    Column {
                        x: portadaBloqueo.width + candado.height * 0.04
                        width: parent.width - x
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: candado.height * 0.012
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: musicaBloqueo.p ? (musicaBloqueo.p.trackTitle || "Sin título") : ""
                            color: root.arena
                            opacity: (musicaBloqueo.p && musicaBloqueo.p.isPlaying) ? 1 : 0.6
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            font { family: root.fuente; pixelSize: candado.height * 0.034; weight: Font.Medium }
                        }
                        Text {
                            width: parent.width; elide: Text.ElideRight
                            text: musicaBloqueo.p ? (musicaBloqueo.p.trackArtist || "").toUpperCase() : ""
                            color: root.terracota
                            font { family: root.fuente; pixelSize: candado.height * 0.016; weight: Font.Medium; letterSpacing: 4 }
                        }
                        Item {   // barra de progreso (clic para saltar)
                            width: parent.width; height: candado.height * 0.02
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 3; radius: 1.5; color: Qt.alpha(root.arena, 0.22)
                                Rectangle { width: parent.width * musicaBloqueo.avance; height: parent.height; radius: 1.5; color: root.terracota }
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: musicaBloqueo.p !== null && musicaBloqueo.p.canSeek
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: mouse => { musicaBloqueo.p.position = (mouse.x / width) * musicaBloqueo.p.length; musicaBloqueo.p.positionChanged() }
                            }
                        }
                        Row {
                            spacing: candado.height * 0.03
                            Repeater {
                                model: [ { g: "\uf048", a: "previous" }, { g: "play", a: "toggle" }, { g: "\uf051", a: "next" } ]
                                Text {
                                    required property var modelData
                                    text: modelData.g === "play" ? ((musicaBloqueo.p && musicaBloqueo.p.isPlaying) ? "\uf04c" : "\uf04b") : modelData.g
                                    color: modelData.a === "toggle" ? root.terracota : Qt.alpha(root.arena, 0.8)
                                    font { family: root.fuente; pixelSize: candado.height * 0.026 }
                                    MouseArea {
                                        anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor
                                        onClicked: { if (!musicaBloqueo.p) return
                                            if (modelData.a === "toggle") musicaBloqueo.p.togglePlaying()
                                            else if (modelData.a === "next") musicaBloqueo.p.next()
                                            else musicaBloqueo.p.previous() }
                                    }
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                leftPadding: candado.height * 0.01
                                text: musicaBloqueo.p ? (root.fmtTiempo(musicaBloqueo.p.position) + " / " + root.fmtTiempo(musicaBloqueo.p.length)) : ""
                                color: Qt.alpha(root.arena, 0.5)
                                font { family: root.fuente; pixelSize: candado.height * 0.016; weight: Font.Light }
                            }
                        }
                    }
                }

                // Log del sistema (el de verdad, de journalctl) tecleándose al desbloquear, y luego se despeja todo
                Item {
                    id: capaLog
                    visible: root.accesoOk
                    x: candado.width * 0.05; width: candado.width * 0.9
                    anchors.verticalCenter: parent.verticalCenter
                    height: colLog.implicitHeight
                    opacity: Math.min(1, root.apertura * 10) * (1 - candado.suave((candado.p - 0.42) / 0.10))
                    readonly property int n: root.lineasLog.length
                    readonly property int visibles: Math.floor(Math.min(1, root.apertura / 0.38) * (n + 1))
                    Column {
                        id: colLog
                        width: parent.width
                        spacing: candado.height * 0.004
                        Text {
                            text: "MIARCH  ::  ACCESO CONCEDIDO  ::  CARGANDO SESIÓN"
                            color: root.salvia
                            font { family: root.fuente; pixelSize: candado.height * 0.02; weight: Font.Medium; letterSpacing: 6 }
                            bottomPadding: candado.height * 0.014
                        }
                        Repeater {
                            model: root.lineasLog
                            Text {
                                required property string modelData
                                required property int index
                                width: parent.width; elide: Text.ElideRight
                                visible: index < capaLog.visibles
                                text: modelData
                                // la línea más reciente en el acento; las anteriores se apagan hacia arriba
                                color: index === capaLog.visibles - 1 ? root.terracota : root.arena
                                opacity: index === capaLog.visibles - 1 ? 1 : 0.35 + 0.4 * (index / Math.max(1, capaLog.n))
                                font { family: root.fuente; pixelSize: candado.height * 0.0165; weight: Font.Light }
                            }
                        }
                    }
                }

                Column {
                    x: parent.width * 0.05
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: (1 - candado.entrada) * 60
                    opacity: Math.min(1, candado.entrada) * (1 - Math.min(1, root.apertura * 6))
                    spacing: 6

                    Text {
                        text: Qt.formatDateTime(reloj.date, "HH:mm")
                        color: root.arena
                        font { family: root.fuente; pixelSize: Math.round(candado.height * 0.12); weight: Font.Thin }
                    }
                    Text {
                        text: Qt.locale("es_CO").toString(reloj.date, "dddd d 'de' MMMM").toUpperCase()
                        color: root.terracota
                        font { family: root.fuente; pixelSize: Math.round(candado.height * 0.024); weight: Font.Medium; letterSpacing: 6 }
                        leftPadding: 6
                    }
                    Item { width: 1; height: candado.height * 0.05 }
                    Row {
                        spacing: candado.height * 0.045
                        leftPadding: 4
                        Anillo { etiqueta: "CPU"; valor: root.cpu;     color: root.pizarra;    tam: candado.height * 0.13 }
                        Anillo { etiqueta: "RAM"; valor: root.ram;     color: root.salvia;     tam: candado.height * 0.13 }
                        Anillo { etiqueta: root.cargando ? "CARGA" : "BAT"; valor: root.bateria; color: root.terracota; tam: candado.height * 0.13 }
                    }
                    Item { width: 1; height: candado.height * 0.07 }

                    // Contraseña: puntos que aparecen con rebote
                    Item {
                        id: zonaClave
                        width: candado.width * 0.4; height: candado.height * 0.08
                        property real temblor: 0
                        Connections {
                            target: root
                            function onSacudir() { temblar.restart() }
                        }
                        SequentialAnimation {
                            id: temblar
                            NumberAnimation { target: zonaClave; property: "temblor"; to: 18;  duration: 60 }
                            NumberAnimation { target: zonaClave; property: "temblor"; to: -16; duration: 80 }
                            NumberAnimation { target: zonaClave; property: "temblor"; to: 10;  duration: 70 }
                            NumberAnimation { target: zonaClave; property: "temblor"; to: -6;  duration: 60 }
                            NumberAnimation { target: zonaClave; property: "temblor"; to: 0;   duration: 60 }
                        }
                        Column {
                            x: zonaClave.temblor
                            spacing: 14
                            Text {
                                text: root.verificando ? "VERIFICANDO…" : root.errorClave ? "CONTRASEÑA INCORRECTA" : (root.clave.length ? "" : "ESCRIBE TU CONTRASEÑA")
                                color: root.errorClave ? root.terracota : Qt.alpha(root.arena, 0.55)
                                font { family: root.fuente; pixelSize: candado.height * 0.018; weight: Font.Medium; letterSpacing: 5 }
                                leftPadding: 4
                                height: root.clave.length ? 0 : implicitHeight
                            }
                            Row {
                                spacing: 12
                                leftPadding: 4
                                Repeater {
                                    model: root.clave.length
                                    Rectangle {
                                        width: candado.height * 0.016; height: width; radius: width / 2
                                        color: root.errorClave ? root.terracota : root.arena
                                        scale: 0
                                        Component.onCompleted: scale = 1
                                        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Componente: módulo de la barra (icono + texto, con hover elástico) ──
    component Modulo: Item {
        id: m
        property string icono: ""
        property string texto: ""
        property color acento: "white"
        property bool atenuado: false
        signal clic()
        signal clicDerecho()
        signal rueda(int dir)

        implicitWidth: fila.implicitWidth
        implicitHeight: 30
        opacity: atenuado ? 0.45 : 1
        Behavior on opacity { NumberAnimation { duration: 300 } }
        scale: (zona.containsMouse && root.animBarra === "rebote") ? 1.1 : 1
        Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

        Row {
            id: fila
            anchors.verticalCenter: parent.verticalCenter
            spacing: m.texto.length ? 8 : 0
            Text {
                text: m.icono
                color: m.acento
                font { family: root.fuente; pixelSize: 15 * root.esc }
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 800 } }
            }
            Text {
                text: m.texto
                color: root.arena
                visible: m.texto.length > 0
                font { family: root.fuente; pixelSize: 13 * root.esc; weight: Font.Light }
                anchors.verticalCenter: parent.verticalCenter
                Behavior on color { ColorAnimation { duration: 800 } }
            }
        }
        MouseArea {
            id: zona
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => mouse.button === Qt.LeftButton ? m.clic() : m.clicDerecho()
            onWheel: wheel => m.rueda(wheel.angleDelta.y)
        }
    }

    // ── Componente: interruptor encendido/apagado ──
    component Interruptor: Rectangle {
        id: sw
        property bool encendido: false
        signal alternar()
        width: 46; height: 26; radius: 13
        color: encendido ? root.terracota : Qt.alpha(root.arena, 0.18)
        Behavior on color { ColorAnimation { duration: 250 } }
        Rectangle {
            width: 20; height: 20; radius: 10
            y: 3
            x: sw.encendido ? sw.width - width - 3 : 3
            color: sw.encendido ? root.fondo : root.arena
            Behavior on x { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: sw.alternar() }
    }

    // ── Componentes del panel de Ajustes ──
    component Pagina: Flickable {
        id: pg
        width: parent.width; height: parent.height
        contentWidth: width
        contentHeight: col.implicitHeight + 70
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        default property alias contenidoPagina: col.data
        Column {
            id: col
            x: 36; y: 30
            width: pg.width - 72
            spacing: 18
        }
    }
    component Titulo: Column {
        property string texto: ""
        spacing: 10
        width: parent ? parent.width : implicitWidth
        Text {
            text: parent.texto
            color: root.arena
            font { family: root.fuente; pixelSize: 32 * root.esc; weight: Font.Thin; letterSpacing: 4 }
        }
        Rectangle { width: 70; height: 2; radius: 1; color: root.terracota }
    }
    component Etiqueta: Text {
        property string texto: ""
        text: texto
        topPadding: 8
        color: Qt.alpha(root.arena, 0.5)
        font { family: root.fuente; pixelSize: 12 * root.esc; weight: Font.Medium; letterSpacing: 5 }
    }
    component Fila: Item {
        id: fl
        property string etiqueta: ""
        property string detalle: ""
        default property alias controles: ctrl.data
        width: parent ? parent.width : implicitWidth
        height: Math.max(54, tx.implicitHeight + 20)
        Rectangle { anchors.fill: parent; radius: 14; color: Qt.alpha(root.arena, 0.05) }
        Column {
            id: tx
            x: 18; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - ctrl.width - 54
            spacing: 2
            Text {
                width: parent.width; elide: Text.ElideRight
                text: fl.etiqueta
                color: root.arena
                font { family: root.fuente; pixelSize: 14 * root.esc; weight: Font.Medium }
            }
            Text {
                visible: fl.detalle.length > 0
                width: parent.width; elide: Text.ElideRight
                text: fl.detalle
                color: Qt.alpha(root.arena, 0.5)
                font { family: root.fuente; pixelSize: 12 * root.esc; weight: Font.Light }
            }
        }
        Row {
            id: ctrl
            anchors.right: parent.right; anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
        }
    }
    component Tarjeta: Item {
        id: tj
        property string titulo: ""
        property string detalle: ""
        property string boton: ""
        signal clic()
        width: parent ? parent.width : implicitWidth
        height: 78
        Rectangle { anchors.fill: parent; radius: 16; color: Qt.alpha(root.arena, 0.05) }
        Column {
            x: 20; anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            Text { text: tj.titulo; color: Qt.alpha(root.arena, 0.5); font { family: root.fuente; pixelSize: 11 * root.esc; weight: Font.Medium; letterSpacing: 4 } }
            Text { text: tj.detalle; color: root.arena; font { family: root.fuente; pixelSize: 16 * root.esc; weight: Font.Light } }
        }
        Opcion { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; texto: tj.boton; onClic: tj.clic() }
    }
    component Deslizador: Item {
        id: dz
        property real valor: 0
        property real v: valor
        signal movido(real v)
        implicitWidth: 240; implicitHeight: 28
        onValorChanged: if (!zona.pressed) v = valor
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 6; radius: 3
            color: Qt.alpha(root.arena, 0.18)
            Rectangle { width: parent.width * dz.v; height: parent.height; radius: 3; color: root.terracota }
        }
        Rectangle {
            x: (dz.width - width) * dz.v
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18; radius: 9
            color: root.arena
        }
        MouseArea {
            id: zona
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            function poner(x) { dz.v = Math.max(0, Math.min(1, x / width)); dz.movido(dz.v) }
            onPressed: mouse => poner(mouse.x)
            onPositionChanged: mouse => { if (pressed) poner(mouse.x) }
        }
    }
    // Botón que pide una segunda pulsación para confirmar (para acciones que no se deshacen)
    component Confirmar: Opcion {
        id: cf
        property string base: ""
        property bool armado: false
        signal confirmado()
        Component.onCompleted: base = texto
        activo: armado
        texto: armado ? "¿Seguro?" : base
        Timer { id: reinicio; interval: 4000; onTriggered: cf.armado = false }
        onClic: { if (armado) { armado = false; confirmado() } else { armado = true; reinicio.restart() } }
    }

    // ── Componente: botón de opción (cápsula) ──
    component Opcion: Rectangle {
        id: o
        property string texto: ""
        property bool activo: false
        signal clic()
        implicitHeight: 38
        implicitWidth: t.implicitWidth + 36
        radius: 19
        color: activo ? root.terracota : (zona.containsMouse ? Qt.alpha(root.arena, 0.14) : "transparent")
        border.width: activo ? 0 : 1
        border.color: Qt.alpha(root.arena, 0.28)
        Behavior on color { ColorAnimation { duration: 200 } }
        Text {
            id: t
            anchors.centerIn: parent
            text: o.texto
            color: o.activo ? root.fondo : root.arena
            font { family: root.fuente; pixelSize: 14 * root.esc; weight: o.activo ? Font.Medium : Font.Light }
        }
        MouseArea { id: zona; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: o.clic() }
    }

    // ── Componente: sección con varias opciones ──
    component Seccion: Column {
        id: sec
        property string titulo: ""
        property string clave: ""
        property string actual: ""
        property var opciones: []
        spacing: 12
        width: parent ? parent.width : implicitWidth
        Text {
            text: sec.titulo
            color: Qt.alpha(root.arena, 0.5)
            font { family: root.fuente; pixelSize: 12 * root.esc; weight: Font.Medium; letterSpacing: 5 }
        }
        Flow {
            spacing: 10
            width: sec.width
            Repeater {
                model: sec.opciones
                Opcion {
                    required property var modelData
                    texto: modelData.t
                    activo: sec.actual === modelData.v
                    onClic: root.aplicar(sec.clave, modelData.v)
                }
            }
        }
    }

    // ── Componente: anillo con valor animado ──
    component Anillo: Item {
        id: a
        property string etiqueta: ""
        property real valor: 0
        property color color: "white"
        property real tam: 120
        property real animado: 0
        width: tam; height: tam

        Behavior on animado { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }
        onValorChanged: animado = valor

        // Dibujado por la GPU: no se repinta por software en cada cuadro como el Canvas anterior
        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: root.pista; strokeWidth: 5; fillColor: "transparent"
                PathAngleArc { centerX: a.tam / 2; centerY: a.tam / 2; radiusX: a.tam / 2 - 7; radiusY: a.tam / 2 - 7; startAngle: 0; sweepAngle: 360 }
            }
            ShapePath {
                strokeColor: a.color; strokeWidth: 5; fillColor: "transparent"; capStyle: ShapePath.RoundCap
                PathAngleArc { centerX: a.tam / 2; centerY: a.tam / 2; radiusX: a.tam / 2 - 7; radiusY: a.tam / 2 - 7
                               startAngle: -90; sweepAngle: 360 * Math.max(0.015, a.animado) }
            }
        }
        Column {
            anchors.centerIn: parent
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(a.animado * 100)
                color: root.arena
                font { family: root.fuente; pixelSize: a.tam * 0.27; weight: Font.Light }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: a.etiqueta
                color: a.color
                font { family: root.fuente; pixelSize: a.tam * 0.09; weight: Font.Medium; letterSpacing: 3 }
            }
        }
    }
}
