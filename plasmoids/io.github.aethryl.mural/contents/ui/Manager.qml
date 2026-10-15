import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Rectangle {
    id: manager

    required property var app

    readonly property var wall: app.wall
    readonly property var images: app.library ? app.library.images : []
    readonly property var collections: wall ? wall.collections : []
    readonly property var collectionNames: collections.map(c => c.name)
    readonly property var sidebarModel: [{ name: "all", label: "All", count: wall ? wall.total : images.length }].concat(collections.map(c => ({ name: c.name, label: c.name, count: c.count })))
    readonly property var visibleImages: selectedCollection === "all" ? images : images.filter(image => image.collection === selectedCollection)
    readonly property var selectedIds: Object.keys(selection).filter(id => selection[id])
    readonly property int selectionCount: selectedIds.length
    readonly property int sidebarIndex: sidebarModel.findIndex(entry => entry.name === selectedCollection)
    readonly property int rotateIndex: wall && wall.collection !== "all" ? collectionNames.indexOf(wall.collection) + 1 : 0
    readonly property bool narrow: width < Kirigami.Units.gridUnit * 44
    readonly property var presets: [
        { minutes: 5, label: "5m" },
        { minutes: 10, label: "10m" },
        { minutes: 15, label: "15m" },
        { minutes: 30, label: "30m" },
        { minutes: 60, label: "1h" },
        { minutes: 120, label: "2h" },
        { minutes: 180, label: "3h" },
        { minutes: 360, label: "6h" },
        { minutes: 720, label: "12h" },
        { minutes: 1440, label: "24h" },
    ]

    property string selectedCollection: "all"
    property var selection: ({})
    property string panel: ""
    property string panelError: ""
    property string errorText: ""
    property bool deleteArmed: false
    property var preview: null
    readonly property var hostWindow: Window.window

    implicitWidth: Kirigami.Units.gridUnit * 60
    implicitHeight: Kirigami.Units.gridUnit * 40
    Layout.preferredWidth: Kirigami.Units.gridUnit * 60
    Layout.preferredHeight: Kirigami.Units.gridUnit * 40
    Layout.minimumWidth: Kirigami.Units.gridUnit * 28
    Layout.minimumHeight: Kirigami.Units.gridUnit * 28

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false
    color: Kirigami.Theme.backgroundColor

    Component.onCompleted: app.refresh()
    onHostWindowChanged: {
        if (!app.windowed || !hostWindow || hostWindow.width > Layout.minimumWidth)
            return
        hostWindow.width = Math.min(Layout.preferredWidth, Screen.desktopAvailableWidth * 0.9)
        hostWindow.height = Math.min(Layout.preferredHeight, Screen.desktopAvailableHeight * 0.9)
    }

    onSelectedCollectionChanged: {
        selection = {}
        deleteArmed = false
        if (panel !== "new")
            panel = ""
    }
    onCollectionNamesChanged: if (selectedCollection !== "all" && collectionNames.indexOf(selectedCollection) < 0) selectedCollection = "all"
    onDeleteArmedChanged: if (deleteArmed) disarm.restart()
    onErrorTextChanged: errorMessage.visible = errorText !== ""

    function q(value) {
        return app.quote(value)
    }

    function act(args, inPanel, done) {
        app.mutate(args, result => {
            if (result.ok) {
                if (inPanel)
                    manager.panelError = ""
                else
                    manager.errorText = ""
                if (done)
                    done(result)
            } else if (inPanel) {
                manager.panelError = result.error
            } else {
                manager.errorText = result.error
            }
        })
    }

    function toggle(id) {
        const next = Object.assign({}, selection)
        if (next[id])
            delete next[id]
        else
            next[id] = true
        selection = next
    }

    function selectAll() {
        const next = {}
        visibleImages.forEach(image => next[image.id] = true)
        selection = next
    }

    function selectedArgs() {
        return selectedIds.map(id => q(id)).join(" ")
    }

    function countOf(name) {
        const match = collections.find(c => c.name === name)
        return match ? match.count : 0
    }

    function openPanel(name) {
        if (name !== "new" && selectedCollection === "all")
            return
        panelError = ""
        panel = name
        if (name === "new") {
            nameField.text = ""
            nameField.forceActiveFocus()
        } else if (name === "rename") {
            nameField.text = selectedCollection
            nameField.forceActiveFocus()
            nameField.selectAll()
        }
    }

    function togglePanel(name) {
        if (panel === name)
            panel = ""
        else
            openPanel(name)
    }

    function submitName() {
        const name = nameField.text.trim()
        if (name === "")
            return
        if (panel === "new") {
            act("mkcol " + q(name), true, () => {
                manager.panel = ""
                manager.selectedCollection = name
            })
        } else if (panel === "rename") {
            if (name === selectedCollection) {
                panel = ""
                return
            }
            act("rename " + q(selectedCollection) + " " + q(name), true, () => {
                manager.panel = ""
                manager.selectedCollection = name
            })
        }
    }

    function removeCollection() {
        const name = selectedCollection
        const into = moveRadio.checked && intoBox.currentText ? " --into " + q(intoBox.currentText) : ""
        act("rmcol " + q(name) + into, true, () => {
            manager.panel = ""
            manager.selectedCollection = "all"
        })
    }

    function objectsOf(instantiator) {
        const list = []
        for (let i = 0; i < instantiator.count; i++)
            list.push(instantiator.objectAt(i))
        return list
    }

    Binding {
        target: manager.hostWindow
        when: manager.app.windowed && manager.hostWindow !== null
        property: "minimumWidth"
        value: manager.Layout.minimumWidth
    }

    Binding {
        target: manager.hostWindow
        when: manager.app.windowed && manager.hostWindow !== null
        property: "minimumHeight"
        value: manager.Layout.minimumHeight
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: manager.deleteArmed = false
    }

    Instantiator {
        id: presetActions
        model: manager.presets
        delegate: Kirigami.Action {
            required property var modelData
            text: modelData.label
            checkable: true
            checked: !!manager.wall && manager.wall.interval === modelData.minutes
            onTriggered: {
                manager.act("interval " + modelData.minutes, false)
                checked = Qt.binding(() => !!manager.wall && manager.wall.interval === modelData.minutes)
            }
        }
    }

    Instantiator {
        id: moveActions
        model: manager.collectionNames
        delegate: Kirigami.Action {
            required property string modelData
            text: modelData
            icon.name: "folder-pictures"
            onTriggered: manager.act("move " + manager.q(modelData) + " " + manager.selectedArgs(), false, () => manager.selection = {})
        }
    }

    component Pill: Rectangle {
        property alias text: pillLabel.text
        property color tone: Kirigami.Theme.highlightColor
        property color ink: Kirigami.Theme.highlightedTextColor
        implicitWidth: pillLabel.implicitWidth + Kirigami.Units.smallSpacing * 3
        implicitHeight: pillLabel.implicitHeight + Kirigami.Units.smallSpacing
        radius: height / 2
        color: tone
        QQC2.Label {
            id: pillLabel
            anchors.centerIn: parent
            color: parent.ink
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            font.weight: Font.DemiBold
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: header.implicitHeight + Kirigami.Units.largeSpacing * 2
            Kirigami.Theme.colorSet: Kirigami.Theme.Header
            Kirigami.Theme.inherit: false
            color: Kirigami.Theme.backgroundColor

            ColumnLayout {
                id: header
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing

                GridLayout {
                    Layout.fillWidth: true
                    columns: manager.narrow ? 1 : 2
                    rowSpacing: Kirigami.Units.largeSpacing
                    columnSpacing: Kirigami.Units.largeSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.ShadowedImage {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                            Layout.preferredHeight: Math.round(Kirigami.Units.gridUnit * 4 * 9 / 21)
                            visible: !!manager.app.current
                            source: manager.app.current ? manager.app.imageUrl(manager.app.current.path) : ""
                            sourceSize.width: Kirigami.Units.gridUnit * 4
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            radius: Kirigami.Units.cornerRadius
                            color: Qt.alpha(Kirigami.Theme.textColor, 0.08)
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 0
                            Kirigami.Heading {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                level: 3
                                text: manager.app.current ? manager.app.current.title : manager.app.failed ? "mural not found" : "No wallpaper set"
                                elide: Text.ElideRight
                            }
                            QQC2.Label {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                text: manager.wall ? manager.wall.total + " wallpapers · " + manager.wall.excluded + " excluded" + (manager.app.current ? " · now from " + manager.app.current.collection : "") : ""
                                color: Kirigami.Theme.disabledTextColor
                                elide: Text.ElideRight
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: manager.narrow
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: Kirigami.Units.mediumSpacing

                        QQC2.Label {
                            text: "Rotate"
                        }
                        QQC2.ComboBox {
                            id: rotateBox
                            Layout.fillWidth: manager.narrow
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 10
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                            model: ["All"].concat(manager.collectionNames)
                            currentIndex: manager.rotateIndex
                            onActivated: index => {
                                manager.act("collection " + (index === 0 ? "all" : manager.q(manager.collectionNames[index - 1])), false)
                                currentIndex = Qt.binding(() => manager.rotateIndex)
                            }
                        }
                        QQC2.Switch {
                            text: "Rotation"
                            checked: manager.app.rotating
                            onToggled: {
                                manager.act(checked ? "on" : "off", false)
                                checked = Qt.binding(() => manager.app.rotating)
                            }
                        }
                        QQC2.Button {
                            text: "Next"
                            icon.name: "media-skip-forward"
                            enabled: !!manager.wall && manager.wall.total > 0
                            onClicked: manager.act("next", false)
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.mediumSpacing

                    QQC2.Label {
                        text: "Every"
                    }
                    Kirigami.ActionToolBar {
                        Layout.fillWidth: true
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 2
                        actions: manager.objectsOf(presetActions)
                    }
                    QQC2.Label {
                        text: "Custom"
                    }
                    QQC2.SpinBox {
                        id: minutes
                        from: 1
                        to: 10080
                        editable: true
                        value: manager.wall ? manager.wall.interval : 30
                    }
                    QQC2.Label {
                        text: "min"
                    }
                    QQC2.Button {
                        text: "Apply"
                        enabled: !!manager.wall && minutes.value !== manager.wall.interval
                        onClicked: {
                            manager.act("interval " + minutes.value, false)
                            minutes.value = Qt.binding(() => manager.wall ? manager.wall.interval : 30)
                        }
                    }
                }
            }
        }

        Kirigami.Separator {
            Layout.fillWidth: true
        }

        Kirigami.InlineMessage {
            id: errorMessage
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            type: Kirigami.MessageType.Error
            visible: false
            text: manager.errorText
            showCloseButton: true
            onVisibleChanged: if (!visible) manager.errorText = ""
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: manager.narrow ? 1 : 3
            rowSpacing: 0
            columnSpacing: 0

            ColumnLayout {
                Layout.fillWidth: manager.narrow
                Layout.fillHeight: !manager.narrow
                Layout.preferredWidth: Kirigami.Units.gridUnit * 13
                spacing: 0

                QQC2.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !manager.narrow

                    ListView {
                        id: sidebar
                        clip: true
                        model: manager.sidebarModel
                        delegate: QQC2.ItemDelegate {
                            id: entry
                            required property var modelData
                            width: ListView.view.width
                            highlighted: manager.selectedCollection === modelData.name
                            onClicked: {
                                manager.panel = ""
                                manager.selectedCollection = modelData.name
                            }
                            contentItem: RowLayout {
                                spacing: Kirigami.Units.smallSpacing
                                Kirigami.Icon {
                                    source: entry.modelData.name === "all" ? "view-list-icons" : "folder-pictures"
                                    selected: entry.highlighted
                                    implicitWidth: Kirigami.Units.iconSizes.smallMedium
                                    implicitHeight: Kirigami.Units.iconSizes.smallMedium
                                }
                                QQC2.Label {
                                    Layout.fillWidth: true
                                    Layout.minimumWidth: 0
                                    text: entry.modelData.label
                                    color: entry.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.textColor
                                    elide: Text.ElideRight
                                }
                                Kirigami.Icon {
                                    visible: !!manager.wall && manager.wall.collection === entry.modelData.name
                                    source: "media-playlist-repeat"
                                    selected: entry.highlighted
                                    implicitWidth: Kirigami.Units.iconSizes.small
                                    implicitHeight: Kirigami.Units.iconSizes.small
                                }
                                QQC2.Label {
                                    text: entry.modelData.count
                                    color: entry.highlighted ? Kirigami.Theme.highlightedTextColor : Kirigami.Theme.disabledTextColor
                                    font.features: { "tnum": 1 }
                                }
                            }
                        }
                    }
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                    visible: !manager.narrow
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.ComboBox {
                            Layout.fillWidth: true
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 6
                            visible: manager.narrow
                            model: manager.sidebarModel.map(entry => entry.label + " (" + entry.count + ")")
                            currentIndex: manager.sidebarIndex
                            onActivated: index => {
                                manager.panel = ""
                                manager.selectedCollection = manager.sidebarModel[index].name
                                currentIndex = Qt.binding(() => manager.sidebarIndex)
                            }
                        }
                        QQC2.ToolButton {
                            icon.name: "list-add"
                            text: "New"
                            display: QQC2.AbstractButton.TextBesideIcon
                            checked: manager.panel === "new"
                            onClicked: manager.togglePanel("new")
                        }
                        QQC2.ToolButton {
                            icon.name: "edit-rename"
                            text: "Rename"
                            display: QQC2.AbstractButton.IconOnly
                            enabled: manager.selectedCollection !== "all"
                            checked: manager.panel === "rename"
                            onClicked: manager.togglePanel("rename")
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        }
                        QQC2.ToolButton {
                            icon.name: "edit-delete"
                            text: "Delete collection"
                            display: QQC2.AbstractButton.IconOnly
                            enabled: manager.selectedCollection !== "all"
                            checked: manager.panel === "remove"
                            onClicked: manager.togglePanel("remove")
                            QQC2.ToolTip.text: text
                            QQC2.ToolTip.visible: hovered
                            QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                        }
                        Item {
                            Layout.fillWidth: !manager.narrow
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: manager.panel === "new" || manager.panel === "rename"
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.Label {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: manager.panel === "new" ? "New collection" : "Rename “" + manager.selectedCollection + "”"
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        QQC2.TextField {
                            id: nameField
                            Layout.fillWidth: true
                            Layout.minimumWidth: Kirigami.Units.gridUnit * 6
                            placeholderText: "Name"
                            maximumLength: 48
                            onAccepted: manager.submitName()
                            Keys.onEscapePressed: manager.panel = ""
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            QQC2.Button {
                                text: manager.panel === "new" ? "Create" : "Rename"
                                enabled: nameField.text.trim() !== ""
                                onClicked: manager.submitName()
                            }
                            QQC2.Button {
                                text: "Cancel"
                                onClicked: manager.panel = ""
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: manager.panel === "remove"
                        spacing: Kirigami.Units.smallSpacing

                        QQC2.Label {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            text: "Delete “" + manager.selectedCollection + "”" + (manager.countOf(manager.selectedCollection) > 0 ? " (" + manager.countOf(manager.selectedCollection) + " images)?" : "?")
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: manager.countOf(manager.selectedCollection) > 0
                            spacing: 0
                            QQC2.RadioButton {
                                id: moveRadio
                                text: "Move images to"
                                checked: true
                                enabled: intoBox.count > 0
                            }
                            QQC2.ComboBox {
                                id: intoBox
                                Layout.fillWidth: true
                                Layout.minimumWidth: Kirigami.Units.gridUnit * 5
                                Layout.leftMargin: Kirigami.Units.gridUnit
                                enabled: moveRadio.checked
                                model: manager.collectionNames.filter(name => name !== manager.selectedCollection)
                            }
                            QQC2.RadioButton {
                                id: trashRadio
                                text: "Delete images too"
                                checked: intoBox.count === 0
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing
                            QQC2.Button {
                                text: "Delete"
                                icon.name: "edit-delete"
                                onClicked: manager.removeCollection()
                            }
                            QQC2.Button {
                                text: "Cancel"
                                onClicked: manager.panel = ""
                            }
                        }
                    }

                    QQC2.Label {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        visible: manager.panel !== "" && manager.panelError !== ""
                        text: manager.panelError
                        color: Kirigami.Theme.negativeTextColor
                        wrapMode: Text.Wrap
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: manager.narrow
                Layout.fillHeight: !manager.narrow
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.mediumSpacing

                    QQC2.Label {
                        Layout.leftMargin: Kirigami.Units.smallSpacing
                        text: manager.selectionCount > 0 ? manager.selectionCount + " selected" : manager.visibleImages.length + " images"
                        font.weight: Font.DemiBold
                    }
                    Kirigami.ActionToolBar {
                        Layout.fillWidth: true
                        Layout.minimumWidth: Kirigami.Units.gridUnit * 2
                        alignment: Qt.AlignRight
                        actions: [
                            Kirigami.Action {
                                text: "Select all"
                                icon.name: "edit-select-all"
                                enabled: manager.visibleImages.length > 0
                                onTriggered: manager.selectAll()
                            },
                            Kirigami.Action {
                                text: "Clear"
                                icon.name: "edit-select-none"
                                enabled: manager.selectionCount > 0
                                onTriggered: manager.selection = {}
                            },
                            Kirigami.Action {
                                separator: true
                            },
                            Kirigami.Action {
                                text: "Exclude"
                                icon.source: Qt.resolvedUrl("../images/eye-off.svg")
                                icon.color: Kirigami.Theme.textColor
                                enabled: manager.selectionCount > 0
                                onTriggered: manager.act("exclude " + manager.selectedArgs(), false)
                            },
                            Kirigami.Action {
                                text: "Include"
                                icon.name: "view-visible"
                                enabled: manager.selectionCount > 0
                                onTriggered: manager.act("include " + manager.selectedArgs(), false)
                            },
                            Kirigami.Action {
                                text: "Move to"
                                icon.name: "go-next"
                                enabled: manager.selectionCount > 0 && moveActions.count > 0
                                children: manager.objectsOf(moveActions)
                            },
                            Kirigami.Action {
                                text: manager.deleteArmed ? "Click again to delete" : "Delete"
                                icon.name: "edit-delete"
                                enabled: manager.selectionCount > 0
                                displayHint: Kirigami.DisplayHint.KeepVisible
                                onTriggered: {
                                    if (manager.deleteArmed) {
                                        manager.deleteArmed = false
                                        manager.act("delete " + manager.selectedArgs(), false, () => manager.selection = {})
                                    } else {
                                        manager.deleteArmed = true
                                    }
                                }
                            }
                        ]
                    }
                }

                Kirigami.Separator {
                    Layout.fillWidth: true
                }

                QQC2.ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 0
                    Layout.minimumHeight: Kirigami.Units.gridUnit * 6
                    QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                    GridView {
                        id: grid
                        readonly property real target: Kirigami.Units.gridUnit * 13
                        readonly property real usable: width - leftMargin - rightMargin
                        readonly property int columns: Math.max(1, Math.floor(usable / target))
                        readonly property real pad: Kirigami.Units.smallSpacing
                        readonly property real thumbWidth: cellWidth - pad * 2
                        readonly property int decodeWidth: Math.ceil(thumbWidth / (Kirigami.Units.gridUnit * 4)) * Kirigami.Units.gridUnit * 4
                        clip: true
                        leftMargin: Kirigami.Units.smallSpacing
                        rightMargin: Kirigami.Units.smallSpacing
                        topMargin: Kirigami.Units.smallSpacing
                        bottomMargin: Kirigami.Units.smallSpacing
                        cellWidth: Math.floor(usable / columns)
                        cellHeight: Math.round(thumbWidth * 9 / 21) + caption.implicitHeight + pad * 3
                        model: manager.visibleImages
                        reuseItems: false

                        QQC2.Label {
                            id: caption
                            visible: false
                            text: " "
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }

                        delegate: Item {
                            id: tile
                            required property var modelData
                            readonly property bool selected: !!manager.selection[modelData.id]
                            width: grid.cellWidth
                            height: grid.cellHeight

                            Item {
                                id: frame
                                x: grid.pad
                                y: grid.pad
                                width: grid.thumbWidth
                                height: Math.round(width * 9 / 21)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: Kirigami.Units.cornerRadius
                                    color: Qt.alpha(Kirigami.Theme.textColor, 0.06)
                                }
                                Kirigami.ShadowedImage {
                                    anchors.fill: parent
                                    source: manager.app.imageUrl(tile.modelData.path)
                                    sourceSize.width: grid.decodeWidth
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    radius: Kirigami.Units.cornerRadius
                                    color: "transparent"
                                    opacity: status !== Image.Ready ? 0 : tile.modelData.excluded ? 0.35 : 1
                                    Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: Kirigami.Units.cornerRadius
                                    color: tile.selected ? Qt.alpha(Kirigami.Theme.highlightColor, 0.2) : tileMouse.containsMouse ? Qt.alpha(Kirigami.Theme.highlightColor, 0.1) : "transparent"
                                    border.width: tile.selected ? Math.round(Kirigami.Units.smallSpacing * 0.75) : tile.modelData.current ? Math.round(Kirigami.Units.smallSpacing / 2) : 0
                                    border.color: tile.selected ? Kirigami.Theme.highlightColor : Kirigami.Theme.positiveTextColor
                                }
                                Kirigami.Icon {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: Kirigami.Units.smallSpacing
                                    width: Kirigami.Units.iconSizes.smallMedium
                                    height: width
                                    visible: tile.selected
                                    source: "checkbox"
                                    color: Kirigami.Theme.highlightColor
                                }
                                Row {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: Kirigami.Units.smallSpacing
                                    spacing: Kirigami.Units.smallSpacing
                                    Pill {
                                        visible: tile.modelData.excluded
                                        text: "excluded"
                                        tone: Kirigami.Theme.neutralBackgroundColor
                                        ink: Kirigami.Theme.neutralTextColor
                                    }
                                    Pill {
                                        visible: tile.modelData.current
                                        text: "current"
                                        tone: Kirigami.Theme.positiveBackgroundColor
                                        ink: Kirigami.Theme.positiveTextColor
                                    }
                                }
                            }
                            QQC2.Label {
                                anchors.left: frame.left
                                anchors.right: frame.right
                                anchors.top: frame.bottom
                                anchors.topMargin: Kirigami.Units.smallSpacing
                                text: tile.modelData.title
                                elide: Text.ElideRight
                                color: tile.modelData.excluded ? Kirigami.Theme.disabledTextColor : Kirigami.Theme.textColor
                                font.pointSize: Kirigami.Theme.smallFont.pointSize
                            }
                            MouseArea {
                                id: tileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: manager.toggle(tile.modelData.id)
                                onDoubleClicked: manager.preview = tile.modelData
                            }
                        }

                        Kirigami.PlaceholderMessage {
                            anchors.centerIn: parent
                            width: parent.width - Kirigami.Units.gridUnit * 4
                            visible: grid.count === 0
                            icon.name: "preferences-desktop-wallpaper"
                            text: manager.app.library ? "No wallpapers here" : "Loading…"
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: overlay
        anchors.fill: parent
        visible: !!manager.preview
        color: Qt.alpha(Kirigami.Theme.backgroundColor, 0.96)
        focus: visible
        Keys.onEscapePressed: manager.preview = null

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: manager.preview = null
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.gridUnit
            spacing: Kirigami.Units.largeSpacing

            Image {
                id: full
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
                source: manager.preview ? manager.app.imageUrl(manager.preview.path) : ""
                sourceSize.width: Math.ceil(overlay.width / (Kirigami.Units.gridUnit * 8)) * Kirigami.Units.gridUnit * 8
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                QQC2.BusyIndicator {
                    anchors.centerIn: parent
                    running: full.status === Image.Loading
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.largeSpacing
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    spacing: 0
                    Kirigami.Heading {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        level: 3
                        text: manager.preview ? manager.preview.title : ""
                        elide: Text.ElideRight
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        text: manager.preview ? manager.preview.collection + (manager.preview.source ? " · " + manager.preview.source : "") + (manager.preview.excluded ? " · excluded" : "") : ""
                        color: Kirigami.Theme.disabledTextColor
                        elide: Text.ElideRight
                    }
                }
                QQC2.Button {
                    readonly property string url: manager.app.pageUrl(manager.preview)
                    visible: url.indexOf("://") > 0
                    text: (manager.app.host(url) || "Source") + " ↗"
                    icon.name: "internet-services"
                    onClicked: Qt.openUrlExternally(url)
                }
                QQC2.Button {
                    text: "Close"
                    icon.name: "window-close"
                    onClicked: manager.preview = null
                }
            }
        }
    }
}
