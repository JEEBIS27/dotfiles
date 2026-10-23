import QtQuick
import Quickshell.Io
import qs.Commons

QtObject {
  id: root
  property string raw: ""
  readonly property color warning: {
    var named = raw.match(/^\s*yellow\s*=\s*["']?(#[0-9a-fA-F]{6})/m)
    var ansi = raw.match(/^\s*color3\s*=\s*["']?(#[0-9a-fA-F]{6})/m)
    return named ? named[1] : ansi ? ansi[1] : Color.accent
  }
  readonly property color charging: {
    var named = raw.match(/^\s*green\s*=\s*["']?(#[0-9a-fA-F]{6})/m)
    var ansi = raw.match(/^\s*color2\s*=\s*["']?(#[0-9a-fA-F]{6})/m)
    return named ? named[1] : ansi ? ansi[1] : Color.accent
  }
  readonly property color critical: Color.urgent
  property FileView palette: FileView {
    path: Color.currentThemePath + "/colors.toml"
    watchChanges: true
    printErrors: false
    onLoaded: root.raw = text()
    onFileChanged: reload()
    onLoadFailed: root.raw = ""
  }
}
