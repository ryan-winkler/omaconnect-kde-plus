pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons

Column {
    id: root
    property string sectionId: ""
    property string title: ""
    property string description: ""
    property bool expanded: false
    signal toggleRequested()
    default property alias contentData: body.data
    width: parent ? parent.width : 0
    spacing: Style.space(6)
    SettingsButton {
        objectName: "section-toggle-" + root.sectionId
        width: parent.width
        height: Math.max(44, implicitHeight)
        // Section headings match the original OmaConnect: muted capitals, no frame.
        bordered: false
        text: root.title.toUpperCase()
        iconText: root.expanded ? "󰅀" : "󰅂"
        leftAlign: true
        fontSize: Style.font.caption
        foreground: Qt.darker(Commons.Color.popups.text, 1.4)
        focusable: true
        tooltipText: root.description
        Accessible.name: (root.expanded ? "Collapse " : "Expand ") + root.title
        Accessible.description: root.description
        Accessible.checkable: true
        Accessible.checked: root.expanded
        onClicked: root.toggleRequested()
    }
    Column {
        id: body
        width: parent.width
        spacing: Style.space(8)
        visible: root.expanded
    }
}
