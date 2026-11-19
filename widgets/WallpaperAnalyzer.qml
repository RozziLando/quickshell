import QtQuick
import qs.services

Canvas {
    id: root

    width: 64
    height: 36
    opacity: 0.01
    z: -1

    property string source: ""
    property var done: null

    function analyze(path, callback) {
        var url = Theme.fileUrl(path)
        if (source !== "" && source !== url) unloadImage(source)
        source = url
        done = callback
        if (isImageLoaded(url)) requestPaint()
        else loadImage(url)
    }

    function cancel() {
        if (source !== "") unloadImage(source)
        source = ""
        done = null
    }

    onImageLoaded: if (source !== "" && isImageLoaded(source)) requestPaint()

    onPaint: {
        if (source === "" || !isImageLoaded(source)) return
        var ctx = getContext("2d")
        ctx.reset()
        ctx.drawImage(source, 0, 0, width, height)
        var d = ctx.getImageData(0, 0, width, height).data
        unloadImage(source)
        source = ""
        var callback = done
        done = null
        if (callback) callback(d)
    }
}
