/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasmoid

KCM.SimpleKCM {
    id: root

    property string cfg_icon: Plasmoid.configuration.icon
    property alias cfg_viewMode: viewModeCombo.currentIndex
    property alias cfg_popupWidth: widthSpin.value
    property alias cfg_popupHeight: heightSpin.value
    property alias cfg_enableFavorites: favoritesCheck.checked
    property alias cfg_showPowerButtons: powerCheck.checked
    property alias cfg_sidebarCollapsed: sidebarCheck.checked
    property alias cfg_showUserProfile: profileCheck.checked
    property alias cfg_webSearch: webSearchCheck.checked
    property alias cfg_gridColumns: columnsSpin.value
    property alias cfg_gridCellHeight: cellHeightSpin.value

    Kirigami.FormLayout {
        QQC2.TextField {
            id: iconField
            Kirigami.FormData.label: i18nc("@label:textbox", "Icon name:")
            placeholderText: "start-here-kde-symbolic"
            text: root.cfg_icon
            onTextChanged: root.cfg_icon = text.length > 0 ? text : "start-here-kde-symbolic"
        }

        QQC2.ComboBox {
            id: viewModeCombo
            Kirigami.FormData.label: i18nc("@label:listbox", "Default view:")
            model: [i18nc("@item:inlistbox", "Grid"), i18nc("@item:inlistbox", "List")]
        }

        QQC2.SpinBox {
            id: widthSpin
            Kirigami.FormData.label: i18nc("@label:spinbox", "Popup width (px):")
            from: 340
            to: 1600
            stepSize: 10
            editable: true
        }

        QQC2.SpinBox {
            id: heightSpin
            Kirigami.FormData.label: i18nc("@label:spinbox", "Popup height (px):")
            from: 360
            to: 1400
            stepSize: 10
            editable: true
        }

        QQC2.CheckBox {
            id: favoritesCheck
            Kirigami.FormData.label: i18nc("@label:checkbox", "Tabs:")
            text: i18nc("@option:check", "Show Favorites tab")
        }

        QQC2.CheckBox {
            id: powerCheck
            Kirigami.FormData.label: i18nc("@label:checkbox", "Power buttons:")
            text: i18nc("@option:check", "Enable power buttons")
        }
        QQC2.CheckBox {
            id: lockCheck
            text: i18nc("@option:check", "Lock screen")
            enabled: powerCheck.checked
        }
        QQC2.CheckBox {
            id: suspendCheck
            text: i18nc("@option:check", "Suspend")
            enabled: powerCheck.checked
        }
        QQC2.CheckBox {
            id: rebootCheck
            text: i18nc("@option:check", "Restart…")
            enabled: powerCheck.checked
        }
        QQC2.CheckBox {
            id: shutdownCheck
            text: i18nc("@option:check", "Shut down…")
            enabled: powerCheck.checked
        }

        QQC2.CheckBox {
            id: sidebarCheck
            text: i18nc("@option:check", "Collapse the sidebar to icons only")
        }

        QQC2.CheckBox {
            id: profileCheck
            text: i18nc("@option:check", "Show user profile (avatar and user name) in the bottom bar")
        }

        QQC2.CheckBox {
            id: webSearchCheck
            text: i18nc("@option:check", "Show web results (DuckDuckGo) when searching")
        }

        QQC2.SpinBox {
            id: columnsSpin
            Kirigami.FormData.label: i18nc("@label:spinbox", "Grid columns:")
            from: 1
            to: 8
            stepSize: 1
            editable: true
        }

        QQC2.SpinBox {
            id: cellHeightSpin
            Kirigami.FormData.label: i18nc("@label:spinbox", "Grid card height (px):")
            from: 56
            to: 200
            stepSize: 4
            editable: true
        }
    }
}
