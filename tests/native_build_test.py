import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'scripts/native_build.py'
spec = importlib.util.spec_from_file_location('native_build', SCRIPT)
build = importlib.util.module_from_spec(spec)

class NativeBuildTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec.loader.exec_module(build)

    def test_jobs_bound_cpu_and_memory(self):
        self.assertEqual(build.job_limit(16, 6 * 1024**3, None), 2)
        self.assertEqual(build.job_limit(8, 32 * 1024**3, None), 8)
        self.assertEqual(build.job_limit(8, 512 * 1024**2, None), 1)
        self.assertEqual(build.job_limit(8, 32 * 1024**3, '1'), 1)
        for value in ['0', '-1', '8; touch bad', 'garbage']:
            with self.assertRaises(ValueError):
                build.job_limit(8, 32 * 1024**3, value)

    def test_incremental_build_and_failure_do_not_run_stale_program(self):
        with tempfile.TemporaryDirectory(prefix="native build's ") as tmp:
            root = Path(tmp)
            (root/'CMakeLists.txt').write_text('cmake_minimum_required(VERSION 3.16)\nproject(probe LANGUAGES CXX)\nadd_executable(app main.cpp helper.cpp)\n')
            (root/'main.cpp').write_text('#include <cstdio>\nint helper(); int main(){puts("RUN_OK"); return helper();}\n')
            (root/'helper.cpp').write_text('int helper(){return 0;}\n')
            def run(action='run', **extra):
                env = dict(os.environ, NVIM_BUILD_JOBS='2', **extra)
                return subprocess.run(['python3', str(SCRIPT), '--root', tmp, action], text=True, capture_output=True, env=env)
            first = run()
            self.assertEqual(first.returncode, 0, first.stdout+first.stderr)
            self.assertIn('RUN_OK', first.stdout)
            binary = root/'build/app'
            stamp = binary.stat().st_mtime_ns
            self.assertEqual(run().returncode, 0)
            self.assertEqual(binary.stat().st_mtime_ns, stamp, 'unchanged source should not rebuild')
            (root/'main.cpp').write_text('invalid C++ !')
            failed = run()
            self.assertNotEqual(failed.returncode, 0)
            self.assertNotIn('RUN_OK', failed.stdout)
            self.assertTrue((root/'build/compile_commands.json').is_file())

    def test_failed_configure_recovers_after_missing_source_is_added(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root/'CMakeLists.txt').write_text('cmake_minimum_required(VERSION 3.16)\nproject(probe LANGUAGES CXX)\nadd_executable(app missing.cpp)\n')
            cmd = ['python3', str(SCRIPT), '--root', tmp, 'build']
            self.assertNotEqual(subprocess.run(cmd, capture_output=True).returncode, 0)
            (root/'missing.cpp').write_text('int main(){return 0;}\n')
            result = subprocess.run(cmd, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stdout+result.stderr)

    def test_build_lock_rejects_overlapping_builds(self):
        import fcntl
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root/'CMakeLists.txt').write_text('cmake_minimum_required(VERSION 3.16)\n')
            (root/'build').mkdir()
            with (root/'build/.nvim-build.lock').open('w') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                result = subprocess.run(['python3', str(SCRIPT), '--root', tmp, 'build'], text=True, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('Another build', result.stderr)
                self.assertFalse((root/'build/CMakeCache.txt').exists())

    def test_external_build_symlink_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp, tempfile.TemporaryDirectory() as outside:
            root = Path(tmp)
            (root/'CMakeLists.txt').write_text('cmake_minimum_required(VERSION 3.16)\n')
            (root/'build').symlink_to(outside)
            result = subprocess.run(['python3', str(SCRIPT), '--root', tmp, 'build'], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(list(Path(outside).iterdir()), [])

if __name__ == '__main__':
    unittest.main()
