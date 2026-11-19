import QtQuick
import Quickshell.Widgets
import qs.services

ClippingRectangle {
    id: root

    property var wallpaper: ({})

    color: Theme.surface

    Image {
        id: thumbImage
        property bool fromThumb: !!root.wallpaper.hasThumb
        anchors.fill: parent
        source: root.wallpaper.path && root.width > 0 && root.height > 0
                ? Theme.fileUrl(fromThumb ? root.wallpaper.thumb : root.wallpaper.path) : ""
        readonly property int needW: Theme.px(root.width, thumbImage)
        readonly property int needH: Theme.px(root.height, thumbImage)
        sourceSize: fromThumb ? undefined : Qt.size(needW, needH)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        onStatusChanged: {
            if (status === Image.Error && fromThumb) {
                fromThumb = false
                return
            }
            if (status !== Image.Ready || !root.wallpaper.thumb) return
            if (fromThumb) {
                if (implicitWidth + 1 < needW || implicitHeight + 1 < needH)
                    fromThumb = false
                return
            }
            var file = root.wallpaper.thumb
            grabToImage(function (result) { result.saveToFile(file) }, Qt.size(needW, needH))
        }
    }
}
