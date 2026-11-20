// Miarch · pantalla de inicio de sesión (greetd + Quickshell)
// Mismo estilo que el bloqueo: wallpaper desenfocado, reloj grande, contraseña con puntos.
// Modo de prueba (no toca el sistema):  MIARCH_GREETER_TEST=1 MIARCH_GREETER_DATA=<carpeta> qs -p <esta carpeta>
//   en el modo de prueba la clave "prueba" simula un acceso correcto; Esc cierra.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd
import QtQuick
import QtQuick.Effects

ShellRoot {
    id: root

    readonly property bool prueba: Quickshell.env("MIARCH_GREETER_TEST") === "1"
    readonly property string datos: Quickshell.env("MIARCH_GREETER_DATA") || "/var/lib/miarch-greeter"
    readonly property string fuente: "JetBrainsMono Nerd Font"

    // ── Paleta: la misma del escritorio (copiada a /var/lib/miarch-greeter por wallpaper.sh) ──
    property color arena: "#cfc6b4"
    property color terracota: "#b97b62"
    property color fondo: "#12141a"
    Behavior on arena { ColorAnimation { duration: 800 } }
    Behavior on terracota { ColorAnimation { duration: 800 } }
    Behavior on fondo { ColorAnimation { duration: 800 } }
    FileView {
        path: root.datos + "/colors.json"
        onLoaded: {
            try {
                const c = JSON.parse(text())
                root.arena = c.arena; root.terracota = c.terracota; root.fondo = c.fondo
            } catch (e) {}
        }
    }

    SystemClock { id: reloj; precision: SystemClock.Seconds }

    // ── Usuarios ──
    property var usuarios: []
    property int usuarioIdx: 0
    readonly property string usuario: usuarios.length > 0 ? usuarios[usuarioIdx] : ""
    Process {
        running: true
        command: ["sh", "-c", "awk -F: '$3>=1000 && $3<60000 && $7 !~ /(nologin|false)$/ {print $1}' /etc/passwd"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.usuarios = text.trim().split("\n").filter(x => x.length > 0)
                root.iniciarSesion()
            }
        }
    }

    // ── Estado del acceso ──
    property string clave: ""
    property bool verificando: false
    property bool hayError: false
    property string mensaje: ""
    property bool listoParaClave: root.prueba     // en real, true cuando greetd pide la contraseña
    signal sacudir()
    property bool accesoOk: false                    // contraseña correcta: el fondo se acerca y se enfoca, y luego arranca la sesión
    property real apertura: 0
    property bool lanzar: false                      // greetd ya está listo para lanzar la sesión

    function iniciarSesion() {
        root.clave = ""; root.hayError = false; root.verificando = false
        if (root.prueba || root.usuario === "") return
        root.listoParaClave = false
        Greetd.createSession(root.usuario)
    }
    function cambiarUsuario(delta) {
        if (root.usuarios.length < 2 || root.verificando) return
        if (!root.prueba) Greetd.cancelSession()
        root.usuarioIdx = (root.usuarioIdx + delta + root.usuarios.length) % root.usuarios.length
        root.iniciarSesion()
    }
    function fallar(texto) {
        root.verificando = false; root.clave = ""; root.hayError = true
        root.mensaje = texto
        root.sacudir()
        reintento.restart()
    }
    function enviar() {
        if (root.verificando || root.clave.length === 0 || !root.listoParaClave) return
        const c = root.clave
        root.clave = ""                       // la contraseña no se queda guardada en memoria del panel
        root.hayError = false; root.mensaje = ""
        if (root.prueba) {
            root.verificando = true
            if (c === "prueba") { root.mensaje = "Acceso concedido (modo de prueba)"; root.entrar() }
            else root.fallar("CONTRASEÑA INCORRECTA")
            return
        }
        root.verificando = true
        Greetd.respond(c)
    }

    // Entrada: al acertar, el fondo se acerca y se enfoca (llega a escala 1, igual que el escritorio) y entonces arranca la sesión
    function entrar() {
        if (root.accesoOk) return
        root.accesoOk = true; root.apertura = 0
        animApertura.restart()
    }
    NumberAnimation {
        id: animApertura
        target: root; property: "apertura"; from: 0; to: 1; duration: 1900; easing.type: Easing.InOutSine
        onFinished: {
            if (root.prueba) { Qt.quit(); return }
            // shell de login: así se carga tu entorno (~/.zprofile, PATH) como en un inicio normal
            Greetd.launch(["zsh", "-lc", "exec start-hyprland"], [], true)
        }
    }
    Timer { id: reintento; interval: 1300; onTriggered: { if (!root.prueba) Greetd.cancelSession(); root.iniciarSesion() } }
    Timer { id: cierre; interval: 1400; onTriggered: Qt.quit() }
    Timer { running: root.prueba; interval: 14000; onTriggered: Qt.quit() }   // seguro: el modo de prueba se cierra solo

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) { root.listoParaClave = true; root.verificando = false }
            else { root.mensaje = message; Greetd.respond("") }
        }
        function onAuthFailure(message) { root.fallar("CONTRASEÑA INCORRECTA") }
        function onReadyToLaunch() { root.entrar() }
        function onError(error, message) { root.fallar(message || "ERROR DE INICIO DE SESIÓN") }
    }

    // ── Una ventana por monitor ──
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            color: root.fondo
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "miarch-greeter"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Item {
                id: pantalla
                anchors.fill: parent
                focus: true
                Component.onCompleted: { forceActiveFocus(); entrada = 1 }
                property real entrada: 0
                Behavior on entrada { NumberAnimation { duration: 1500; easing.type: Easing.OutQuint } }
                readonly property real abre: { const x = root.apertura; return x * x * (3 - 2 * x) }   // suavizada

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Escape) { if (root.prueba) Qt.quit(); else root.clave = ""; return }
                    if (event.key === Qt.Key_Tab) { root.cambiarUsuario(1); return }
                    if (root.verificando || root.accesoOk) return
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.enviar(); return }
                    if (event.key === Qt.Key_Backspace) root.clave = root.clave.slice(0, -1)
                    else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32) root.clave += event.text
                    else return
                    root.hayError = false
                }

                // Fondo: wallpaper desenfocado + velo del color de fondo
                Image {
                    id: img
                    anchors.fill: parent
                    source: "file://" + root.datos + "/wallpaper"
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    asynchronous: true
                }
                MultiEffect {
                    anchors.fill: parent
                    source: img
                    visible: img.status === Image.Ready
                    blurEnabled: true; blurMax: 64; blur: 1.0
                    autoPaddingEnabled: false
                    opacity: 1 - pantalla.abre; scale: 1 + pantalla.abre * 0.10
                }
                Rectangle { anchors.fill: parent; color: root.fondo; opacity: (img.status === Image.Ready ? 0.58 : 0) * (1 - pantalla.abre) }
                Image {   // el fondo nítido llega desde más cerca y se asienta en escala 1
                    anchors.fill: parent
                    source: img.source
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: pantalla.abre > 0
                    opacity: pantalla.abre
                    scale: 1.18 - 0.18 * (1 - Math.pow(1 - pantalla.abre, 3))
                }

                Column {
                    x: parent.width * 0.05
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: (1 - pantalla.entrada) * 40
                    opacity: pantalla.entrada * (1 - Math.min(1, root.apertura * 4))
                    spacing: 6

                    Text {
                        text: Qt.formatDateTime(reloj.date, "HH:mm")
                        color: root.arena
                        font { family: root.fuente; pixelSize: Math.round(pantalla.height * 0.12); weight: Font.Thin }
                    }
                    Text {
                        text: Qt.locale("es_CO").toString(reloj.date, "dddd d 'de' MMMM").toUpperCase()
                        color: root.terracota
                        font { family: root.fuente; pixelSize: Math.round(pantalla.height * 0.024); weight: Font.Medium; letterSpacing: 6 }
                        leftPadding: 6
                    }
                    Item { width: 1; height: pantalla.height * 0.07 }

                    // Usuario
                    Row {
                        spacing: 16
                        leftPadding: 6
                        Rectangle {
                            width: pantalla.height * 0.05; height: width; radius: width / 2
                            color: root.terracota
                            Text {
                                anchors.centerIn: parent
                                text: root.usuario.length ? root.usuario.charAt(0).toUpperCase() : ""
                                color: root.fondo
                                font { family: root.fuente; pixelSize: parent.width * 0.5; weight: Font.Medium }
                            }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                text: root.usuario
                                color: root.arena
                                font { family: root.fuente; pixelSize: pantalla.height * 0.026; weight: Font.Light }
                            }
                            Text {
                                visible: root.usuarios.length > 1
                                text: "TAB PARA CAMBIAR DE USUARIO"
                                color: Qt.alpha(root.arena, 0.4)
                                font { family: root.fuente; pixelSize: pantalla.height * 0.012; letterSpacing: 3 }
                            }
                        }
                    }
                    Item { width: 1; height: pantalla.height * 0.03 }

                    // Contraseña (puntos con rebote)
                    Item {
                        id: zonaClave
                        width: pantalla.width * 0.4; height: pantalla.height * 0.09
                        property real temblor: 0
                        Connections { target: root; function onSacudir() { temblar.restart() } }
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
                                text: root.accesoOk ? "ACCESO CONCEDIDO" : root.verificando ? "VERIFICANDO…"
                                    : root.mensaje !== "" ? root.mensaje
                                    : (!root.listoParaClave ? "ESPERANDO…" : (root.clave.length ? "" : "ESCRIBE TU CONTRASEÑA"))
                                color: root.hayError ? root.terracota : Qt.alpha(root.arena, 0.55)
                                font { family: root.fuente; pixelSize: pantalla.height * 0.018; weight: Font.Medium; letterSpacing: 5 }
                                leftPadding: 6
                                height: (root.clave.length && root.mensaje === "" && !root.verificando) ? 0 : implicitHeight
                            }
                            Row {
                                spacing: 12
                                leftPadding: 6
                                Repeater {
                                    model: root.clave.length
                                    Rectangle {
                                        width: pantalla.height * 0.016; height: width; radius: width / 2
                                        color: root.hayError ? root.terracota : root.arena
                                        scale: 0
                                        Component.onCompleted: scale = 1
                                        Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 2.5 } }
                                    }
                                }
                            }
                        }
                    }
                }

                // Reiniciar / Apagar (piden una segunda pulsación)
                Row {
                    x: parent.width * 0.05; y: parent.height - height - parent.height * 0.05
                    spacing: 28
                    opacity: pantalla.entrada * (1 - Math.min(1, root.apertura * 4))
                    Repeater {
                        model: [ { t: "REINICIAR", c: "reboot" }, { t: "APAGAR", c: "poweroff" } ]
                        Text {
                            required property var modelData
                            property bool armado: false
                            text: armado ? "¿SEGURO?" : modelData.t
                            color: armado ? root.terracota : Qt.alpha(root.arena, 0.45)
                            font { family: root.fuente; pixelSize: pantalla.height * 0.014; weight: Font.Medium; letterSpacing: 4 }
                            Timer { id: rearmar; interval: 4000; onTriggered: parent.armado = false }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (parent.armado) { if (!root.prueba) Quickshell.execDetached(["systemctl", parent.modelData.c]); parent.armado = false }
                                    else { parent.armado = true; rearmar.restart() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
