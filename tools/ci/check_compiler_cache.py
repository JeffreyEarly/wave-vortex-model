#!/usr/bin/env python3
"""Exercise cache reuse and invalidation with the selected hosted compiler."""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile


def main():
    compiler = shutil.which({'release': 'g++', 'sanitized': 'clang++'}[os.environ['CONFIGURATION']])
    if not compiler or not shutil.which('ccache'):
        raise SystemExit('Compiler and ccache must be installed before cache validation')
    with tempfile.TemporaryDirectory(prefix='wvm-cache-contract-') as folder:
        root = Path(folder)
        calls = root / 'compiler-calls'
        wrapper = root / ('g++' if os.environ['CONFIGURATION'] == 'release' else 'clang++')
        wrapper.write_text('#!/bin/sh\nset -eu\ncompile=0\npreprocess=0\n'
                           'for arg in "$@"; do\n'
                           '  if [ "$arg" = -c ]; then compile=1; fi\n'
                           '  if [ "$arg" = -E ]; then preprocess=1; fi\n'
                           'done\n'
                           'if [ "$compile" = 1 ] && [ "$preprocess" = 0 ]; then\n'
                           "  printf 'compile\\n' >> " + shlex.quote(str(calls)) + '\nfi\n'
                           'exec ' + shlex.quote(compiler) + ' "$@"\n')
        wrapper.chmod(0o755)
        header = root / 'value.hpp'
        header.write_text('#define HEADER_VALUE 1\n')
        source = root / 'value.cpp'
        source.write_text('#include "value.hpp"\n#ifndef FLAG_VALUE\n#define FLAG_VALUE 0\n#endif\n'
                          'int value() { return HEADER_VALUE + FLAG_VALUE; }\n')
        driver = root / 'main.cpp'
        driver.write_text('int value(); int main() { return value(); }\n')
        environment = dict(os.environ, CCACHE_DIR=str(root/'cache'), CCACHE_COMPILERCHECK='content')
        object_file, executable = root/'value.o', root/'value'

        def count():
            return calls.read_text().count('compile\n') if calls.exists() else 0

        def compile_and_check(expected_value, expected_miss, flags=()):
            before = count()
            subprocess.run(['ccache', str(wrapper), *flags, '-c', str(source), '-o', str(object_file)],
                           env=environment, cwd=root, check=True)
            assert count() - before == int(expected_miss), 'Unexpected compiler cache hit/miss'
            subprocess.run([compiler, str(driver), str(object_file), '-o', str(executable)], check=True)
            assert subprocess.run([str(executable)]).returncode == expected_value, 'Stale compiler output'

        compile_and_check(1, True)
        compile_and_check(1, False)
        header.write_text('#define HEADER_VALUE 2\n')
        compile_and_check(2, True)
        flags = ('-DFLAG_VALUE=7',)
        compile_and_check(9, True, flags)
        source.write_text(source.read_text().replace('HEADER_VALUE + FLAG_VALUE;', 'HEADER_VALUE + FLAG_VALUE + 10;'))
        compile_and_check(19, True, flags)
        wrapper.write_text(wrapper.read_text() + '# compiler identity changes\n')
        compile_and_check(19, True, flags)
        (root/'unrelated-note.txt').write_text('Not a compilation dependency.\n')
        compile_and_check(19, False, flags)
    print('Compiler cache reuses identical inputs and invalidates source, header, flags and compiler changes.')


if __name__ == '__main__':
    main()
