// Miarch · escritorio propio con Quickshell
// v1: sin barra. Reloj grande + anillos de datos sobre el wallpaper. Colores mate.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
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
                Behavior on entrada { NumberAnimation { duration: 1400; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

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

    Process {
        id: pActualiz
        command: ["sh", "-c", "if command -v checkupdates >/dev/null; then checkupdates 2>/dev/null | wc -l; else pacman -Qu 2>/dev/null | wc -l; fi"]
        stdout: StdioCollector { onStreamFinished: root.actualizaciones = parseInt(text.trim()) || 0 }
    }
    Timer { interval: 1200000; running: true; repeat: true; triggeredOnStart: true; onTriggered: pActualiz.running = true }

    // Cambios nuevos de Miarch en GitHub: se revisan una vez al encender el sistema (y se reintenta si aún no hay internet).
    // El clic en la nube abre miarch-update, que los baja y los aplica.
    property int cambiosRepo: 0
    property int _intentosRepo: 0
    readonly property int pendientes: root.actualizaciones + root.cambiosRepo
    Process {
        id: pRepo
        command: ["sh", "-c", "d=\"${MIARCH_DIR:-$HOME/Miarch}\"; [ -d \"$d/.git\" ] || { echo 0; exit; }; " +
                  "git -C \"$d\" fetch -q origin 2>/dev/null || { echo x; exit; }; " +
                  "u=$(git -C \"$d\" rev-parse -q --verify '@{u}' 2>/dev/null || echo \"origin/$(git -C \"$d\" rev-parse --abbrev-ref HEAD)\"); " +
                  "git -C \"$d\" rev-list --count \"HEAD..$u\" 2>/dev/null || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                if (t === "x") { if (root._intentosRepo < 5) tReintentoRepo.restart(); return }   // sin internet todavía
                const n = parseInt(t) || 0
                if (n > 0 && root.cambiosRepo === 0)
                    Quickshell.execDetached(["sh", "-c", "command -v notify-send >/dev/null && notify-send -a Miarch 'Miarch tiene una actualización' 'Haz clic en la nube de la barra para aplicarla.'"])
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
        stdout: StdioCollector {
            onStreamFinished: {
                root.wifiOcupado = false
                try {
                    const d = JSON.parse(text)
                    if (pAccion.accion === "connect") {
                        root.wifiMensaje = d.ok ? "" : (d.msg || "No se pudo conectar")
                        if (d.ok) root.redClave = ""
                    }
                } catch (e) { root.wifiMensaje = "No se pudo conectar" }
                pLista.running = true
            }
        }
    }
    function wifiAccion(accion, arg, clave) {
        if (pAccion.running) return
        pAccion.accion = accion
        pAccion.environment = { "MIARCH_PASS": clave || "" }
        pAccion.command = arg !== "" ? [root.wifiBin, accion, arg] : [root.wifiBin, accion]
        if (accion === "connect") { root.wifiOcupado = true; root.wifiMensaje = "" }
        pAccion.running = true
    }
    function conectarRed(r, clave) {
        if (r.seguridad !== "open" && !r.conocida && !clave) { root.wifiClave = ""; root.redClave = r.nombre; root.wifiMensaje = ""; return }
        root.wifiAccion("connect", r.nombre, clave)
    }
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
        const visibles = todos.filter(d => d.connected || d.paired || root.btNombre(d) !== "" || root.btMostrarSinNombre)
        visibles.sort((x, y) =>
            (y.connected - x.connected) || (y.paired - x.paired) ||
            String(root.btNombre(x) || "~" + x.address).localeCompare(String(root.btNombre(y) || "~" + y.address)))
        // solo se reemplaza la lista si de verdad cambió algo (así las filas no parpadean cada segundo)
        const clave = visibles.map(d => d.address + "|" + root.btNombre(d) + "|" + d.connected + "|" + d.paired).join(";")
        if (clave !== root._btClave) { root._btClave = clave; root.btLista = visibles }
    }
    Timer {
        interval: 1000; repeat: true; triggeredOnStart: true
        running: root.conexionesAbierto && root.conexionesModo === "bt"
        onTriggered: root.ordenarBt()
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
                    width: 400
                    height: Math.min(cuerpo.implicitHeight + 44, parent.height - 80)
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
                                            width: filas.width
                                            spacing: 4
                                            Item {
                                                width: parent.width; height: 46
                                                Rectangle {
                                                    anchors.fill: parent; radius: 12
                                                    color: filaZona.containsMouse ? Qt.alpha(root.arena, 0.08) : "transparent"
                                                    Behavior on color { ColorAnimation { duration: 150 } }
                                                }
                                                Text {
                                                    x: 12; anchors.verticalCenter: parent.verticalCenter
                                                    text: ""
                                                    color: modelData.conectada ? root.terracota : root.arena
                                                    opacity: 0.3 + 0.175 * modelData.senal
                                                    font { family: root.fuente; pixelSize: 16 * root.esc }
                                                }
                                                Text {
                                                    x: 44; anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 110
                                                    elide: Text.ElideRight
                                                    text: modelData.nombre
                                                    color: root.arena
                                                    font { family: root.fuente; pixelSize: 15 * root.esc; weight: modelData.conectada ? Font.Medium : Font.Light }
                                                }
                                                Text {
                                                    anchors.right: parent.right; anchors.rightMargin: 14
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: modelData.conectada ? "" : (modelData.seguridad !== "open" && !modelData.conocida ? "" : "")
                                                    color: modelData.conectada ? root.terracota : Qt.alpha(root.arena, 0.5)
                                                    font { family: root.fuente; pixelSize: 13 * root.esc }
                                                }
                                                Text {
                                                    visible: root.wifiOcupado && root.redClave === "" && false
                                                    text: ""
                                                }
                                                MouseArea {
                                                    id: filaZona
                                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: { if (modelData.conectada) root.wifiAccion("disconnect", "", ""); else root.conectarRed(modelData, "") }
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

    // ═════════════════ MENÚ DE ENERGÍA (Super + Shift + Esc) ═════════════════
    property bool energiaAbierto: false
    property int energiaSel: 0
    property int energiaConfirmar: -1
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
    onEnergiaAbiertoChanged: { root.energiaSel = 0; root.energiaConfirmar = -1 }
    IpcHandler {
        target: "power"
        function toggle(): void { root.energiaAbierto = !root.energiaAbierto }
        function open(): void { root.energiaAbierto = true }
        function close(): void { root.energiaAbierto = false }
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
                Behavior on entrada { NumberAnimation { duration: 600; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) { if (root.energiaConfirmar >= 0) root.energiaConfirmar = -1; else root.energiaAbierto = false }
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
                    width: Math.min(parent.width * 0.4, 520)
                    spacing: 6

                    Text {
                        text: "ENERGÍA"
                        color: Qt.alpha(root.arena, 0.3)
                        font { family: root.fuente; pixelSize: 40 * root.esc; weight: Font.Thin; letterSpacing: 12 }
                        bottomPadding: 22
                    }
                    Repeater {
                        model: root.energiaOpciones
                        Item {
                            required property var modelData
                            required property int index
                            readonly property bool sel: root.energiaSel === index
                            readonly property bool pideConfirmar: root.energiaConfirmar === index
                            width: parent.width; height: 64
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
                    Text {
                        text: "↑ ↓ elegir    ENTER aceptar    ESC cerrar"
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
                Behavior on entrada { NumberAnimation { duration: 700; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }

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
                        Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.OutBack; easing.overshoot: 1.4 } }
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
                            Behavior on y { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
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
                                Behavior on x { NumberAnimation { duration: 380; easing.type: Easing.OutBack; easing.overshoot: 2 } }

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
                sesion.locked = false
            } else {
                root.errorClave = true
                root.sacudir()
            }
        }
        onError: err => { root.verificando = false; root.clave = ""; root.errorClave = true; root.sacudir() }
    }

    function intentar() {
        if (root.clave.length === 0 || root.verificando) return
        root.verificando = true
        if (!pam.start()) { root.verificando = false; root.errorClave = true; root.sacudir() }
    }

    IpcHandler {
        target: "lock"
        function lock(): void { root.clave = ""; root.errorClave = false; sesion.locked = true }
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
                Behavior on entrada { NumberAnimation { duration: 1200; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }

                Keys.onPressed: event => {
                    if (root.verificando) return
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
                    autoPaddingEnabled: false
                }
                Rectangle { anchors.fill: parent; color: root.fondo; opacity: 0.58 }

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

                Column {
                    x: parent.width * 0.05
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: (1 - candado.entrada) * 60
                    opacity: Math.min(1, candado.entrada)
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
