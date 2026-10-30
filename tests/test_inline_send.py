"""Daily inline review and bar hover. Real components, private providers only."""
import json
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class InlineSendTests(unittest.TestCase):
    def test_native_inline_review_and_bar_hover_preserve_explicit_send(self):
        runner=native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture='inline_send_ui.qml'
        runner.force_offscreen=True

        def configure(fixture,plugin,home,fake_bin):
            # Isolate the bar's panel handoff from its separately tested host UI.
            (plugin/'Panel.qml').write_text('''import QtQuick
Item {
 objectName: "fake-hover-panel"
 property bool opened: false
 property int hoverOpens: 0
 property var settings: ({})
 function openDropTarget(){hoverOpens++;opened=true}
 function open(){opened=true}
 function close(){opened=false}
 function openSendWindow(){}
}
''')

        def checked(fixture,home,output,calls):
            self.assertIn('INLINE_SEND_PASS',output)
            self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()),[{'multiple':True,'directory':False}])
            self.assertTrue(all(row['tool'] in ('fc-match','hyprctl','dbus-monitor') for row in calls),calls)
            self.assertEqual((fixture/'one').read_bytes(),b'abc')
            self.assertEqual((fixture/'two').read_bytes(),b'defg')

        runner.configure_fixture=configure
        runner.assert_fixture=checked
        runner.test_actual_service_bar_panel_and_controls()


if __name__=='__main__':unittest.main()
