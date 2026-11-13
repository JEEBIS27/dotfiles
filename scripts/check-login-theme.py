#!/usr/bin/env python3
"""Render the built SDDM theme and exercise submission without authenticating.
Requires PySide6 (including QtQuick.VirtualKeyboard); argv[1] is the theme dir.
This does not test PAM, real login, or physical display rotation.
"""
import os
import sys
from pathlib import Path
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')
os.environ.setdefault('QT_QUICK_CONTROLS_STYLE', 'Basic')
os.environ.setdefault('GSETTINGS_BACKEND', 'memory')
os.environ.setdefault('QT_IM_MODULE', 'qtvirtualkeyboard')
from PySide6.QtCore import QAbstractListModel, QObject, Property, Qt, Signal, Slot, QUrl, QMetaObject, Q_ARG
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView
from PySide6.QtTest import QTest

class Model(QAbstractListModel):
    def __init__(self, names):
        super().__init__()
        self.names = names
    def rowCount(self, parent=None):
        return len(self.names)
    def roleNames(self):
        return {int(Qt.UserRole) + 1: b'name'}
    def data(self, index, role):
        if index.isValid() and role == int(Qt.UserRole) + 1:
            return self.names[index.row()]
    @Property(int, constant=True)
    def lastIndex(self):
        return 1

class Proxy(QObject):
    loginFailed = Signal()
    canPowerOff = Property(bool, lambda self: True, constant=True)
    canReboot = Property(bool, lambda self: True, constant=True)
    canSuspend = Property(bool, lambda self: True, constant=True)
    def __init__(self):
        super().__init__()
        self.calls = []
    @Slot(str, str, int)
    def login(self, user, password, session):
        self.calls.append((user, password, session))
    @Slot()
    def powerOff(self):
        raise AssertionError('Unexpected power action')
    @Slot()
    def reboot(self):
        raise AssertionError('Unexpected power action')
    @Slot()
    def suspend(self):
        raise AssertionError('Unexpected power action')

app = QGuiApplication(sys.argv)
proxy = Proxy()
users = Model(['other', 'jeebis'])
sessions = Model(['other', 'Hyprland (UWSM)'])
view = QQuickView()
view.setResizeMode(QQuickView.SizeRootObjectToView)
for name, value in [('sddm', proxy), ('userModel', users), ('sessionModel', sessions)]:
    view.rootContext().setContextProperty(name, value)
view.setSource(QUrl.fromLocalFile(str(Path(sys.argv[1], 'Main.qml').resolve())))
assert view.status() == QQuickView.Ready, view.errors()
view.resize(1920, 1200)
view.show()
QTest.qWait(1200)
root = view.rootObject()
password = root.findChild(QObject, 'passwordInput')
assert password is not None
assert root.findChild(QObject, 'loginUser').property('currentText') == 'jeebis'
assert root.findChild(QObject, 'loginSession').property('currentIndex') == 1
password.setProperty('text', 'test-only-not-a-real-password')
QTest.keyClick(view, Qt.Key_Return)
QTest.qWait(100)
assert proxy.calls == [('jeebis', 'test-only-not-a-real-password', 1)]
assert password.property('text') == ''
assert root.property('authenticating')
QMetaObject.invokeMethod(root, 'submit', Q_ARG(str, ''))
assert len(proxy.calls) == 1, 'Duplicate submission while busy'
proxy.loginFailed.emit()
QTest.qWait(100)
assert not root.property('authenticating') and password.property('enabled')
assert root.property('failureMessage')
# No theme-side password requirement: the daemon/PAM decides empty-password auth.
QMetaObject.invokeMethod(root, 'submit', Q_ARG(str, ''))
assert proxy.calls[-1] == ('jeebis', '', 1)
proxy.loginFailed.emit()
root.setProperty('failureMessage', '')
for width, height in [(1920, 1200), (1200, 1920)]:
    view.resize(width, height)
    QTest.qWait(300)
    assert root.findChild(QObject, 'clockCard') is not None
    assert root.findChild(QObject, 'profileCard') is not None
    assert password.property('width') <= width
    image = view.grabWindow()
    assert not image.isNull()
    if os.environ.get('JEEBIS_THEME_PREVIEW'):
        image.save(os.environ['JEEBIS_THEME_PREVIEW'] + f'-{width}x{height}.png')
print('QML loaded; landscape/portrait rendered; user/session selection, Enter, secret clearing, busy guard and failure retry passed.')
view.close()
