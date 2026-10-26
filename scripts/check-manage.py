#!/usr/bin/env python3
"""Exercise installer routing with mocked commands; never activate the host."""
from pathlib import Path
import subprocess
import unittest

SCRIPT = Path(__file__).resolve().with_name('manage.sh')


class RoutingTests(unittest.TestCase):
    def run_manage(self, host, action, *, exists=True, pull_ok=True, setup_ok=True, desktop_markers=False):
        # These functions shadow only commands within this child Bash process.
        # The production script has no test-only host override or dry-run path.
        mocks = '''
repo='/tmp/dotfiles checkout'
is_android() { return ANDROID; }
is_nixos() { return NIXOS; }
is_omarchy() { return OMARCHY; }
require_host() { :; }
nixos_flake_exists() { return EXISTS; }
log() { printf '%s' "$1"; shift; printf ' <%s>' "$@"; printf '\\n'; }
nix() { log nix "$@"; [[ $NIX_CONFIG == *'extra-experimental-features = nix-command flakes'* ]]; }
nix-on-droid() { log nix-on-droid "$@"; }
git() { log git "$@"; return PULL; }
run_nixos() { log nixos "$@"; if [[ $1 == setup ]]; then return SETUP; fi; }
'''
        values = dict(ANDROID=int(host != 'android'), NIXOS=int(host != 'nixos' and not desktop_markers),
                      OMARCHY=int(host != 'omarchy' and not desktop_markers), EXISTS=int(not exists),
                      PULL=int(not pull_ok), SETUP=int(not setup_ok))
        for key, value in values.items():
            mocks = mocks.replace(key, str(value))
        return subprocess.run(['bash', '-c', 'source "$1"\n' + mocks + '\nmain "$2"',
                               'check-manage', str(SCRIPT), action],
                              text=True, capture_output=True)

    def test_omarchy_bootstraps_locked_home_manager(self):
        r = self.run_manage('omarchy', 'switch')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), 'nix <run> <path:/tmp/dotfiles checkout#home-manager> <--> <switch> <--flake> <path:/tmp/dotfiles checkout#jeebis@omarchy>')

    def test_android_switch_never_runs_pc_manager(self):
        r = self.run_manage('android', 'switch')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), 'nix-on-droid <switch> <--flake> <path:/tmp/dotfiles checkout#galaxy-tab-s11>')

    def test_android_wins_over_desktop_markers(self):
        r = self.run_manage('android', 'switch', desktop_markers=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(r.stdout.startswith('nix-on-droid '))
        self.assertNotIn('home-manager', r.stdout)

    def test_wrong_pc_checkout_is_rejected(self):
        shell = 'source "$1"; repo=/tmp/wrong-checkout; HOME=/home/jeebis; uname() { echo x86_64; }; id() { echo jeebis; }; require_host omarchy'
        r = subprocess.run(['bash', '-c', shell, 'check-manage', str(SCRIPT)], text=True, capture_output=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('/home/jeebis/Git/home-manager', r.stderr)

    def test_wrong_android_architecture_is_rejected(self):
        shell = 'source "$1"; uname() { echo x86_64; }; require_host android'
        r = subprocess.run(['bash', '-c', shell, 'check-manage', str(SCRIPT)], text=True, capture_output=True)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('aarch64', r.stderr)

    def test_android_build_does_not_activate(self):
        r = self.run_manage('android', 'build')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), 'nix <build> <path:/tmp/dotfiles checkout#nixOnDroidConfigurations.galaxy-tab-s11.activationPackage> <--no-link>')

    def test_nixos_first_switch_prepares_then_switches(self):
        r = self.run_manage('nixos', 'switch', exists=False)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.splitlines(), ['nixos <setup>', 'nixos <switch>'])

    def test_nixos_first_build_only_prepares_and_builds(self):
        r = self.run_manage('nixos', 'build', exists=False)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.splitlines(), ['nixos <setup>'])

    def test_existing_nixos_flake_is_not_replaced(self):
        r = self.run_manage('nixos', 'switch')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.splitlines(), ['nixos <switch>'])

    def test_setup_failure_prevents_switch(self):
        r = self.run_manage('nixos', 'switch', exists=False, setup_ok=False)
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(r.stdout.splitlines(), ['nixos <setup>'])

    def test_sync_pulls_before_applying(self):
        r = self.run_manage('android', 'sync')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.splitlines(), ['git <-C> </tmp/dotfiles checkout> <pull> <--ff-only>', 'nix-on-droid <switch> <--flake> <path:/tmp/dotfiles checkout#galaxy-tab-s11>'])

    def test_pull_failure_prevents_activation(self):
        r = self.run_manage('android', 'sync', pull_ok=False)
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(len(r.stdout.splitlines()), 1)
        self.assertTrue(r.stdout.startswith('git '))

    def test_unknown_os_fails_before_any_command(self):
        r = self.run_manage('unknown', 'switch')
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(r.stdout, '')

    def test_setup_is_nixos_only(self):
        r = self.run_manage('android', 'setup')
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(r.stdout, '')

    def test_host_is_read_only(self):
        r = self.run_manage('android', 'host')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), 'android')

    def test_unknown_action_is_rejected(self):
        r = self.run_manage('omarchy', 'bogus')
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(r.stdout, '')


if __name__ == '__main__':
    unittest.main()
