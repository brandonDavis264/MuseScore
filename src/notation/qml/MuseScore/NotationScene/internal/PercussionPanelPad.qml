/*
 * SPDX-License-Identifier: GPL-3.0-only
 * MuseScore-Studio-CLA-applies
 *
 * MuseScore Studio
 * Music Composition & Notation
 *
 * Copyright (C) 2024 MuseScore Limited
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */
import QtQuick 2.15

import Muse.Ui 1.0
import Muse.UiComponents 1.0
import Muse.GraphicalEffects 1.0
import MuseScore.NotationScene 1.0

DropArea {
    id: root

    property var padModel: null

    property bool panelEnabled: false

    property int panelMode: -1
    property bool useNotationPreview: false
    property bool showEditOutline: false

    property alias totalBorderWidth: padLoader.anchors.margins
    property alias showOriginBackground: originBackground.visible
    property alias draggableArea: draggableArea

    property int navigationRow: -1
    property int navigationColumn: -1
    property alias padNavigation: padNavCtrl
    property alias footerNavigation: footerNavCtrl

    readonly property bool hasActiveControl: padNavCtrl.active || footerNavCtrl.active

    property var dragParent: null
    signal dragStarted()
    signal dragCancelled()

    QtObject {
        id: prv
        readonly property color enabledBackgroundColor: Utils.colorWithAlpha(ui.theme.buttonColor, ui.theme.buttonOpacityNormal)
        readonly property color disabledBackgroundColor: Utils.colorWithAlpha(ui.theme.buttonColor, ui.theme.itemOpacityDisabled)
        readonly property real footerHeight: 24
        readonly property string accessibleDescription: {
            //: %1 will be the row number of a percussion panel pad
            let line1 = qsTrc("notation", "Row: %1").arg(root.navigationRow + 1)

            //: %1 will be the column number of a percussion panel pad
            let line2 = qsTrc("notation", "Column: %1").arg(root.navigationColumn + 1)

            return line1 + ", " + line2
        }
    }

    NavigationControl {
        id: padNavCtrl

        row: root.navigationRow
        column: root.navigationColumn

        name: root.objectName !== "" ? root.objectName : "PercussionPanelPad"

        // Only navigate to empty slots when we're in edit mode
        enabled: Boolean(root.padModel) || root.panelMode === PanelMode.EDIT_LAYOUT

        accessible.role: MUAccessible.Button
        accessible.name: Boolean(root.padModel) ? root.padModel.instrumentName : qsTrc("notation", "Empty pad")

        accessible.description: prv.accessibleDescription

        accessible.visualItem: padFocusBorder
        accessible.enabled: padNavCtrl.enabled

        onTriggered: {
            if (!Boolean(root.padModel)) {
                return
            }
            root.padModel.triggerPad()
        }
    }

    NavigationControl {
        id: footerNavCtrl

        row: root.navigationRow
        column: root.navigationColumn

        name: root.objectName !== "" ? root.objectName : "PercussionPanelPadFooter"

        enabled: Boolean(root.padModel)

        accessible.role: MUAccessible.Button
        accessible.name: Boolean(root.padModel) ? root.padModel.instrumentName + " " + qsTrc("notation", "footer") : ""

        accessible.description: prv.accessibleDescription

        accessible.visualItem: footerFocusBorder
        accessible.enabled: footerNavCtrl.enabled

        onTriggered: {
            // TODO: trigger context menu (not yet implemented)
        }
    }

    Rectangle {
        id: draggableArea

        // Protrudes slightly from behind the components in the loader to produce the edit mode "border with gap" effect
        width: root.width
        height: root.height

        radius: root.width / 6

        color: ui.theme.backgroundPrimaryColor

        border.color: root.showEditOutline ? ui.theme.accentColor : "transparent"
        border.width: 2

        DragHandler {
            id: dragHandler

            target: draggableArea
            enabled: Boolean(root.padModel) && root.panelMode === PanelMode.EDIT_LAYOUT

            dragThreshold: 0 // prevents the flickable from stealing drag events

            onActiveChanged: {
                if (dragHandler.active) {
                    root.dragStarted()
                    return
                }
                if (!draggableArea.Drag.drop()) {
                    root.dragCancelled()
                }
            }
        }

        Drag.active: dragHandler.active
        Drag.hotSpot.x: root.width / 2
        Drag.hotSpot.y: root.height / 2

        Loader {
            // Loads either an empty slot or the pad content
            id: padLoader

            anchors.fill: parent
            // Defined as 1 in the spec, but causes some aliasing in practice...
            anchors.margins: 2 + draggableArea.border.width

            // Can't simply use clip as this won't take into account radius...
            layer.enabled: ui.isEffectsAllowed
            layer.effect: EffectOpacityMask {
                maskSource: Rectangle {
                    width: padLoader.width
                    height: padLoader.height
                    radius: draggableArea.radius - padLoader.anchors.margins
                }
            }

            sourceComponent: Boolean(root.padModel) ? padContentComponent : emptySlotComponent

            Component {
                id: padContentComponent

                PercussionPanelPadContent {
                    padModel: root.padModel
                    panelMode: root.panelMode
                    useNotationPreview: root.useNotationPreview

                    footerHeight: prv.footerHeight

                    dragActive: dragHandler.active
                }
            }

            Component {
                id: emptySlotComponent

                Rectangle {
                    id: emptySlotBackground
                    color: root.panelEnabled ? prv.enabledBackgroundColor : prv.disabledBackgroundColor
                }
            }
        }

        NavigationFocusBorder {
            id: padFocusBorder

            padding: root.panelMode === PanelMode.EDIT_LAYOUT ? 0 : root.totalBorderWidth * -1
            navigationCtrl: padNavCtrl
        }

        NavigationFocusBorder {
            id: footerFocusBorder

            anchors {
                fill: null

                left: padLoader.left
                right: padLoader.right
                bottom: padLoader.bottom
            }

            height: prv.footerHeight + root.totalBorderWidth
            radius: 0

            navigationCtrl: footerNavCtrl
        }

        states: [
            State {
                name: "DRAGGED"
                when: dragHandler.active
                ParentChange {
                    target: draggableArea
                    parent: root.dragParent
                }
                AnchorChanges {
                    target: draggableArea
                    anchors.horizontalCenter: undefined
                    anchors.verticalCenter: undefined
                }
            },
            //! NOTE: Workaround for a bug in Qt 6.2.4 - see PR #24106 comment
            // https://bugreports.qt.io/browse/QTBUG-99436
            State {
                name: "DROPPED"
                when: !dragHandler.active
                ParentChange {
                    target: draggableArea
                    parent: root
                }
            }
        ]
    }

    Rectangle {
        id: originBackground

        anchors.fill: parent

        radius: draggableArea.radius

        border.color: draggableArea.border.color
        border.width: draggableArea.border.width

        color: draggableArea.color

        Rectangle {
            id: originBackgroundFill

            anchors.fill: parent
            anchors.margins: padLoader.anchors.margins
            radius: draggableArea.radius - originBackgroundFill.anchors.margins

            color: root.containsDrag ? ui.theme.buttonColor : prv.enabledBackgroundColor
        }
    }
}
