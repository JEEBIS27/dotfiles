"""Test the 1Password adapter without accessing real accounts or secrets."""
from pathlib import Path
import os
import pty
import select
import subprocess
import time
import unittest

ADAPTER = Path(__file__).resolve().parent.parent / 'files/tmux/1password-op.sh'
SETUP = '''
source "$1"
options::op_account() { printf '%s' "${TEST_ACCOUNT:-}"; }
options::op_valut() { :; }
options::op_filter_tags() { :; }
'''


class AdapterTests(unittest.TestCase):
    def shell(self, body, account=''):
        return subprocess.run(['bash', '-c', SETUP + body, 'test', str(ADAPTER)],
            env=dict(os.environ, TEST_ACCOUNT=account), text=True, capture_output=True)

    def test_default_account_is_selected_by_op(self):
        r = self.shell('op::run() { printf "<%s>\\n" "$@"; }; op::cli whoami')
        self.assertEqual(r.stdout, '<whoami>\n')

    def test_explicit_account_is_preserved(self):
        r = self.shell('op::run() { printf "<%s>\\n" "$@"; }; op::cli whoami', account='work')
        self.assertEqual(r.stdout, '<whoami>\n<--account=work>\n')

    def test_signin_precedes_whoami_and_outputs_no_token(self):
        r = self.shell('''
op::run() {
  echo "$1" >&2
  case $1 in signin) echo synthetic-token ;; whoami) echo authenticated ;; esac
}
op::verify_session
''')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stderr.splitlines(), ['signin', 'whoami'])
        self.assertEqual(r.stdout, '')

    def test_failed_signin_does_not_check_whoami(self):
        r = self.shell('''
op::run() { if [[ $1 == signin ]]; then return 1; fi; echo WHOAMI_CALLED; }
op::verify_session
''')
        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn('WHOAMI_CALLED', r.stdout + r.stderr)

    def test_failed_item_request_is_not_hidden_by_json_pipeline(self):
        for command in ['op::get_all_items', 'op::get_item_password fixture']:
            r = self.shell('op::run() { return 7; }; ' + command)
            self.assertIn(r.returncode, (4, 7), r.stderr)

    def test_item_list_parses_successful_response(self):
        r = self.shell('''
op::run() { printf '%s' '[{"title":"Fixture","id":"fixture-id"}]'; }
op::get_all_items
''')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout, 'Fixture,fixture-id\n')

    def test_auth_error_remains_visible_until_enter(self):
        master, slave = pty.openpty()
        proc = subprocess.Popen(['bash', '-c', SETUP + '''
op::run() { echo 'fixture authentication failed' >&2; return 1; }
op::verify_session
''', 'test', str(ADAPTER)], stdin=slave, stdout=slave, stderr=slave)
        os.close(slave)
        try:
            output = b''
            deadline = time.monotonic() + 5
            while b'Enter' not in output and time.monotonic() < deadline:
                if select.select([master], [], [], 0.2)[0]:
                    output += os.read(master, 65536)
            self.assertIn(b'fixture authentication failed', output)
            self.assertIn(b'Enter', output)
            self.assertIsNone(proc.poll())
            os.write(master, b'\n')
            self.assertEqual(proc.wait(timeout=3), 1)
        finally:
            if proc.poll() is None:
                proc.kill()
                proc.wait()
            os.close(master)


if __name__ == '__main__':
    unittest.main()
