import QtQuick
import qs.Ui as Kit

// Keep native Omarchy styling and add an assistive-technology action.
Kit.Button {
    id: root
    Accessible.role: Accessible.Button
    Accessible.name: root.text
    Accessible.onPressAction: if (root.enabled) root.clicked()
}
