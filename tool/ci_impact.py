#!/usr/bin/env python3
"""Select work within stable SDK/compatibility CI statuses."""

import argparse
import fnmatch
import subprocess


def gates(files):
    all_gates = {'compat-minimum', 'compat-high', 'downgrade', 'demo', 'package'}
    if files is None:
        return all_gates
    selected = set()
    for path in files:
        if path.lower().endswith('.md'):
            continue
        if path in ('.github/workflows/dart.yml', 'tool/ci_impact.py'):
            return all_gates
        if any(fnmatch.fnmatchcase(path, pattern) for pattern in (
            'lib/**', 'test/**', 'example/**', 'pubspec.*',
            'analysis_options*', '.fvmrc', 'tool/validate.sh',
        )):
            selected.update(('compat-minimum', 'compat-high'))
        if any(fnmatch.fnmatchcase(path, pattern) for pattern in (
            'lib/**', 'pubspec.*', 'example/pubspec.*', 'analysis_options*',
        )):
            selected.add('downgrade')
        if any(fnmatch.fnmatchcase(path, pattern) for pattern in (
            'demo/**', 'lib/**', 'pubspec.yaml', '.fvmrc',
        )):
            selected.add('demo')
        if any(fnmatch.fnmatchcase(path, pattern) for pattern in (
            '.pubignore', 'pubspec.*', 'lib/**', 'test/assets/**', 'example/**',
            'analysis_options*',
        )):
            selected.add('package')
    return selected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gate', required=True, choices=(
        'compat-minimum', 'compat-high', 'downgrade', 'demo', 'package',
    ))
    parser.add_argument('--base')
    parser.add_argument('--files', nargs='*')
    args = parser.parse_args()
    files = args.files
    if files is None and args.base and set(args.base) != {'0'}:
        result = subprocess.run(
            ['git', 'diff', '--name-only', '-z', args.base + '..HEAD', '--'],
            check=True, capture_output=True, text=True,
        )
        files = [path for path in result.stdout.split('\0') if path]
    print('enabled=' + str(args.gate in gates(files)).lower())


if __name__ == '__main__':
    main()
