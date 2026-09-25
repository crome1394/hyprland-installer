import QtQuick 2.2
import QtQuick.Layouts 1.2
import QtQuick.Controls 2.4

TextField {
    placeholderTextColor: config.color || "#ffffff"
    palette.text: config.color || "#ffffff"
    font.pointSize: config.fontSize || 10
    font.family: config.Font || config.font || "Noto Sans"
    width: parent.width
    background: Rectangle {
        color: parent.focus ? "#356a9f" : "#264d73"
        radius: 100
        opacity: 0.30
    }
}
