/*
    SPDX-License-Identifier: GPL-2.0-or-later

    Modern Menu — a fast, simple and good-looking application launcher
    for Plasma 6.

    Sidebar sections:
      Favorites — pinned apps (star apps from anywhere in the menu)
      All Apps  — all applications, alphabetical
      Places    — places (Home, Documents, ...)
      System    — session actions (suspend, restart, ...)

    Plus KRunner search, grid/list layout toggle and a slim user/power bar.
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import org.kde.plasma.components as PC3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.private.kicker as Kicker

PlasmoidItem {
    id: modernMenu

    Plasmoid.icon: Plasmoid.configuration.icon

    preferredRepresentation: compactRepresentation

    width: Kirigami.Units.iconSizes.large
    height: Kirigami.Units.iconSizes.large
    switchWidth: Kirigami.Units.gridUnit * 16
    switchHeight: Kirigami.Units.gridUnit * 14

    // ---------- Models ----------

    readonly property Kicker.RootModel rootModel: Kicker.RootModel {
        autoPopulate: false

        appletInterface: modernMenu

        appNameFormat: 0
        flat: true // categories, but no sub-categories
        sorted: true
        showSeparators: false
        showTopLevelItems: true

        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: true

        Component.onCompleted: {
            favoritesModel.initForClient("org.sk.modernmenu.favorites.instance-" + Plasmoid.id)
            // Seed with a sensible default set on first run
            if (favoritesModel.count === 0) {
                favoritesModel.portOldFavorites(
                    ["org.kde.dolphin.desktop",
                     "org.kde.konsole.desktop",
                     "org.mozilla.firefox.desktop",
                     "systemsettings.desktop",
                     "org.kde.discover.desktop"])
            }
        }
        onRefreshed: modernMenu.appsModelStamp += 1
    }

    property int appsModelRow: 1
    property int appsModelStamp: 0
    readonly property var appsModel: {
        // appsModelStamp changes on every root model refresh, forcing this
        // binding to re-resolve modelForRow()
        void appsModelStamp
        return rootModel.modelForRow(appsModelRow)
    }

    readonly property Kicker.ComputerModel computerModel: Kicker.ComputerModel {
    }

    readonly property Kicker.RunnerModel runnerModel: Kicker.RunnerModel {
        query: modernMenu.searchField ? modernMenu.searchField.text : ""
        onRequestUpdateQuery: query => {
            if (modernMenu.searchField) {
                modernMenu.searchField.text = query
            }
        }
        appletInterface: modernMenu
        mergeResults: true
        favoritesModel: modernMenu.rootModel.favoritesModel
    }

    Kicker.ProcessRunner {
        id: processRunner
    }

    // ---------- State ----------

    readonly property bool showPowerButtons: Plasmoid.configuration.showPowerButtons
    readonly property bool showUserProfile: Plasmoid.configuration.showUserProfile
    readonly property string viewMode: Plasmoid.configuration.viewMode === 0 ? "grid" : "list"

    readonly property bool searching: searchField !== null && searchField.text.length > 0

    property Item searchField: null

    // 0 = All Applications, 1 = Favorites, 2 = Places, 3 = System actions
    property int currentSection: 0

    readonly property string currentSectionTitle: {
        switch (modernMenu.currentSection) {
        case 0: return i18nc("@title section header", "ALL APPLICATIONS")
        case 1: return i18nc("@title section header", "PINNED APPLICATIONS")
        case 2: return i18nc("@title section header", "PLACES")
        default: return i18nc("@title section header", "SYSTEM ACTIONS")
        }
    }

    readonly property int favoriteIdRole: KItemModels.KRoleNames.role("favoriteId")

    readonly property var powerActions: [
        { icon: "system-lock-screen-symbolic", actionId: "lock-screen", name: i18nc("@action", "Lock") },
        { icon: "system-suspend-symbolic", actionId: "suspend", name: i18nc("@action", "Suspend") },
        { icon: "system-reboot-symbolic", actionId: "reboot", name: i18nc("@action", "Restart…") },
        { icon: "system-shutdown-symbolic", actionId: "shutdown", name: i18nc("@action", "Shut Down…") },
    ]

    readonly property var sectionModel: {
        switch (modernMenu.currentSection) {
        case 0: return modernMenu.appsModel
        case 1: return modernMenu.rootModel.favoritesModel
        case 2: return modernMenu.computerModel
        default: return modernMenu.systemModel
        }
    }

    readonly property int currentSectionCount: {
        switch (modernMenu.currentSection) {
        case 0: return modernMenu.appsModel ? modernMenu.appsModel.count : 0
        case 1: return modernMenu.rootModel.favoritesModel.count
        case 2: return modernMenu.computerModel.rowCount()
        default: return modernMenu.systemModel ? modernMenu.systemModel.rowCount() : 0
        }
    }

    // ---------- Helpers ----------

    function toggleFavorite(favoriteId: string): void {
        if (!favoriteId || favoriteId.length === 0) {
            return
        }
        const m = modernMenu.rootModel.favoritesModel
        if (m.isFavorite(favoriteId)) {
            m.removeFavorite(favoriteId)
        } else {
            m.addFavorite(favoriteId)
        }
    }

    function isFavorite(favoriteId: string): bool {
        if (!favoriteId || favoriteId.length === 0) {
            return false
        }
        return modernMenu.rootModel.favoritesModel.isFavorite(favoriteId)
    }

    function activate(viewModel: QObject, row: int): bool {
        if (viewModel && typeof viewModel.trigger === "function") {
            return viewModel.trigger(row, "", null)
        }
        return false
    }

    function triggerSystemAction(actionId: string): void {
        const m = modernMenu.systemModel
        if (!m) return
        for (let i = 0; i < m.rowCount(); i++) {
            const idx = m.index(i, 0)
            const id = String(m.data(idx, modernMenu.favoriteIdRole))
            if (id === String(actionId)) {
                m.trigger(i, "", null)
                return
            }
        }
    }

    function systemActionAvailable(actionId: string): bool {
        const m = modernMenu.systemModel
        if (!m) return false
        for (let i = 0; i < m.rowCount(); i++) {
            const idx = m.index(i, 0)
            const id = String(m.data(idx, modernMenu.favoriteIdRole))
            if (id === String(actionId)) {
                return true
            }
        }
        return false
    }

    // Deterministic hue for an app, used for its icon tile.
    function hashString(text: string): int {
        let h = 5381
        for (let i = 0; i < text.length; i++) {
            h = ((h << 5) + h + text.charCodeAt(i)) & 0x7fffffff
        }
        return h
    }

    function hueFor(model: var): real {
        const seed = (model && model.favoriteId) ? model.favoriteId
            : (model ? String(model.display) : "x")
        return (modernMenu.hashString(seed || "x") % 360) / 360.0
    }

    // ---------- Uninstall support ----------

    property string pendingUninstallId: ""
    property string pendingUninstallName: ""
    property string uninstallError: ""

    // ---------- Context menu (right click on an entry) ----------

    property var contextMenuTarget: null

    function openContextMenu(item: Item, viewModel: QObject, row: int, x: real, y: real): void {
        modernMenu.contextMenuTarget = {
            item: item,
            viewModel: viewModel,
            row: row,
        }
        appContextMenu.popup(item, x, y)
    }

    P5Support.DataSource {
        id: uninstallSource
        engine: "executable"
        connectedSources: []
        property string lastOutput: ""
        property int lastExitCode: 0

        onNewData: (sourceName, data) => {
            disconnectSource(sourceName)
            const stdout = data && data.stdout !== undefined ? String(data.stdout) : ""
            const stderr = data && data.stderr !== undefined ? String(data.stderr) : ""
            const exitCode = data && data["exit code"] !== undefined ? Number(data["exit code"]) : 0
            modernMenu.rootModel.refresh()
            if (exitCode !== 0 || stderr.trim().length > 0) {
                modernMenu.uninstallError = (stderr.trim().length > 0 ? stderr.trim()
                    : stdout.trim().length > 0 ? stdout.trim()
                    : i18nc("@info:status", "Uninstall failed (exit code %1).", exitCode))
                uninstallErrorDialog.open()
            }
        }
    }

    QQC2.Dialog {
        id: uninstallDialog

        modal: true
        title: i18nc("@title:dialog", "Uninstall")

        footer: QQC2.DialogButtonBox {
            QQC2.Button {
                text: i18nc("@action:button", "Cancel")
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.RejectRole
            }
            QQC2.Button {
                text: i18nc("@action:button", "Uninstall")
                highlighted: true
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.AcceptRole
            }
        }

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            PC3.Label {
                text: i18nc("@info:status", "Uninstall %1?", modernMenu.pendingUninstallName)
                font.weight: Font.DemiBold
            }
            PC3.Label {
                text: i18nc("@info:status", "System packages ask for administrator authentication. Flatpak apps are removed with flatpak.")
                wrapMode: Text.Wrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
                opacity: 0.75
            }
        }

        onAccepted: {
            const id = modernMenu.pendingUninstallId
            // strict allowlist; prevents shell injection via crafted desktop ids
            if (/^[A-Za-z0-9._-]+\.desktop$/.test(id)) {
                modernMenu.expanded = false
                const url = Qt.resolvedUrl("../scripts/uninstall").toString()
                const path = decodeURIComponent(url.replace(/^file:\/+/, ""))
                uninstallSource.connectSource("bash '" + path + "' '" + id + "'")
            }
        }
    }

    QQC2.Dialog {
        id: uninstallErrorDialog

        modal: true
        title: i18nc("@title:dialog", "Uninstall failed")

        footer: QQC2.DialogButtonBox {
            QQC2.Button {
                text: i18nc("@action:button", "Close")
                QQC2.DialogButtonBox.buttonRole: QQC2.DialogButtonBox.AcceptRole
            }
        }

        ColumnLayout {
            spacing: Kirigami.Units.smallSpacing

            PC3.Label {
                text: i18nc("@info:status", "Could not uninstall %1.", modernMenu.pendingUninstallName)
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            }
            PC3.Label {
                text: modernMenu.uninstallError
                wrapMode: Text.Wrap
                font: Kirigami.Theme.smallFont
                opacity: 0.85
                Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            }
        }
    }

    QQC2.Menu {
        id: appContextMenu

        QQC2.MenuItem {
            text: modernMenu.contextMenuTarget && modernMenu.contextMenuTarget.item
                ? (modernMenu.isFavorite(modernMenu.contextMenuTarget.item.model.favoriteId ?? "")
                    ? i18nc("@item:inmenu", "Remove from Favorites")
                    : i18nc("@item:inmenu", "Add to Favorites"))
                : i18nc("@item:inmenu", "Add to Favorites")
            icon.name: "starred-symbolic"
            enabled: modernMenu.contextMenuTarget && modernMenu.contextMenuTarget.item
                && modernMenu.contextMenuTarget.item.model
                && !!modernMenu.contextMenuTarget.item.model.favoriteId
            onTriggered: {
                const favoriteId = modernMenu.contextMenuTarget.item.model.favoriteId
                modernMenu.toggleFavorite(favoriteId)
            }
        }
        QQC2.MenuItem {
            text: i18nc("@item:inmenu", "Run")
            icon.name: "system-run-symbolic"
            enabled: modernMenu.contextMenuTarget !== null
            onTriggered: {
                const t = modernMenu.contextMenuTarget
                if (t && modernMenu.activate(t.viewModel, t.row)) {
                    modernMenu.expanded = false
                }
            }
        }
        QQC2.MenuItem {
            text: i18nc("@item:inmenu", "Uninstall…")
            icon.name: "edit-delete-remove-symbolic"
            enabled: modernMenu.contextMenuTarget && modernMenu.contextMenuTarget.item
                && modernMenu.contextMenuTarget.item.model
                && String(modernMenu.contextMenuTarget.item.model.favoriteId ?? "").endsWith(".desktop")
            onTriggered: {
                const m = modernMenu.contextMenuTarget.item.model
                modernMenu.pendingUninstallId = String(m.favoriteId)
                modernMenu.pendingUninstallName = String(m.display ?? m.favoriteId)
                uninstallDialog.open()
            }
        }
        QQC2.MenuItem {
            text: i18nc("@item:inmenu", "Edit Applications…")
            icon.name: "kmenuedit"
            onTriggered: processRunner.runMenuEditor()
        }
    }

    // ---------- Shared card delegates (grid + list) ----------

    Component {
        id: cardDelegateComponent

        Item {
            id: card
            required property var model
            required property int index
            property url url: ""
            property var decoration: ""
            property string description: ""

            readonly property var view: GridView.view
            readonly property bool isFavorite: modernMenu.isFavorite(model.favoriteId ?? "")
            readonly property real hue: modernMenu.hueFor(model)

            width: view ? view.cellWidth : Kirigami.Units.gridUnit * 12
            height: view ? view.cellHeight : Kirigami.Units.gridUnit * 4.4

            Accessible.role: Accessible.ListItem
            Accessible.name: model.display ?? ""

            Rectangle {
                id: cardBackground
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing / 2
                radius: Kirigami.Units.smallSpacing * 1.8
                color: mouseArea.containsMouse
                    ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.14)
                    : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.045)
                border.width: 1
                border.color: mouseArea.containsMouse
                    ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.45)
                    : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.09)
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.largeSpacing

                Rectangle {
                    id: iconTile
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                    Layout.preferredHeight: Kirigami.Units.iconSizes.large
                    radius: Kirigami.Units.smallSpacing * 1.8
                    color: Qt.hsla(card.hue, 0.55, 0.36, 1)

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: model.decoration ?? "application-x-executable"
                        width: Kirigami.Units.iconSizes.medium
                        height: Kirigami.Units.iconSizes.medium
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    PC3.Label {
                        Layout.fillWidth: true
                        text: model.display ?? ""
                        textFormat: Text.PlainText
                        font.pixelSize: Kirigami.Units.gridUnit * 0.78
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    PC3.Label {
                        Layout.fillWidth: true
                        text: model.description ?? ""
                        textFormat: Text.PlainText
                        font.pixelSize: Kirigami.Units.gridUnit * 0.62
                        color: Kirigami.Theme.textColor
                        opacity: 0.55
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        visible: text.length > 0
                    }
                }
            }

            PC3.ToolButton {
                id: starButton
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Kirigami.Units.smallSpacing / 2
                z: 2
                flat: true
                display: PC3.AbstractButton.IconOnly
                icon.name: card.isFavorite ? "starred-symbolic" : "non-starred-symbolic"
                icon.width: Kirigami.Units.iconSizes.small
                icon.height: Kirigami.Units.iconSizes.small
                icon.color: card.isFavorite ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                visible: !!model.favoriteId && (card.isFavorite || mouseArea.containsMouse)
                enabled: !!model.favoriteId

                PC3.ToolTip.text: card.isFavorite
                    ? i18nc("@info:tooltip", "Remove from Favorites")
                    : i18nc("@info:tooltip", "Add to Favorites")
                PC3.ToolTip.visible: hovered

                onClicked: modernMenu.toggleFavorite(model.favoriteId)
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        modernMenu.openContextMenu(card, card.view.model, index, mouse.x, mouse.y)
                    } else if (modernMenu.activate(card.view.model, index)) {
                        modernMenu.expanded = false
                    }
                }
            }
        }
    }

    Component {
        id: listDelegateComponent

        Item {
            id: row
            required property var model
            required property int index
            property url url: ""
            property var decoration: ""
            property string description: ""

            readonly property var view: ListView.view
            readonly property bool isFavorite: modernMenu.isFavorite(model.favoriteId ?? "")
            readonly property real hue: modernMenu.hueFor(model)

            width: view ? view.width : Kirigami.Units.gridUnit * 30
            height: Kirigami.Units.gridUnit * 3.5

            Accessible.role: Accessible.ListItem
            Accessible.name: model.display ?? ""

            Rectangle {
                id: rowBackground
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing / 3
                radius: Kirigami.Units.smallSpacing * 1.5
                color: mouseArea.containsMouse
                    ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.14)
                    : "transparent"
                border.width: 1
                border.color: mouseArea.containsMouse
                    ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.4)
                    : "transparent"
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing * 1.5
                spacing: Kirigami.Units.largeSpacing

                Rectangle {
                    id: rowTile
                    Layout.preferredWidth: Kirigami.Units.iconSizes.medium + 6
                    Layout.preferredHeight: Kirigami.Units.iconSizes.medium + 6
                    radius: Kirigami.Units.smallSpacing * 1.5
                    color: Qt.hsla(row.hue, 0.55, 0.36, 1)

                    Kirigami.Icon {
                        anchors.centerIn: parent
                        source: model.decoration ?? "application-x-executable"
                        width: Kirigami.Units.iconSizes.medium
                        height: Kirigami.Units.iconSizes.medium
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    PC3.Label {
                        Layout.fillWidth: true
                        text: model.display ?? ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    PC3.Label {
                        Layout.fillWidth: true
                        text: model.description ?? ""
                        textFormat: Text.PlainText
                        font: Kirigami.Theme.smallFont
                        opacity: 0.55
                        visible: text.length > 0 && text !== (model.display ?? "")
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }

                PC3.ToolButton {
                    id: starButton
                    z: 2
                    flat: true
                    display: PC3.AbstractButton.IconOnly
                    icon.name: row.isFavorite ? "starred-symbolic" : "non-starred-symbolic"
                    icon.width: Kirigami.Units.iconSizes.small
                    icon.height: Kirigami.Units.iconSizes.small
                    icon.color: row.isFavorite ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                    visible: !!model.favoriteId && (row.isFavorite || mouseArea.containsMouse)
                    enabled: !!model.favoriteId

                    PC3.ToolTip.text: row.isFavorite
                        ? i18nc("@info:tooltip", "Remove from Favorites")
                        : i18nc("@info:tooltip", "Add to Favorites")
                    PC3.ToolTip.visible: hovered

                    onClicked: modernMenu.toggleFavorite(model.favoriteId)
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        modernMenu.openContextMenu(row, row.view.model, index, mouse.x, mouse.y)
                    } else if (modernMenu.activate(row.view.model, index)) {
                        modernMenu.expanded = false
                    }
                }
            }
        }
    }

    // ---------- Views ----------

    Component {
        id: appGridComponent
        GridView {
            id: appGrid
            readonly property int columns: Math.max(1, Math.min(10, Plasmoid.configuration.gridColumns))
            readonly property int cardHeight: Math.max(56, Plasmoid.configuration.gridCellHeight)
            cellWidth: Math.floor(width / columns)
            cellHeight: cardHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            delegate: cardDelegateComponent
            focus: true
            Keys.onReturnPressed: {
                if (model && model.trigger(currentIndex, "", null)) {
                    modernMenu.expanded = false
                }
            }
        }
    }

    Component {
        id: appListComponent
        ListView {
            id: appList
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            delegate: listDelegateComponent
            focus: true
            Keys.onReturnPressed: {
                if (model && model.trigger(currentIndex, "", null)) {
                    modernMenu.expanded = false
                }
            }
        }
    }

    Component {
        id: searchListComponent
        ListView {
            id: searchList
            model: modernMenu.runnerModel.count > 0 ? modernMenu.runnerModel.modelForRow(0) : null
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            delegate: listDelegateComponent
            currentIndex: 0
            focus: true
            Keys.onEscapePressed: modernMenu.searchField ? modernMenu.searchField.clear() : modernMenu.expanded = false
            Keys.onReturnPressed: {
                if (modernMenu.runnerModel.count > 0 && modernMenu.activate(searchList.model, searchList.currentIndex)) {
                    modernMenu.expanded = false
                }
            }
        }
    }

    // ---------- Compact (panel) representation ----------

    compactRepresentation: MouseArea {
        id: compactRoot

        hoverEnabled: true
        Accessible.name: Plasmoid.title
        Accessible.role: Accessible.Button

        implicitWidth: Kirigami.Units.iconSizes.large
        implicitHeight: Kirigami.Units.iconSizes.large

        property bool wasExpanded

        onPressed: wasExpanded = modernMenu.expanded
        onClicked: modernMenu.expanded = !wasExpanded

        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            active: compactRoot.containsMouse
        }
    }

    // ---------- Full (popup) representation ----------

    fullRepresentation: Item {
        id: popup

        Layout.minimumWidth: Kirigami.Units.gridUnit * 38
        Layout.minimumHeight: Kirigami.Units.gridUnit * 30
        Layout.preferredWidth: Math.max(Layout.minimumWidth, Plasmoid.configuration.popupWidth)
        Layout.preferredHeight: Math.max(Layout.minimumHeight, Plasmoid.configuration.popupHeight)

        focus: true

        Component.onCompleted: modernMenu.rootModel.refresh()

        Connections {
            target: modernMenu
            function onExpandedChanged() {
                if (modernMenu.expanded) {
                    modernMenu.currentSection = 0
                    modernMenu.rootModel.refresh()
                    if (modernMenu.searchField) {
                        modernMenu.searchField.text = ""
                        modernMenu.searchField.forceActiveFocus()
                    }
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            // ==================== SIDEBAR ====================
            ColumnLayout {
                id: sidebar
                Layout.fillHeight: true
                Layout.preferredWidth: collapsed ? 54 : 150
                Layout.minimumWidth: collapsed ? 54 : 150
                Layout.maximumWidth: collapsed ? 54 : 150
                spacing: Kirigami.Units.smallSpacing / 2

                readonly property bool collapsed: Plasmoid.configuration.sidebarCollapsed

                PC3.ToolButton {
                    id: collapseButton
                    Layout.alignment: sidebar.collapsed ? Qt.AlignHCenter : Qt.AlignRight
                    flat: true
                    display: PC3.AbstractButton.IconOnly
                    icon.name: sidebar.collapsed ? "go-next-symbolic" : "go-previous-symbolic"
                    icon.width: Kirigami.Units.iconSizes.small
                    icon.height: Kirigami.Units.iconSizes.small
                    onClicked: Plasmoid.configuration.sidebarCollapsed = !sidebar.collapsed

                    PC3.ToolTip.text: sidebar.collapsed
                        ? i18nc("@info:tooltip", "Expand sidebar")
                        : i18nc("@info:tooltip", "Collapse sidebar to icons")
                    PC3.ToolTip.visible: hovered
                }

                component SidebarEntry : Rectangle {
                    id: sidebarEntry

                    property string iconName: ""
                    property string label: ""
                    property int section: 0

                    readonly property bool selected: modernMenu.currentSection === section

                    Layout.fillWidth: true
                    Layout.preferredHeight: sidebar.collapsed ? 42 : 36
                    radius: Kirigami.Units.smallSpacing * 1.4
                    color: selected
                        ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.16)
                        : "transparent"
                    border.width: selected ? 1 : 0
                    border.color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.35)

                    Rectangle {
                        // left accent bar for the selected entry
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 3
                        height: parent.height * 0.55
                        radius: 2
                        color: Kirigami.Theme.highlightColor
                        visible: sidebarEntry.selected
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: sidebar.collapsed ? 0 : Kirigami.Units.largeSpacing
                        anchors.rightMargin: sidebar.collapsed ? 0 : Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.largeSpacing

                        Kirigami.Icon {
                            source: sidebarEntry.iconName
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                            implicitWidth: Kirigami.Units.iconSizes.smallMedium
                            implicitHeight: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            color: sidebarEntry.selected ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
                        }
                        PC3.Label {
                            visible: !sidebar.collapsed
                            Layout.fillWidth: true
                            text: sidebarEntry.label
                            textFormat: Text.PlainText
                            font.pixelSize: Kirigami.Units.gridUnit * 0.72
                            font.weight: sidebarEntry.selected ? Font.Medium : Font.Normal
                            color: sidebarEntry.selected
                                ? Kirigami.Theme.textColor
                                : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.72)
                            elide: Text.ElideRight
                        }
                    }

                    TapHandler {
                        onTapped: {
                            modernMenu.currentSection = sidebarEntry.section
                            modernMenu.searchField.clear()
                        }
                    }

                    HoverHandler {
                        id: entryHoverHandler
                    }

                    PC3.ToolTip.text: sidebarEntry.label
                    PC3.ToolTip.visible: sidebar.collapsed && entryHoverHandler.hovered
                }

                SidebarEntry {
                    section: 1
                    iconName: "starred-symbolic"
                    label: i18nc("@item sidebar entry", "Favorites")
                }
                SidebarEntry {
                    section: 0
                    iconName: "view-app-grid-symbolic"
                    label: i18nc("@item sidebar entry", "All Apps")
                }
                SidebarEntry {
                    section: 2
                    iconName: "folder-symbolic"
                    label: i18nc("@item sidebar entry", "Places")
                }
                SidebarEntry {
                    section: 3
                    iconName: "computer-symbolic"
                    label: i18nc("@item sidebar entry", "System")
                }

                Item {
                    Layout.fillHeight: true
                }

                PC3.Label {
                    visible: !sidebar.collapsed
                    Layout.fillWidth: true
                    text: i18nc("@info small caps app signature", "MODERN MENU")
                    font.pixelSize: Kirigami.Units.gridUnit * 0.56
                    font.letterSpacing: 2
                    color: Kirigami.Theme.textColor
                    opacity: 0.35
                    leftPadding: Kirigami.Units.largeSpacing
                }
            }

            // ==================== MAIN COLUMN ====================
            ColumnLayout {
                id: main
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Kirigami.Units.smallSpacing * 1.5

                // ---- Search bar ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Rectangle {
                        id: searchBox

                        Layout.fillWidth: true
                        Layout.preferredHeight: Kirigami.Units.gridUnit * 2.35
                        radius: Kirigami.Units.smallSpacing * 1.6
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)
                        border.width: 1
                        border.color: searchField && searchField.activeFocus
                            ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.6)
                            : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.1)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Kirigami.Units.largeSpacing
                            anchors.rightMargin: Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.largeSpacing

                            Kirigami.Icon {
                                source: "edit-find-symbolic"
                                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                                color: Kirigami.Theme.highlightColor
                            }

                            PC3.TextField {
                                id: searchFieldImpl
                                Layout.fillWidth: true
                                focus: true
                                placeholderText: i18nc("@info:placeholder", "Type to search apps, files, actions…")
                                color: Kirigami.Theme.textColor
                                placeholderTextColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.38)
                                background: null
                                font.pixelSize: Kirigami.Units.gridUnit * 0.82
                                selectionColor: Kirigami.Theme.highlightColor
                                selectedTextColor: Kirigami.Theme.highlightedTextColor
                                selectByMouse: true

                                Keys.onReturnPressed: {
                                    if (text.length > 0 && modernMenu.runnerModel.count > 0) {
                                        if (modernMenu.activate(modernMenu.runnerModel.modelForRow(0), 0)) {
                                            modernMenu.expanded = false
                                        }
                                    }
                                }
                                Keys.onEscapePressed: {
                                    if (text.length > 0) {
                                        text = ""
                                    } else {
                                        modernMenu.expanded = false
                                    }
                                }
                                Keys.onDownPressed: {
                                    if (modernMenu.searching && contentLoader.item) {
                                        contentLoader.item.forceActiveFocus()
                                    }
                                }
                            }

                            Binding {
                                target: modernMenu
                                property: "searchField"
                                value: searchFieldImpl
                                restoreMode: Binding.RestoreBinding
                            }

                            component KbdBadge : Rectangle {
                                property string label: ""

                                Layout.preferredWidth: Kirigami.Units.gridUnit * 2.4
                                Layout.preferredHeight: Kirigami.Units.gridUnit * 1.25
                                radius: Kirigami.Units.smallSpacing * 0.9
                                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)
                                border.width: 1
                                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.14)

                                PC3.Label {
                                    anchors.centerIn: parent
                                    text: parent.label
                                    font.pixelSize: Kirigami.Units.gridUnit * 0.6
                                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.6)
                                }
                            }

                            KbdBadge {
                                label: i18nc("@label keyboard key", "Super")
                            }
                            KbdBadge {
                                label: i18nc("@label keyboard key", "Space")
                            }
                        }
                    }

                    PC3.ToolButton {
                        id: viewToggleButton
                        flat: true
                        display: PC3.AbstractButton.IconOnly
                        icon.name: modernMenu.viewMode === "grid" ? "view-list-text-symbolic" : "view-grid-symbolic"
                        icon.width: Kirigami.Units.iconSizes.smallMedium
                        icon.height: Kirigami.Units.iconSizes.smallMedium
                        onClicked: Plasmoid.configuration.viewMode = (Plasmoid.configuration.viewMode === 0 ? 1 : 0)

                        PC3.ToolTip.text: modernMenu.viewMode === "grid"
                            ? i18nc("@info:tooltip", "Switch to list view")
                            : i18nc("@info:tooltip", "Switch to grid view")
                        PC3.ToolTip.visible: hovered
                    }
                }

                // ---- Category tabs ----
                Rectangle {
                    id: tabsRow

                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 2.0
                    color: "transparent"
                    visible: !modernMenu.searching

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        component Tab : Rectangle {
                            id: tab

                            property string label: ""
                            property int section: 0

                            readonly property bool selected: modernMenu.currentSection === section

                            implicitWidth: tabLabel.implicitWidth + Kirigami.Units.gridUnit * 1.9
                            Layout.preferredWidth: implicitWidth
                            Layout.fillHeight: true
                            radius: Kirigami.Units.smallSpacing * 1.4
                            color: selected
                                ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.13)
                                : "transparent"
                            border.width: selected ? 1 : 0
                            border.color: Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.4)

                            PC3.Label {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: tab.label
                                font.pixelSize: Kirigami.Units.gridUnit * 0.75
                                font.weight: tab.selected ? Font.Medium : Font.Normal
                                color: tab.selected
                                    ? Kirigami.Theme.highlightColor
                                    : Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.6)
                            }

                            TapHandler {
                                onTapped: {
                                    modernMenu.currentSection = tab.section
                                    modernMenu.searchField.clear()
                                }
                            }
                        }

                        Tab {
                            label: i18nc("@item tab", "All")
                            section: 0
                        }
                        Tab {
                            label: i18nc("@item tab", "Apps")
                            section: 1
                        }
                        Tab {
                            label: i18nc("@item tab", "Files")
                            section: 2
                        }
                        Tab {
                            label: i18nc("@item tab", "Actions")
                            section: 3
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }

                // ---- Section header + count ----
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: -Kirigami.Units.smallSpacing / 2
                    visible: !modernMenu.searching

                    PC3.Label {
                        text: modernMenu.currentSectionTitle
                        font.pixelSize: Kirigami.Units.gridUnit * 0.62
                        font.letterSpacing: 1.6
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.48)
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    PC3.Label {
                        text: i18ncp("@info item count", "%1 item", "%1 items", modernMenu.currentSectionCount)
                        font.pixelSize: Kirigami.Units.gridUnit * 0.62
                        color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.42)
                    }
                }

                // ---- Content area ----
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Loader {
                        id: contentLoader
                        anchors.fill: parent
                        sourceComponent: {
                            if (modernMenu.searching) {
                                return searchListComponent
                            }
                            if (Plasmoid.configuration.viewMode === 0) {
                                return appGridComponent
                            }
                            return appListComponent
                        }
                        onLoaded: {
                            if (item && !modernMenu.searching) {
                                item.model = modernMenu.sectionModel
                            }
                        }
                        Binding {
                            target: contentLoader.item
                            property: "model"
                            value: modernMenu.sectionModel
                            when: !modernMenu.searching
                            restoreMode: Binding.RestoreBinding
                        }
                    }

                    PlasmaExtras.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.largeSpacing * 2
                        visible: !modernMenu.searching
                            && modernMenu.currentSection === 1
                            && modernMenu.rootModel.favoritesModel.count === 0
                        iconName: "starred-symbolic"
                        text: i18nc("@info:status", "No favorites yet")
                        explanation: i18nc("@info:status", "Star apps in All Apps to pin them here.")
                    }

                    PlasmaExtras.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.largeSpacing * 2
                        visible: !modernMenu.searching
                            && modernMenu.currentSection === 2
                            && modernMenu.computerModel.rowCount() === 0
                        iconName: "folder-symbolic"
                        text: i18nc("@info:status", "No places found")
                        explanation: i18nc("@info:status", "Home, Documents and other places should appear here.")
                    }

                    PlasmaExtras.PlaceholderMessage {
                        anchors.centerIn: parent
                        width: parent.width - Kirigami.Units.largeSpacing * 2
                        visible: modernMenu.searching && modernMenu.runnerModel.count === 0
                        iconName: "edit-none"
                        text: i18nc("@info:status", "No matches")
                        explanation: i18nc("@info:status", "Nothing matches “%1”.", searchField ? searchField.text : "")
                    }
                }

                // ---- Bottom bar: identity + power ----
                Rectangle {
                    id: bottomBar

                    Layout.fillWidth: true
                    Layout.preferredHeight: Kirigami.Units.gridUnit * 3.5
                    visible: modernMenu.showUserProfile || modernMenu.showPowerButtons
                    radius: Kirigami.Units.smallSpacing * 1.6
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.05)
                    border.width: 1
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.08)

                    P5Support.DataSource {
                        id: userNameSource
                        engine: "executable"
                        connectedSources: []
                        property string userName: ""
                        onNewData: (sourceName, data) => {
                            disconnectSource(sourceName)
                            userNameSource.userName = String(data.stdout || "").trim()
                        }
                    }

                    Component.onCompleted: userNameSource.connectSource("id -un")

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Kirigami.Units.largeSpacing
                        anchors.rightMargin: Kirigami.Units.largeSpacing
                        spacing: Kirigami.Units.largeSpacing

                        Item {
                            id: avatar

                            Layout.preferredWidth: Kirigami.Units.iconSizes.large
                            Layout.preferredHeight: Kirigami.Units.iconSizes.large
                            visible: modernMenu.showUserProfile

                            readonly property string initial: userNameSource.userName.length > 0
                                ? userNameSource.userName.charAt(0).toUpperCase()
                                : "?"

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: Qt.hsla(0.52, 0.62, 0.45, 1)

                                PC3.Label {
                                    anchors.centerIn: parent
                                    text: avatar.initial
                                    font.pixelSize: Kirigami.Units.gridUnit * 0.85
                                    font.bold: true
                                    color: "#ffffff"
                                }
                            }

                            Rectangle {
                                // presence dot
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 1
                                width: Kirigami.Units.gridUnit * 0.55
                                height: Kirigami.Units.gridUnit * 0.55
                                radius: width / 2
                                color: "#2ecc71"
                                border.width: 2
                                border.color: Kirigami.Theme.backgroundColor
                            }
                        }

                        ColumnLayout {
                            spacing: 0
                            visible: modernMenu.showUserProfile

                            PC3.Label {
                                text: userNameSource.userName.length > 0 ? userNameSource.userName : "…"
                                font.weight: Font.Medium
                                font.pixelSize: Kirigami.Units.gridUnit * 0.78
                            }
                            PC3.Label {
                                text: i18nc("@info session type", "Desktop Session")
                                font.pixelSize: Kirigami.Units.gridUnit * 0.62
                                opacity: 0.5
                            }
                        }

                        Item {
                            visible: !modernMenu.showUserProfile
                            Layout.fillWidth: true
                        }
                        Item {
                            Layout.fillWidth: true
                        }

                        // SystemModel is created here (inside the footer), not at
                        // applet root: it refreshes asynchronously via logind D-Bus
                        // and segfaults if built too early.
                        Kicker.SystemModel {
                            id: systemModel
                            favoritesModel: modernMenu.rootModel.systemFavoritesModel
                        }

                        Repeater {
                            model: modernMenu.showPowerButtons ? modernMenu.powerActions : []

                            delegate: PC3.ToolButton {
                                id: powerButton
                                required property var modelData

                                flat: true
                                display: PC3.AbstractButton.IconOnly
                                icon.name: modelData.icon
                                icon.width: Kirigami.Units.iconSizes.smallMedium
                                icon.height: Kirigami.Units.iconSizes.smallMedium
                                opacity: 0.75
                                visible: modernMenu.systemActionAvailable(modelData.actionId)
                                onClicked: modernMenu.triggerSystemAction(modelData.actionId)

                                PC3.ToolTip.text: modelData.name
                                PC3.ToolTip.visible: hovered
                            }
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        Plasmoid.activationTogglesExpanded = true
    }
}
