"""Exercise the merge helper against real temporary Git repositories."""
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).with_name('sync-upstream.sh').resolve()


class UpstreamSyncTests(unittest.TestCase):
    def git(self, *args, cwd=None, check=True):
        return subprocess.run(['git', *args], cwd=cwd or self.work,
                              text=True, capture_output=True, check=check)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = pathlib.Path(self.temp.name)
        self.upstream, self.work = root / 'upstream.git', root / 'work'
        self.git('init', '--bare', '--initial-branch=main', str(self.upstream), cwd=root)
        self.git('clone', str(self.upstream), str(self.work), cwd=root)
        self.git('config', 'user.name', 'Sync test')
        self.git('config', 'user.email', 'sync-test@localhost')
        self.git('config', f'url.{self.upstream}.insteadOf', 'https://github.com/can1357/oh-my-pi.git')
        (self.work / 'state').write_text('base\n')
        self.git('add', '.'); self.git('commit', '-m', 'base'); self.git('push', 'origin', 'main')
        self.git('switch', '-c', 'android')
        (self.work / 'android-file').write_text('Android patch\n')
        self.git('add', '.'); self.git('commit', '-m', 'Android patch')

    def advance_upstream(self, conflict=False):
        self.git('switch', 'main')
        (self.work / ('state' if conflict else 'upstream-file')).write_text('upstream\n')
        self.git('add', '.'); self.git('commit', '-m', 'upstream update'); self.git('push', 'origin', 'main')
        self.git('switch', 'android')
        if conflict:
            (self.work / 'state').write_text('android\n')
            self.git('add', '.'); self.git('commit', '-m', 'conflicting Android patch')

    def run_sync(self, flag):
        return subprocess.run(['sh', str(SCRIPT), flag], cwd=self.work, text=True, capture_output=True)

    def test_clean_check_preserves_head_index_and_worktree(self):
        self.advance_upstream()
        before = self.git('rev-parse', 'HEAD').stdout
        result = self.run_sync('--check')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git('rev-parse', 'HEAD').stdout, before)
        self.assertEqual(self.git('status', '--porcelain').stdout, '')
        self.assertFalse((self.work / 'upstream-file').exists())

    def test_conflicting_check_leaves_the_android_branch_usable(self):
        self.advance_upstream(conflict=True)
        before = self.git('rev-parse', 'HEAD').stdout
        result = self.run_sync('--check')
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.git('rev-parse', 'HEAD').stdout, before)
        self.assertEqual(self.git('status', '--porcelain').stdout, '')
        self.assertFalse((self.work / '.git/MERGE_HEAD').exists())

    def test_apply_preserves_both_histories(self):
        self.advance_upstream()
        before = self.git('rev-parse', 'HEAD').stdout.strip()
        result = self.run_sync('--apply')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git('merge-base', '--is-ancestor', before, 'HEAD').returncode, 0)
        self.assertTrue((self.work / 'upstream-file').exists())
        self.assertTrue((self.work / 'android-file').exists())
        self.assertEqual(len(self.git('rev-list', '--parents', '-n1', 'HEAD').stdout.split()), 3)

    def test_dirty_apply_is_rejected_without_touching_local_edits(self):
        (self.work / 'state').write_text('local edit\n')
        self.assertEqual(self.run_sync('--apply').returncode, 2)
        self.assertEqual((self.work / 'state').read_text(), 'local edit\n')

    def test_apply_cannot_merge_into_the_upstream_reference_branch(self):
        self.git('switch', 'main')
        before = self.git('rev-parse', 'HEAD').stdout
        self.assertEqual(self.run_sync('--apply').returncode, 2)
        self.assertEqual(self.git('rev-parse', 'HEAD').stdout, before)
