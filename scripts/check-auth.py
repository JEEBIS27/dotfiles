#!/usr/bin/env python3
"""Test authentication routing without reading real credentials or logging in."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent

class AuthTests(unittest.TestCase):
    def shell(self, body):
        return subprocess.run(['bash', '-c', 'source "$1"\n' + body, 'test', str(ROOT / 'auth.sh')], text=True, capture_output=True)

    def test_op_failure_never_runs_gh(self):
        r = self.shell('need() { :; }; op_cli() { return 1; }; gh() { echo GH_CALLED; }; main git op://vault/item/token')
        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn('GH_CALLED', r.stdout)

    def test_token_is_ephemeral_and_reference_is_saved(self):
        r = self.shell('''
need() { :; }
op_cli() { echo test-token; }
gh() { [[ $GH_TOKEN == test-token ]]; }
git() { printf '%s\\n' "$*"; }
main git op://vault/item/token
''')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('op://vault/item/token', r.stdout)
        self.assertIn('!git-credential-op', r.stdout)
        self.assertNotIn('test-token', r.stdout + r.stderr)

    def test_raw_token_is_rejected(self):
        r = self.shell('need() { :; }; main git accidental-secret')
        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn('accidental-secret', r.stdout + r.stderr)

    def test_gh_failure_does_not_fall_back_to_other_credentials(self):
        r = self.shell('need() { :; }; github_token() { return 1; }; gh() { echo GH_CALLED; }; main gh repo list')
        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn('GH_CALLED', r.stdout)

    def test_rclone_reconnect_preserves_existing_config(self):
        with tempfile.TemporaryDirectory() as d:
            r = self.shell(f'''
export XDG_CONFIG_HOME={d!r}
need() {{ :; }}
rclone() {{
  if [[ $3 == listremotes ]]; then echo gdrive:;
  elif [[ $3 == config && $4 == reconnect && $5 == gdrive: ]]; then
    touch "$XDG_CONFIG_HOME/rclone/rclone.conf"; echo RECONNECTED;
  else return 1; fi
}}
main rclone gdrive
''')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('RECONNECTED', r.stdout)

    def test_rclone_config_failure_does_not_open_setup(self):
        r = self.shell('need() { :; }; rclone() { if [[ $3 == listremotes ]]; then return 1; fi; echo SETUP_CALLED; }; main rclone gdrive')
        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn('SETUP_CALLED', r.stdout)

    def test_invalid_remote_is_rejected(self):
        r = self.shell('need() { :; }; rclone() { echo CALLED; }; main rclone wrong')
        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn('CALLED', r.stdout)

    def test_credential_helper_ignores_other_hosts_and_store(self):
        for operation, host in [('get', 'example.com'), ('store', 'github.com'), ('erase', 'github.com')]:
            r = subprocess.run(['bash', str(ROOT / 'git-credential-op.sh'), operation], input=f'protocol=https\nhost={host}\n\n', text=True, capture_output=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(r.stdout, '')

if __name__ == '__main__':
    unittest.main()
