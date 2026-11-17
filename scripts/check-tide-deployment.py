"""Check that a stale activation cannot remove a working Tide deployment."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parent.parent


class DeploymentTests(unittest.TestCase):
    def check_activation(self, marked, matching, removed):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            config = root/'config'
            state = root/'state'
            package = root/'tide'
            package.joinpath('share/tide-island').mkdir(parents=True)
            if marked:
                package.joinpath('share/tide-island/network-auth-version').write_text('1\n')
            unit = config/'systemd/user/tide-island.service'
            unit.parent.mkdir(parents=True)
            unit.write_text('ExecStart=' + (str(package) if matching else '/old-tide') + '/bin/tide-island\n')
            override = unit.parent/'tide-island.service.d/90-jeebis-wifi-deployment.conf'
            override.parent.mkdir()
            override.write_text('tested override')
            gcroot = state/'jeebis-desktop/tide-wifi-deployment'
            gcroot.parent.mkdir(parents=True)
            gcroot.symlink_to(package)
            source = (ROOT/'modules/desktop.nix').read_text()
            block = source.split('cleanupTideDeploymentOverride =', 1)[1].split("''", 2)[1]
            for token, value in {
                '${config.xdg.configHome}':str(config),
                '${config.xdg.stateHome}':str(state),
                '${tide}':str(package),
                '${pkgs.gnugrep}/bin/grep':'grep',
            }.items():block = block.replace(token, value)
            subprocess.run(['bash','-euc','run() { "$@"; }\n'+block],check=True)
            self.assertEqual(override.exists(), not removed)
            self.assertEqual(gcroot.exists(), not removed)

    def test_old_package_keeps_live_fix(self):self.check_activation(False, True, False)
    def test_stale_unit_keeps_live_fix(self):self.check_activation(True, False, False)
    def test_new_managed_unit_releases_pin(self):self.check_activation(True, True, True)


if __name__ == '__main__':unittest.main()
