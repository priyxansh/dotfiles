import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope { // Scope
    id: root
    property bool pinned: Config.options?.osk.pinnedOnStartup ?? false

    component OskControlButton: GroupButton { // Pin button
        baseWidth: 40
        baseHeight: 40
        clickedWidth: baseWidth
        clickedHeight: baseHeight + 10
        buttonRadius: Appearance.rounding.normal
    }

    Loader {
        id: oskLoader
        active: GlobalStates.oskOpen
        onActiveChanged: {
            if (!oskLoader.active) {
                Ydotool.releaseAllKeys();
            }
        }
        
        sourceComponent: PanelWindow { // Window
            id: oskRoot
            visible: oskLoader.active && !GlobalStates.screenLocked

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            function hide() {
                GlobalStates.oskOpen = false
            }
            exclusiveZone: 0
            implicitWidth: Screen.width
            implicitHeight: Screen.height
            WlrLayershell.namespace: "quickshell:osk"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"

            mask: Region {
                item: oskBackground
            }

            // Background
            StyledRectangularShadow {
                target: oskBackground
            }
            Rectangle {
                id: oskBackground
                // Initial position: bottom-center
                x: (oskRoot.width - width) / 2
                y: oskRoot.height - height - 10
                color: Appearance.colors.colLayer0
                radius: Appearance.rounding.windowRounding
                property real padding: 10
                implicitWidth: oskRowLayout.implicitWidth + padding * 2
                implicitHeight: oskRowLayout.implicitHeight + padding * 2

                Keys.onPressed: (event) => { // Esc to close
                    if (event.key === Qt.Key_Escape) {
                        oskRoot.hide()
                    }
                }

                // Drag handler for the entire keyboard
                MouseArea {
                    id: dragArea
                    anchors.fill: parent
                    property real startX: 0
                    property real startY: 0
                    property real startMouseX: 0
                    property real startMouseY: 0
                    property bool dragging: false

                    // Let child buttons handle clicks; only drag on press+move
                    onPressed: (mouse) => {
                        startX = oskBackground.x;
                        startY = oskBackground.y;
                        startMouseX = mouse.x;
                        startMouseY = mouse.y;
                        dragging = false;
                    }
                    onPositionChanged: (mouse) => {
                        let dx = mouse.x - startMouseX;
                        let dy = mouse.y - startMouseY;
                        if (!dragging && Math.abs(dx) + Math.abs(dy) > 5) {
                            dragging = true;
                        }
                        if (dragging) {
                            oskBackground.x = Math.max(0, Math.min(oskRoot.width - oskBackground.width, startX + dx));
                            oskBackground.y = Math.max(0, Math.min(oskRoot.height - oskBackground.height, startY + dy));
                        }
                    }
                    onReleased: {
                        if (!dragging) {
                            // Was a click, not a drag — do nothing, let it propagate
                        }
                        dragging = false;
                    }
                    // Don't block child mouse events when not dragging
                    z: -1
                }

                RowLayout {
                    id: oskRowLayout
                    anchors.centerIn: parent
                    spacing: 5

                    // Drag handle area
                    VerticalButtonGroup {
                        MouseArea {
                            anchors.fill: parent
                            property real startX: 0
                            property real startY: 0
                            property real startMouseX: 0
                            property real startMouseY: 0

                            cursorShape: Qt.SizeAllCursor
                            onPressed: (mouse) => {
                                startX = oskBackground.x;
                                startY = oskBackground.y;
                                startMouseX = mapToItem(oskRoot.contentItem, mouse.x, mouse.y).x;
                                startMouseY = mapToItem(oskRoot.contentItem, mouse.x, mouse.y).y;
                            }
                            onPositionChanged: (mouse) => {
                                let mapped = mapToItem(oskRoot.contentItem, mouse.x, mouse.y);
                                let dx = mapped.x - startMouseX;
                                let dy = mapped.y - startMouseY;
                                oskBackground.x = Math.max(0, Math.min(oskRoot.width - oskBackground.width, startX + dx));
                                oskBackground.y = Math.max(0, Math.min(oskRoot.height - oskBackground.height, startY + dy));
                            }
                        }

                        OskControlButton { // Pin button
                            toggled: root.pinned
                            downAction: () => root.pinned = !root.pinned
                            contentItem: MaterialSymbol {
                                text: "keep"
                                horizontalAlignment: Text.AlignHCenter
                                iconSize: Appearance.font.pixelSize.larger
                                color: root.pinned ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
                            }
                        }
                        OskControlButton {
                            onClicked: () => {
                                oskRoot.hide()
                            }
                            contentItem: MaterialSymbol {
                                horizontalAlignment: Text.AlignHCenter
                                text: "keyboard_hide"
                                iconSize: Appearance.font.pixelSize.larger
                            }
                        }
                        OskControlButton {
                            contentItem: MaterialSymbol {
                                horizontalAlignment: Text.AlignHCenter
                                text: "drag_indicator"
                                iconSize: Appearance.font.pixelSize.larger
                            }
                        }
                    }
                    Rectangle {
                        Layout.topMargin: 20
                        Layout.bottomMargin: 20
                        Layout.fillHeight: true
                        implicitWidth: 1
                        color: Appearance.colors.colOutlineVariant
                    }
                    OskContent {
                        id: oskContent
                        Layout.fillWidth: true
                    }
                }
            }

        }
    }

    IpcHandler {
        target: "osk"

        function toggle(): void {
            GlobalStates.oskOpen = !GlobalStates.oskOpen;
        }

        function close(): void {
            GlobalStates.oskOpen = false
        }

        function open(): void {
            GlobalStates.oskOpen = true
        }
    }

    GlobalShortcut {
        name: "oskToggle"
        description: "Toggles on screen keyboard on press"

        onPressed: {
            GlobalStates.oskOpen = !GlobalStates.oskOpen;
        }
    }

    GlobalShortcut {
        name: "oskOpen"
        description: "Opens on screen keyboard on press"

        onPressed: {
            GlobalStates.oskOpen = true
        }
    }

    GlobalShortcut {
        name: "oskClose"
        description: "Closes on screen keyboard on press"

        onPressed: {
            GlobalStates.oskOpen = false
        }
    }

}
