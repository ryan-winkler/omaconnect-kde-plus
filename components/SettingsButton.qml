import QtQuick
import qs.Ui as Kit

// Keep native Omarchy styling and add an assistive-technology action.
Kit.Button {
    id: root
    // A frame makes each action read as a button, not as plain text.
    bordered: true
    Accessible.role: Accessible.Button
    Accessible.name: root.text
    Accessible.onPressAction: if (root.enabled) root.clicked()
}
