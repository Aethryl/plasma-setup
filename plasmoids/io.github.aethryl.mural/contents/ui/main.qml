import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    readonly property string mural: "w=\"$HOME/.local/bin/mural\"; [ -x \"$w\" ] || w=mural; \"$w\""
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal || Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool windowed: Plasmoid.formFactor === PlasmaCore.Types.Planar || Plasmoid.location === PlasmaCore.Types.Floating
    property var wall: null
    property var library: null
    property string libraryText: ""
    property bool failed: false
    property bool started: false
    property real compactWidth: Kirigami.Units.gridUnit * 6
    property Item compactItem: null
    property bool drooped: false
    property bool deleteArmed: false
    property var pending: ({})
    property int serial: 0

    readonly property real ear: Kirigami.Units.gridUnit * 0.7
    readonly property real bottomRadius: Kirigami.Units.gridUnit * 1.1

    readonly property var current: wall ? wall.current : null
    readonly property var upNext: wall ? wall.next : null
    readonly property bool rotating: !!wall && wall.enabled
    readonly property var intervals: [
        { minutes: 10, label: "10m" },
        { minutes: 30, label: "30m" },
        { minutes: 60, label: "1h" },
        { minutes: 180, label: "3h" },
    ]

    readonly property color dim: Kirigami.Theme.disabledTextColor
    readonly property color hairline: Qt.alpha(Kirigami.Theme.textColor, 0.1)

    preferredRepresentation: windowed ? fullRepresentation : compactRepresentation
    fullRepresentation: Manager {
        app: root
    }
    Plasmoid.backgroundHints: windowed ? PlasmaCore.Types.DefaultBackground : PlasmaCore.Types.NoBackground

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Open wallpaper manager"
            icon.name: "preferences-desktop-wallpaper"
            onTriggered: root.openManager()
        }
    ]

    toolTipMainText: ""
    toolTipSubText: ""

    function quote(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'"
    }

    function command(args) {
        return root.mural + " " + args
    }

    function exec(args, done) {
        root.serial += 1
        const source = command(args) + " #" + root.serial
        if (done)
            root.pending[source] = done
        executable.connectSource(source)
    }

    function refresh() {
        exec("status", result => {
            if (!result.status) {
                root.wall = null
                root.failed = true
            }
        })
        if (root.windowed)
            exec("list")
    }

    function run(args) {
        exec(args, result => {
            if (!result.status)
                root.refresh()
            else if (root.windowed)
                exec("list")
        })
    }

    function mutate(args, done) {
        exec(args, result => {
            root.refresh()
            if (done)
                done(result)
        })
    }

    function advance(args) {
        if (rotation.running)
            rotation.restart()
        run(args)
    }

    function openManager() {
        root.drooped = false
        executable.connectSource("setsid -f plasmawindowed io.github.aethryl.mural >/dev/null 2>&1")
    }

    function applyStatus(parsed) {
        root.wall = parsed
        root.failed = false
        if (!root.started) {
            root.started = true
            if (root.inPanel && parsed.enabled && !parsed.current && parsed.total > 0)
                root.advance("next")
        }
    }

    function imageUrl(path) {
        return path ? "file://" + path : ""
    }

    function pageUrl(item) {
        return item ? item.page || item.source || "" : ""
    }

    function host(url) {
        const match = /^[a-z]+:\/\/(?:www\.)?([^/]+)/i.exec(url || "")
        return match ? match[1] : ""
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            const done = root.pending[source]
            delete root.pending[source]
            const stdout = (data["stdout"] || "").trim()
            const lines = stdout.split("\n")
            let parsed = null
            try {
                parsed = JSON.parse(lines[lines.length - 1])
            } catch (e) {}
            if (parsed && typeof parsed === "object" && Array.isArray(parsed.images)) {
                if (stdout !== root.libraryText) {
                    root.libraryText = stdout
                    root.library = parsed
                }
                parsed = null
            } else if (parsed && typeof parsed === "object" && Array.isArray(parsed.collections) && "enabled" in parsed) {
                root.applyStatus(parsed)
            } else {
                parsed = null
            }
            if (done) {
                const errors = (data["stderr"] || "").trim().split("\n").filter(line => line.trim() !== "")
                done({
                    ok: data["exit code"] === 0,
                    status: parsed,
                    error: errors.length ? errors[errors.length - 1] : (data["exit code"] === 0 ? "" : "mural failed")
                })
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: rotation
        interval: Math.max(1, root.wall ? root.wall.interval : 30) * 60000
        running: root.inPanel && root.rotating
        repeat: true
        onTriggered: root.run("next")
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.deleteArmed = false
    }

    onDeleteArmedChanged: if (deleteArmed) disarm.restart()

    component Chip: Rectangle {
        id: chip
        property string text
        property bool active: false
        signal clicked()
        implicitWidth: chipLabel.implicitWidth + Kirigami.Units.largeSpacing * 2
        implicitHeight: chipLabel.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: height / 2
        color: active ? Kirigami.Theme.highlightColor
            : chipHover.containsMouse ? Qt.alpha(Kirigami.Theme.highlightColor, 0.25)
            : Qt.alpha(Kirigami.Theme.textColor, 0.08)
        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

        PlasmaComponents.Label {
            id: chipLabel
            anchors.centerIn: parent
            text: chip.text
            color: chip.active ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
            font.features: { "tnum": 1 }
        }
        MouseArea {
            id: chipHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    component Action: Rectangle {
        id: action
        property string text
        property string icon
        property color tone: Kirigami.Theme.textColor
        property bool alert: false
        signal clicked()
        Layout.fillWidth: true
        implicitWidth: actionRow.implicitWidth + Kirigami.Units.largeSpacing * 2
        implicitHeight: Math.max(actionRow.implicitHeight, Kirigami.Units.gridUnit) + Kirigami.Units.smallSpacing * 3
        radius: Kirigami.Units.cornerRadius
        opacity: enabled ? 1 : 0.4
        color: alert ? Kirigami.Theme.negativeTextColor
            : actionHover.containsMouse ? Qt.alpha(tone, 0.2)
            : Qt.alpha(Kirigami.Theme.textColor, 0.08)
        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

        RowLayout {
            id: actionRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: action.icon
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: action.alert ? Kirigami.Theme.highlightedTextColor : action.tone
                isMask: true
            }
            PlasmaComponents.Label {
                text: action.text
                color: action.alert ? Kirigami.Theme.highlightedTextColor : action.tone
            }
        }
        MouseArea {
            id: actionHover
            anchors.fill: parent
            hoverEnabled: true
            enabled: action.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }
    }

    readonly property string hideIcon: Qt.resolvedUrl("../images/eye-off.svg").toString()

    component IconAction: Rectangle {
        id: iconAction
        property string icon
        property string label
        property string hint
        property color tone: Kirigami.Theme.textColor
        property bool alert: false
        signal clicked()
        implicitWidth: iconActionRow.implicitWidth + Kirigami.Units.smallSpacing * 3
        implicitHeight: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing * 3
        radius: Kirigami.Units.cornerRadius
        color: alert ? tone : Qt.alpha(tone, iconActionHover.containsMouse ? 0.3 : 0.15)
        Behavior on color { ColorAnimation { duration: Kirigami.Units.shortDuration } }

        RowLayout {
            id: iconActionRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: iconAction.icon
                implicitWidth: Kirigami.Units.iconSizes.small
                implicitHeight: Kirigami.Units.iconSizes.small
                color: iconAction.alert ? Kirigami.Theme.highlightedTextColor : iconAction.tone
                isMask: true
            }
            PlasmaComponents.Label {
                visible: text !== ""
                text: iconAction.label
                color: Kirigami.Theme.highlightedTextColor
            }
        }
        MouseArea {
            id: iconActionHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconAction.clicked()
        }
        PlasmaComponents.ToolTip {
            text: iconAction.hint
            visible: iconActionHover.containsMouse && text !== ""
            delay: Kirigami.Units.toolTipDelay
        }
    }

    component Caption: PlasmaComponents.Label {
        color: root.dim
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1
    }

    compactRepresentation: MouseArea {
        Layout.minimumWidth: row.implicitWidth
        Layout.preferredWidth: row.implicitWidth
        onWidthChanged: root.compactWidth = width
        Component.onCompleted: root.compactItem = this
        onClicked: root.drooped = !root.drooped

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing * 1.5
            opacity: root.rotating ? 1 : 0.6

            Item {
                implicitWidth: Math.round(implicitHeight * 16 / 9)
                implicitHeight: Kirigami.Units.iconSizes.small
                Layout.alignment: Qt.AlignVCenter

                Kirigami.ShadowedImage {
                    id: thumb
                    anchors.fill: parent
                    visible: !!root.upNext && status === Image.Ready
                    source: root.upNext ? root.imageUrl(root.upNext.path) : ""
                    sourceSize.width: Kirigami.Units.iconSizes.small * 4
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    radius: Kirigami.Units.cornerRadius / 2
                    color: "transparent"
                }
                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: Kirigami.Units.iconSizes.small
                    height: width
                    visible: !thumb.visible
                    source: "preferences-desktop-wallpaper"
                    color: root.failed ? root.dim : Kirigami.Theme.textColor
                }
            }
        }
    }

    onDroopedChanged: {
        if (drooped) {
            droop.visible = true
            droop.requestActivate()
            reveal.to = 1
            reveal.easing.type = Easing.OutBack
            reveal.duration = Kirigami.Units.longDuration * 1.6
        } else {
            reveal.to = 0
            reveal.easing.type = Easing.InCubic
            reveal.duration = Kirigami.Units.longDuration * 0.8
            root.deleteArmed = false
        }
        reveal.restart()
    }

    NumberAnimation {
        id: reveal
        target: notch
        property: "progress"
        onFinished: if (!root.drooped) droop.visible = false
    }

    PlasmaCore.Dialog {
        id: droop
        visualParent: root.compactItem
        location: PlasmaCore.Types.TopEdge
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.WindowStaysOnTopHint
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: true
        onVisibleChanged: if (!visible) { root.drooped = false; notch.progress = 0 }
        onXChanged: if (root.compactItem) notch.inset = Math.max(0, root.compactItem.mapToGlobal(0, 0).x + root.compactItem.width / 2 - x - notch.bodyWidth / 2 - root.ear)

        mainItem: Item {
            id: notch
            property real progress: 0
            property real inset: 0
            focus: true
            Keys.onEscapePressed: root.drooped = false
            Kirigami.Theme.colorSet: Kirigami.Theme.Window
            Kirigami.Theme.inherit: false
            readonly property real bodyWidth: Math.max(root.compactWidth, Kirigami.Units.gridUnit * 20) + Kirigami.Units.gridUnit
            readonly property real fullHeight: content.implicitHeight + Kirigami.Units.gridUnit * 1.6
            readonly property real shownHeight: Math.max(0, fullHeight * progress)
            width: inset + bodyWidth + root.ear * 2
            height: fullHeight * 1.1

            Shape {
                x: notch.inset
                width: parent.width - notch.inset
                height: parent.height
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    id: sp
                    readonly property real e: root.ear
                    readonly property real w: notch.bodyWidth
                    readonly property real h: Math.max(notch.shownHeight, e + 1)
                    readonly property real r: Math.min(root.bottomRadius, h - e)
                    strokeWidth: -1
                    fillColor: Qt.tint(Kirigami.Theme.backgroundColor, Qt.alpha(Kirigami.Theme.textColor, 0.08))
                    startX: 0; startY: 0
                    PathQuad { controlX: sp.e; controlY: 0; x: sp.e; y: sp.e }
                    PathLine { x: sp.e; y: sp.h - sp.r }
                    PathQuad { controlX: sp.e; controlY: sp.h; x: sp.e + sp.r; y: sp.h }
                    PathLine { x: sp.e + sp.w - sp.r; y: sp.h }
                    PathQuad { controlX: sp.e + sp.w; controlY: sp.h; x: sp.e + sp.w; y: sp.h - sp.r }
                    PathLine { x: sp.e + sp.w; y: sp.e }
                    PathQuad { controlX: sp.e + sp.w; controlY: 0; x: sp.e * 2 + sp.w; y: 0 }
                    PathLine { x: 0; y: 0 }
                }
            }

            Item {
                x: notch.inset + root.ear
                width: notch.bodyWidth
                height: notch.shownHeight
                clip: true

                ColumnLayout {
                    id: content
                    x: Kirigami.Units.gridUnit * 0.8
                    y: Kirigami.Units.gridUnit * 0.6
                    width: parent.width - Kirigami.Units.gridUnit * 1.6
                    spacing: Kirigami.Units.largeSpacing
                    opacity: Math.min(1, Math.max(0, notch.progress * 1.6 - 0.4))

                    PlasmaComponents.Label {
                        visible: !root.wall
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.failed ? "mural not found" : "Loading…"
                        color: root.dim
                    }

                    ColumnLayout {
                        visible: !!root.wall
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.largeSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing * 2
                            visible: !!root.current

                            Kirigami.ShadowedImage {
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                                Layout.preferredHeight: Math.round(Layout.preferredWidth * 9 / 21)
                                source: root.current ? root.imageUrl(root.current.path) : ""
                                sourceSize.width: Kirigami.Units.gridUnit * 6
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                radius: Kirigami.Units.cornerRadius
                                color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                Caption { text: "Now showing" }
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: root.current ? root.current.title : ""
                                    elide: Text.ElideRight
                                }
                            }
                            IconAction {
                                icon: root.hideIcon
                                tone: Kirigami.Theme.neutralTextColor
                                hint: "Remove from rotation"
                                onClicked: root.advance("exclude " + root.quote(root.current.id))
                            }
                            IconAction {
                                icon: "edit-delete"
                                tone: Kirigami.Theme.negativeTextColor
                                alert: root.deleteArmed
                                label: root.deleteArmed ? "Delete?" : ""
                                hint: root.deleteArmed ? "Click again to move it to the trash" : "Delete this wallpaper"
                                onClicked: {
                                    if (root.deleteArmed) {
                                        root.deleteArmed = false
                                        root.advance("delete " + root.quote(root.current.id))
                                    } else {
                                        root.deleteArmed = true
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: !!root.current
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: root.hairline
                        }

                        Caption { text: "Up next" }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.round(width * 9 / 21)
                            radius: Kirigami.Units.cornerRadius * 2
                            color: Qt.alpha(Kirigami.Theme.textColor, 0.06)

                            Kirigami.ShadowedImage {
                                id: preview
                                anchors.fill: parent
                                source: root.upNext ? root.imageUrl(root.upNext.path) : ""
                                sourceSize.width: Kirigami.Units.gridUnit * 48
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                radius: parent.radius
                                color: "transparent"
                                opacity: status === Image.Ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
                            }
                            PlasmaComponents.Label {
                                anchors.centerIn: parent
                                visible: !root.upNext
                                text: root.wall && root.wall.total === 0 ? "No wallpapers in library" : "Nothing queued"
                                color: root.dim
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: !!root.upNext
                            spacing: Kirigami.Units.smallSpacing * 2

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: root.upNext ? root.upNext.title : ""
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                PlasmaComponents.Label {
                                    Layout.fillWidth: true
                                    text: root.upNext ? root.upNext.collection : ""
                                    color: root.dim
                                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                                    elide: Text.ElideRight
                                }
                            }
                            PlasmaComponents.Label {
                                readonly property string url: root.pageUrl(root.upNext)
                                visible: url !== ""
                                text: (root.host(url) || "source") + " ↗"
                                color: linkHover.containsMouse ? Kirigami.Theme.linkColor : Qt.alpha(Kirigami.Theme.linkColor, 0.8)
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                                font.underline: linkHover.containsMouse
                                MouseArea {
                                    id: linkHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.openUrlExternally(parent.url)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing * 2

                            Action {
                                text: "Show now"
                                icon: "media-skip-forward"
                                enabled: !!root.upNext
                                onClicked: root.advance("next")
                            }
                            Action {
                                text: "Skip"
                                icon: "media-playlist-shuffle"
                                enabled: !!root.upNext
                                onClicked: root.run("skip")
                            }
                            Action {
                                text: "Remove"
                                icon: root.hideIcon
                                tone: Kirigami.Theme.neutralTextColor
                                enabled: !!root.upNext
                                onClicked: root.run("exclude " + root.quote(root.upNext.id))
                            }
                        }

                        Action {
                            text: "Manage…"
                            icon: "configure"
                            onClicked: root.openManager()
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: root.hairline
                        }

                        Caption { text: "Collection" }
                        Flow {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing * 1.5

                            Chip {
                                text: "All (" + (root.wall ? root.wall.total : 0) + ")"
                                active: !!root.wall && root.wall.collection === "all"
                                onClicked: if (!active) root.advance("collection all")
                            }
                            Repeater {
                                model: root.wall ? root.wall.collections : []
                                Chip {
                                    required property var modelData
                                    text: modelData.name + " (" + modelData.count + ")"
                                    active: !!root.wall && root.wall.collection === modelData.name
                                    onClicked: if (!active) root.advance("collection " + root.quote(modelData.name))
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Kirigami.Units.largeSpacing
                                Caption { text: "Interval" }
                                Row {
                                    spacing: Kirigami.Units.smallSpacing * 1.5
                                    Repeater {
                                        model: root.intervals
                                        Chip {
                                            required property var modelData
                                            text: modelData.label
                                            active: !!root.wall && root.wall.interval === modelData.minutes
                                            onClicked: if (!active) root.run("interval " + modelData.minutes)
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.alignment: Qt.AlignRight | Qt.AlignTop
                                spacing: Kirigami.Units.smallSpacing
                                Caption {
                                    Layout.alignment: Qt.AlignRight
                                    text: "Rotation"
                                }
                                PlasmaComponents.Switch {
                                    Layout.alignment: Qt.AlignRight
                                    checked: root.rotating
                                    onToggled: {
                                        root.wall = Object.assign({}, root.wall, { enabled: checked })
                                        root.advance(checked ? "on" : "off")
                                        checked = Qt.binding(() => root.rotating)
                                    }
                                }
                            }
                        }

                        PlasmaComponents.Label {
                            visible: !!root.wall && root.wall.excluded > 0
                            text: root.wall ? root.wall.excluded + " excluded" : ""
                            color: root.dim
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }
                }
            }
        }
    }
}
