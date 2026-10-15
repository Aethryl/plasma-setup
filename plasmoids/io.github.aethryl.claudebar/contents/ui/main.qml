import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Window
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: root

    readonly property string script: Qt.resolvedUrl("../code/claudebar.py").toString().replace("file://", "")
    readonly property string command: "python3 '" + script + "'"
    property var bar: null
    property real now: Date.now() / 1000
    property real compactWidth: Kirigami.Units.gridUnit * 20
    property Item compactItem: null
    property bool drooped: false
    property bool showIdle: false

    readonly property real ear: Kirigami.Units.gridUnit * 0.7
    readonly property real bottomRadius: Kirigami.Units.gridUnit * 1.1

    readonly property var agents: bar && bar.agents ? bar.agents : null
    readonly property var activeAgents: agents ? agents.list.filter(a => a.status !== "idle") : []
    readonly property var idleAgents: agents ? agents.list.filter(a => a.status === "idle") : []

    readonly property color ok: Kirigami.Theme.positiveTextColor
    readonly property color warning: Kirigami.Theme.neutralTextColor
    readonly property color critical: Kirigami.Theme.negativeTextColor
    readonly property color blocked: Kirigami.Theme.neutralTextColor
    readonly property color dim: Kirigami.Theme.disabledTextColor
    readonly property color hairline: Qt.alpha(Kirigami.Theme.textColor, 0.1)

    preferredRepresentation: compactRepresentation
    fullRepresentation: Item {}
    Plasmoid.backgroundHints: "NoBackground"

    function pctColor(pct) {
        return pct >= 85 ? critical : pct >= 60 ? warning : ok
    }

    function statusColor(status) {
        return status === "working" ? ok : status === "blocked" ? blocked : dim
    }

    function timeLeft(resetsAt) {
        if (!resetsAt)
            return ""
        const s = Math.max(0, resetsAt - now)
        const half = v => String(Math.round(v * 2) / 2)
        if (s >= 86400)
            return half(s / 86400) + "d"
        if (s >= 3600)
            return half(s / 3600) + "h"
        return Math.max(1, Math.round(s / 60)) + "m"
    }

    function resetClock(resetsAt) {
        const fmt = resetsAt - now > 86400 ? "ddd HH:mm" : "HH:mm"
        return new Date(resetsAt * 1000).toLocaleString(Qt.locale(), fmt)
    }

    function shortPath(path) {
        return (path || "").replace(/^\/home\/[^/]+/, "~")
    }

    function project(path) {
        const parts = (path || "").split("/").filter(p => p)
        return parts.length ? parts[parts.length - 1] : "~"
    }

    function parentPath(path) {
        return shortPath(path).replace(/\/[^/]*$/, "")
    }

    function focusAgent(terminalId) {
        executable.connectSource("\"$HOME/.local/bin/herdr\" agent focus " + terminalId)
        root.drooped = false
    }

    toolTipMainText: ""
    toolTipSubText: ""

    P5Support.DataSource {
        id: executable
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source)
            if (source !== root.command)
                return
            try {
                root.bar = JSON.parse(data["stdout"])
            } catch (e) {}
            root.now = Date.now() / 1000
        }
    }

    Timer {
        interval: root.drooped ? 2000 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: executable.connectSource(root.command)
    }

    component Dot: Rectangle {
        property color dotColor
        property bool pulse: false
        implicitWidth: Kirigami.Units.smallSpacing * 2
        implicitHeight: implicitWidth
        radius: width / 2
        color: dotColor
        SequentialAnimation on opacity {
            running: pulse
            loops: Animation.Infinite
            NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutQuad }
        }
    }

    component Count: RowLayout {
        id: count
        property color dotColor
        property var value
        property bool pulse: false
        spacing: Kirigami.Units.smallSpacing / 2
        Item {
            id: dotSlot
            readonly property bool beating: count.pulse && count.visible
            readonly property bool animated: Kirigami.Units.longDuration > 0
            implicitWidth: dot.implicitWidth
            implicitHeight: dot.implicitHeight
            Layout.alignment: Qt.AlignVCenter

            function settle() {
                dot.scale = 1
                halo.scale = 1
                halo.opacity = beating && !animated ? 0.35 : 0
            }
            onBeatingChanged: settle()
            onAnimatedChanged: settle()

            Rectangle {
                id: halo
                anchors.fill: parent
                radius: width / 2
                color: count.dotColor
                opacity: 0
            }
            Dot {
                id: dot
                anchors.fill: parent
                dotColor: count.dotColor
            }
            ParallelAnimation {
                running: dotSlot.beating && dotSlot.animated
                loops: Animation.Infinite
                onRunningChanged: if (!running) dotSlot.settle()
                SequentialAnimation {
                    NumberAnimation { target: dot; property: "scale"; from: 1; to: 1.3; duration: 700; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: dot; property: "scale"; from: 1.3; to: 1; duration: 700; easing.type: Easing.InOutQuad }
                }
                NumberAnimation { target: halo; property: "scale"; from: 1; to: 2.6; duration: 1400; easing.type: Easing.OutQuad }
                NumberAnimation { target: halo; property: "opacity"; from: 0.35; to: 0; duration: 1400; easing.type: Easing.OutQuad }
            }
        }
        PlasmaComponents.Label {
            text: value === undefined || value === null ? "–" : value
            color: value ? Kirigami.Theme.textColor : root.dim
        }
    }

    component Bar: Rectangle {
        property real pct
        property color fill
        implicitHeight: Kirigami.Units.smallSpacing * 1.5
        radius: height / 2
        color: Qt.alpha(Kirigami.Theme.textColor, 0.15)
        Rectangle {
            width: parent.width * Math.min(100, pct) / 100
            height: parent.height
            radius: parent.radius
            color: fill
            Behavior on width { NumberAnimation { duration: Kirigami.Units.longDuration } }
        }
    }

    component Meter: RowLayout {
        property string label
        property var win
        readonly property real pct: win ? win.pct : 0
        spacing: Kirigami.Units.smallSpacing
        opacity: root.bar && root.bar.stale ? 0.5 : 1
        PlasmaComponents.Label {
            text: label
            color: root.dim
        }
        Bar {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 3
            pct: parent.pct
            fill: root.pctColor(parent.pct)
        }
        PlasmaComponents.Label {
            text: win ? Math.round(pct) + "%" : "--"
            color: win ? root.pctColor(pct) : root.dim
            font.bold: true
        }
        PlasmaComponents.Label {
            visible: !!(win && win.resets_at)
            text: win ? root.timeLeft(win.resets_at) : ""
            color: root.dim
        }
    }

    component Limit: ColumnLayout {
        id: limit
        property string title
        property var win
        readonly property real pct: win ? win.pct : 0
        readonly property color accent: win ? root.pctColor(pct) : root.dim
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: Kirigami.Units.smallSpacing
        opacity: root.bar && root.bar.stale ? 0.5 : 1

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: limit.title
                color: root.dim
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1
            }
            PlasmaComponents.Label {
                text: limit.win ? Math.round(limit.pct) + "%" : "--"
                color: limit.accent
                font.weight: Font.DemiBold
            }
        }
        Bar {
            Layout.fillWidth: true
            pct: limit.pct
            fill: limit.accent
        }
        PlasmaComponents.Label {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: limit.win && limit.win.resets_at
                ? root.timeLeft(limit.win.resets_at) + " · " + root.resetClock(limit.win.resets_at)
                : " "
            color: root.dim
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }

    component AgentRow: Rectangle {
        id: agentRow
        property var agent
        Layout.fillWidth: true
        implicitHeight: Kirigami.Units.gridUnit * 1.4
        radius: Kirigami.Units.cornerRadius
        color: hover.containsMouse ? Qt.alpha(Kirigami.Theme.highlightColor, 0.25) : "transparent"

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Kirigami.Units.smallSpacing * 1.5
            anchors.rightMargin: Kirigami.Units.smallSpacing * 1.5
            spacing: Kirigami.Units.smallSpacing * 2

            Dot {
                dotColor: root.statusColor(agentRow.agent.status)
                pulse: agentRow.agent.status === "working"
            }
            PlasmaComponents.Label {
                text: root.project(agentRow.agent.cwd)
                font.weight: agentRow.agent.focused ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                Layout.maximumWidth: agentRow.width * 0.6
            }
            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: root.parentPath(agentRow.agent.cwd)
                color: root.dim
                elide: Text.ElideLeft
                horizontalAlignment: Text.AlignRight
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }

        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.focusAgent(agentRow.agent.terminal_id)
        }
    }

    compactRepresentation: Item {
        id: holder
        Layout.minimumWidth: row.implicitWidth
        Layout.preferredWidth: row.implicitWidth
        Layout.fillWidth: true
        property real globalX: 0
        function place() { globalX = mapToGlobal(0, 0).x }
        onXChanged: place()
        onWidthChanged: place()
        Component.onCompleted: { root.compactItem = area; place() }

        MouseArea {
            id: area
            width: row.implicitWidth
            height: parent.height
            x: Math.max(0, Math.min(holder.width - width, holder.Screen.virtualX + holder.Screen.width / 2 - holder.globalX - width / 2))
            onWidthChanged: root.compactWidth = width
            onClicked: root.drooped = !root.drooped

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: Kirigami.Units.largeSpacing

                Image {
                    readonly property real dpr: Screen.devicePixelRatio || 1
                    readonly property int dot: Math.max(1, Math.round(Kirigami.Units.gridUnit * 0.7 * dpr / 12))
                    Layout.preferredHeight: dot * 12 / dpr
                    Layout.preferredWidth: dot * 18 / dpr
                    source: Qt.resolvedUrl("../images/clawd.svg")
                    sourceSize: Qt.size(Layout.preferredWidth, Layout.preferredHeight)
                    smooth: false
                }

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing * 2
                    Count { dotColor: root.ok; value: root.agents ? root.agents.working : null }
                    Count { dotColor: root.blocked; pulse: !!root.agents && root.agents.blocked > 0; value: root.agents ? root.agents.blocked : null }
                    Count { dotColor: root.dim; value: root.agents ? root.agents.idle : null }
                }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: row.height * 0.7; color: root.dim }
                Meter { label: "5h"; win: root.bar ? root.bar.five_hour : null }
                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: row.height * 0.7; color: root.dim }
                Meter { label: "7d"; win: root.bar ? root.bar.seven_day : null }
            }
        }
    }

    onDroopedChanged: {
        if (drooped) {
            droop.visible = true
            droop.requestActivate()
            reveal.to = 1
            reveal.easing.type = Easing.OutBack
            reveal.duration = 320
        } else {
            reveal.to = 0
            reveal.easing.type = Easing.InCubic
            reveal.duration = 160
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

        mainItem: Item {
            id: notch
            property real progress: 0
            focus: true
            Keys.onEscapePressed: root.drooped = false
            Kirigami.Theme.colorSet: Kirigami.Theme.Window
            Kirigami.Theme.inherit: false
            readonly property real bodyWidth: Math.max(root.compactWidth, Kirigami.Units.gridUnit * 16) + Kirigami.Units.gridUnit
            readonly property real fullHeight: content.implicitHeight + Kirigami.Units.gridUnit * 1.6
            readonly property real shownHeight: Math.max(0, fullHeight * progress)
            width: bodyWidth + root.ear * 2
            height: fullHeight * 1.1

            Shape {
                anchors.fill: parent
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
                x: root.ear
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

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.gridUnit
                        Limit { title: "Session"; win: root.bar ? root.bar.five_hour : null }
                        Limit { title: "Weekly"; win: root.bar ? root.bar.seven_day : null }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.hairline
                    }

                    PlasmaComponents.Label {
                        visible: !root.agents
                        text: "herdr not reachable"
                        color: root.dim
                    }
                    PlasmaComponents.Label {
                        visible: !!root.agents && root.activeAgents.length === 0
                        text: "No agents running"
                        color: root.dim
                    }

                    ColumnLayout {
                        visible: root.activeAgents.length > 0 || root.showIdle
                        Layout.fillWidth: true
                        spacing: 0
                        Repeater {
                            model: root.activeAgents
                            AgentRow { agent: modelData }
                        }
                        Repeater {
                            model: root.showIdle ? root.idleAgents : []
                            AgentRow { agent: modelData }
                        }
                    }

                    PlasmaComponents.Label {
                        visible: root.idleAgents.length > 0
                        text: (root.showIdle ? "Hide " : "Show ") + root.idleAgents.length + " idle"
                        color: idleHover.containsMouse ? Kirigami.Theme.textColor : root.dim
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        MouseArea {
                            id: idleHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showIdle = !root.showIdle
                        }
                    }
                }
            }
        }
    }
}
