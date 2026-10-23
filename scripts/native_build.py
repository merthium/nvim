#!/usr/bin/env python3
"""Incremental CMake runner. No shell, downloads, installs, or implicit clean."""
import argparse
import fcntl
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

GIB = 1024**3


def job_limit(cpus, available, override):
    if override is not None:
        if not override.isdecimal() or not 1 <= int(override) <= 1024:
            raise ValueError('Job count must be an integer between 1 and 1024')
        return int(override)
    # Reserve memory for the editor/desktop/linker; template-heavy C++ may need
    # more per compiler. NVIM_BUILD_JOBS=1 explicitly selects serial builds.
    return max(1, min(cpus, max(0, available - 2 * GIB) // (1536 * 1024**2)))


def resources():
    cpus = len(os.sched_getaffinity(0)) if hasattr(os, 'sched_getaffinity') else (os.cpu_count() or 1)
    available = 4 * GIB
    try:
        for line in Path('/proc/meminfo').read_text().splitlines():
            if line.startswith('MemAvailable:'):
                available = int(line.split()[1]) * 1024
    except (OSError, ValueError):
        pass
    # Respect the current cgroup v2 limit when present.
    try:
        entry = next(line.split(':', 2)[2] for line in Path('/proc/self/cgroup').read_text().splitlines() if line.startswith('0::'))
        group = Path('/sys/fs/cgroup') / entry.lstrip('/')
        limit = (group/'memory.max').read_text().strip()
        if limit != 'max':
            available = min(available, max(0, int(limit) - int((group/'memory.current').read_text())))
        quota, period = (group/'cpu.max').read_text().split()
        if quota != 'max':
            cpus = min(cpus, max(1, int(quota) // int(period)))
    except (OSError, ValueError, StopIteration):
        pass
    return cpus, available


def read_cache(path):
    result = {}
    if path.exists():
        for line in path.read_text().splitlines():
            if not line.startswith(('#', '//')) and '=' in line and ':' in line.split('=', 1)[0]:
                key, value = line.split('=', 1)
                result[key.split(':', 1)[0]] = value
    return result


def execute(argv, root):
    print('+ ' + ' '.join(str(arg) for arg in argv), flush=True)
    subprocess.run([str(arg) for arg in argv], cwd=root, check=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--jobs', help='Explicit parallel limit; 1 means serial')
    parser.add_argument('action', choices=['build', 'run', 'test', 'check'])
    args = parser.parse_args(argv)
    root = args.root.resolve()
    if any(char in str(root) for char in (';', '\n', '\r')):
        raise ValueError('CMake does not support semicolons or newlines in this project path')
    build_dir = root/'build'
    if not (root/'CMakeLists.txt').is_file():
        raise ValueError('No CMakeLists.txt in ' + str(root))
    if build_dir.is_symlink() or (build_dir.exists() and not build_dir.is_dir()):
        raise ValueError('build must be a real directory inside the project, not a symlink')
    jobs = job_limit(*resources(), args.jobs or os.environ.get('NVIM_BUILD_JOBS') or os.environ.get('CMAKE_BUILD_PARALLEL_LEVEL'))
    cmake = shutil.which('cmake')
    if not cmake:
        raise ValueError('cmake is not installed')
    build_dir.mkdir(exist_ok=True)
    # One build per output directory; different projects can build independently.
    fd = os.open(build_dir/'.nvim-build.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise ValueError('Another build is using this directory; stop it or wait')
        cache_file = build_dir/'CMakeCache.txt'
        if cache_file.is_symlink():
            raise ValueError('CMakeCache.txt must not be a symlink')
        cache = read_cache(cache_file)
        if cache.get('CMAKE_HOME_DIRECTORY') and Path(cache['CMAKE_HOME_DIRECTORY']).resolve() != root:
            raise ValueError('CMake cache belongs to another project; use a separate build directory')
        configure = [cmake, '-S', root, '-B', build_dir]
        generator_file = 'build.ninja' if cache.get('CMAKE_GENERATOR', '').startswith('Ninja') else 'Makefile'
        needs_configure = not cache_file.exists() or not (build_dir/generator_file).exists()
        if not cache_file.exists():
            if shutil.which('ninja') and not os.environ.get('CMAKE_GENERATOR'):
                configure += ['-G', 'Ninja']
            configure += ['-DCMAKE_BUILD_TYPE=Debug']
        if cache.get('CMAKE_EXPORT_COMPILE_COMMANDS') not in ('ON', 'TRUE', '1'):
            configure += ['-DCMAKE_EXPORT_COMPILE_COMMANDS=ON']
            needs_configure = True
        ccache = shutil.which('ccache')
        if ccache:
            for lang in ('C', 'CXX'):
                key = 'CMAKE_' + lang + '_COMPILER_LAUNCHER'
                if key not in cache and key not in os.environ:
                    configure += ['-D' + key + '=' + ccache]
                    needs_configure = True
        print(f'Build: {jobs} jobs; incremental; compiler cache: {ccache or "not installed"}', flush=True)
        started = time.monotonic()
        if needs_configure:
            execute(configure, root)
        # Build tools track source/header/CMake dependencies and regenerate when needed.
        command = [cmake, '--build', build_dir, '--parallel', str(jobs)]
        if args.action == 'check':
            cache = read_cache(cache_file)
            generator = cache.get('CMAKE_GENERATOR', '')
            if generator not in ('Ninja', 'Unix Makefiles'):
                raise ValueError('Build preview only supports Ninja and Unix Makefiles')
            command += ['--', '-n']
        execute(command, root)
        print(f'Build elapsed: {time.monotonic()-started:.2f}s', flush=True)
        if args.action == 'test':
            execute(['ctest', '--test-dir', build_dir, '--output-on-failure', '--parallel', str(jobs)], root)
        elif args.action == 'run':
            program = build_dir/'app'
            if program.is_symlink() or not program.is_file():
                raise ValueError('Expected generated project executable build/app')
            # Release lock and replace the runner: stopping the task stops the program.
            fcntl.flock(lock, fcntl.LOCK_UN)
            os.chdir(root)
            os.execv(str(program), [str(program)])
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except subprocess.CalledProcessError as exc:
        sys.exit(exc.returncode if exc.returncode > 0 else 1)
    except (ValueError, OSError) as exc:
        print('Build error: ' + str(exc), file=sys.stderr)
        sys.exit(1)
    except KeyboardInterrupt:
        sys.exit(130)
