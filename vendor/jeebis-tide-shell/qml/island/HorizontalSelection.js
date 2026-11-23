function key(event) {
    const modified = event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
    const k = event.key;
    if (k === Qt.Key_Up || k === (modified ? Qt.Key_@mod:K@ : Qt.Key_@plain:K@)
            || k === (modified ? Qt.Key_@mod:H@ : Qt.Key_@plain:H@))
        return Qt.Key_Left;
    if (k === Qt.Key_Down || k === (modified ? Qt.Key_@mod:J@ : Qt.Key_@plain:J@)
            || k === (modified ? Qt.Key_@mod:L@ : Qt.Key_@plain:L@))
        return Qt.Key_Right;
    return k;
}
