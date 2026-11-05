import QtQuick
import QtQuick.Window
import qs.Ui as Kit

// Keep native Omarchy styling and add an assistive-technology action.
Kit.Button {
    id: root
    // A frame makes each action read as a button, not as plain text.
    bordered: true
    Accessible.role: Accessible.Button
    Accessible.name: root.text
    // Cached accessibility nodes can outlive their view.
    readonly property bool actionAvailable: root.enabled && root.visible && !!root.Window.window && root.Window.window.visible
    Keys.enabled: root.actionAvailable
    Accessible.onPressAction: if (root.actionAvailable) root.clicked()
}
