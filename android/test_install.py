"""Check installation and failed-update behavior using a local release fixture."""
import hashlib
import io
import os
import pathlib
import subprocess
import sys
import tarfile
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).with_name('install.sh').resolve()


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.bin, self.release, self.install = [self.root / name for name in ['bin', 'release', 'install']]
        for directory in [self.bin, self.release, self.install]: directory.mkdir()
        self.command('uname', '#!/bin/sh\necho aarch64\n')
        self.command('termux-info', '#!/bin/sh\nexit 0\n')
        self.command('getprop', '#!/bin/sh\necho 36\n')
        self.command('jq', '#!/bin/sh\ncat >/dev/null\necho android-test\n')
        self.command('curl', f'#!{sys.executable}\n' + '''import os, pathlib, shutil, sys
args = sys.argv[1:]
if '-o' in args:
    out = args[args.index('-o') + 1]
    url = next(x for x in args if x.startswith('https://'))
    shutil.copyfile(pathlib.Path(os.environ['OMP_TEST_RELEASE_DIR']) / url.rsplit('/', 1)[1], out)
else:
    print('{"tag_name":"android-test"}')
''')
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        PREFIX=str(self.root), OMP_ANDROID_INSTALL_DIR=str(self.install),
                        OMP_TEST_RELEASE_DIR=str(self.release))
        self.old = self.install / 'omp'
        self.old.write_text('old executable\n')

    def command(self, name, source):
        target = self.bin / name; target.write_text(source); target.chmod(0o755)

    def package(self, executable, extra=None):
        archive = self.release / 'omp-android-arm64.tar.gz'
        with tarfile.open(archive, 'w:gz') as tar:
            content = executable.encode()
            info = tarfile.TarInfo('omp'); info.size = len(content); info.mode = 0o755
            tar.addfile(info, io.BytesIO(content))
            if extra:
                info = tarfile.TarInfo(extra); info.size = 1; tar.addfile(info, io.BytesIO(b'x'))
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        (self.release / 'SHA256SUMS').write_text(f'{digest}  omp-android-arm64.tar.gz\n')

    def run_install(self):
        return subprocess.run(['sh', str(SCRIPT)], env=self.env, text=True, capture_output=True)

    def test_verified_executable_replaces_old_install(self):
        self.package('#!/bin/sh\necho android-test\n')
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(subprocess.check_output([str(self.old), '--version'], text=True).strip(), 'android-test')
        self.assertEqual(list(self.install.glob('.omp-android.*')), [])

    def test_checksum_mismatch_preserves_old_install(self):
        self.package('#!/bin/sh\nexit 0\n')
        with (self.release / 'omp-android-arm64.tar.gz').open('ab') as stream: stream.write(b'tampered')
        self.assertNotEqual(self.run_install().returncode, 0)
        self.assertEqual(self.old.read_text(), 'old executable\n')

    def test_startup_failure_preserves_old_install(self):
        self.package('#!/bin/sh\nexit 42\n')
        self.assertNotEqual(self.run_install().returncode, 0)
        self.assertEqual(self.old.read_text(), 'old executable\n')

    def test_archive_cannot_write_outside_staging(self):
        self.package('#!/bin/sh\nexit 0\n', '../escaped')
        self.assertNotEqual(self.run_install().returncode, 0)
        self.assertFalse((self.install / 'escaped').exists())
        self.assertEqual(self.old.read_text(), 'old executable\n')
