pragma Singleton
import QtQuick

QtObject {
    readonly property string errorString: backend.errorString
    property var pending: ({})
    property var pendingLock: ({})

    function value(key, fallback) {
        return pending[key] ?? backend.userConfig[key] ?? fallback
    }

    function setValue(key, value) { pending[key] = value }
    function setLockValue(key, value) { pendingLock[key] = value }
    function save() {
        if (!backend.save(pending, pendingLock)) return false
        pending = ({})
        pendingLock = ({})
        return true
    }
}
