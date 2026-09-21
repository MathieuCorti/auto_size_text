#!/usr/bin/env python3
"""Portable local policy, skill, import-boundary and impact checks (stdlib only)."""

import argparse
import fnmatch
import json
import re
import subprocess
import sys
from pathlib import Path


def matches(path, patterns):
    return any(fnmatch.fnmatchcase(path, pattern) for pattern in patterns)


def read_config(root):
    path = root / '.gtm/quality.json'
    config = json.loads(path.read_text())
    if config.get('schemaVersion') != 1:
        raise ValueError('quality.json schemaVersion must be 1')
    profiles = ('flutter-app-cubit', 'flutter-app-riverpod',
                'flutter-widget-library', 'flutter-plugin', 'platform')
    if config.get('profile') not in profiles:
        raise ValueError('quality.json profile is not supported')
    roots = config.get('packageRoots')
    if not isinstance(roots, list) or (not roots and not config.get('foundationOnly')):
        raise ValueError('quality.json needs packageRoots (or an explicit foundationOnly placeholder)')
    if config.get('foundationOnly'):
        if roots:
            raise ValueError('foundationOnly requires empty packageRoots')
        if any(p.endswith('pubspec.yaml') or p.startswith('lib/') and p.endswith('.dart')
               for p in tracked_and_new_files(root)):
            raise ValueError('This foundation-only branch now contains code: register packageRoots and remove foundationOnly before validation')
    for package in roots:
        local = (root / package).resolve()
        if not local.is_relative_to(root.resolve()):
            raise ValueError('packageRoots must stay inside the repository')
        if not (local / 'pubspec.yaml').is_file():
            raise ValueError('package root has no pubspec.yaml: ' + package)
    for exception in config.get('boundaryExceptions', []):
        if not all(isinstance(exception.get(key), str) and exception[key].strip()
                   for key in ('file', 'import', 'rule', 'reason')):
            raise ValueError('boundaryExceptions need file, import, rule, and reason')
        if any('*' in exception[key] for key in ('file', 'import', 'rule')):
            raise ValueError('boundaryExceptions must identify one exact import')
    return config


def validate_skills(directory):
    errors = []
    if not directory.is_dir():
        return [str(directory) + ': missing local skills directory']
    for skill in sorted(directory.iterdir()):
        if not skill.is_dir():
            continue
        if skill.is_symlink():
            errors.append(str(skill) + ': skill must be a real local directory')
            continue
        main = skill / 'SKILL.md'
        if not main.is_file():
            errors.append(str(main) + ': missing skill entry point')
            continue
        content = main.read_text()
        frontmatter = re.match(r'\A---\s*\n(.*?)\n---\s*(?:\n|$)', content, re.S)
        if not frontmatter:
            errors.append(str(main) + ': missing YAML frontmatter')
        else:
            for key in ('name', 'description'):
                if not re.search(r'^' + key + r':\s*\S', frontmatter[1], re.M):
                    errors.append(str(main) + ': missing frontmatter ' + key)
        for file in skill.rglob('*'):
            if file.is_symlink():
                errors.append(str(file) + ': external or linked skill files are not portable')
            if file.suffix != '.md' or not file.is_file():
                continue
            text = file.read_text()
            if re.search(r'(?:/Users/[^/\s]+/|/home/[^/\s]+/|~/(?:\.codex|\.agents)/skills)', text):
                errors.append(str(file) + ': personal/global skill path must be portable')
            for target in re.findall(r'\[[^\]]*\]\(([^)]+)\)', text):
                target = target.split('#')[0].strip('<>')
                if not target or re.match(r'[a-z]+:', target):
                    continue
                if not (file.parent / target).exists():
                    errors.append(str(file) + ': missing reference ' + target)
    return errors


def tracked_and_new_files(root):
    result = subprocess.run(['git', '-C', str(root), 'ls-files', '-co',
                             '--exclude-standard', '-z'], capture_output=True)
    if result.returncode == 0:
        return sorted(set(p for p in result.stdout.decode().split('\0') if p))
    ignored = {'.git', '.dart_tool', '.fvm', 'build', 'node_modules', 'Pods'}
    return [str(p.relative_to(root)) for p in root.rglob('*')
            if p.is_file() and not ignored.intersection(p.relative_to(root).parts)]


def check_no_visual_baselines(root, files):
    errors = []
    assertion = re.compile(r'\b(?:matchesGoldenFile|screenMatchesGolden|multiScreenGolden|'
                           r'testGoldens|matchesReferenceImage)\s*\(|package:golden_toolkit/')
    for name in files:
        path = root / name
        if not path.is_file():
            continue
        if path.suffix.lower() in ('.png', '.jpg', '.webp') and re.search(
                r'(?:^|/)(?:goldens?|baselines?|snapshots?)(?:/|\.)', name, re.I):
            errors.append(name + ': stored visual comparison baseline is prohibited')
        if name.endswith('.dart') and ('test/' in name or 'integration_test/' in name):
            for line, text in enumerate(path.read_text().splitlines(), 1):
                if assertion.search(text):
                    errors.append(f'{name}:{line}: remove image comparison; keep behavioral assertions')
    return errors


def import_violations(local_file, uri, package_name, composition):
    """Guard dependencies, not folder count or a mandatory layer structure."""
    if composition:
        return []
    target = uri
    own_prefix = 'package:' + package_name + '/'
    if uri.startswith(own_prefix):
        target = 'lib/' + uri[len(own_prefix):]
    elif not uri.startswith(('dart:', 'package:')):
        # Resolve relative paths lexically without relying on a target existing.
        parts = []
        for part in (Path(local_file).parent / uri).parts:
            if part == '..' and parts:
                parts.pop()
            elif part != '.':
                parts.append(part)
        target = '/'.join(parts)
    found = []
    ui = '/presentation/' in local_file or re.search(r'/(?:pages|widgets|views)/', local_file)
    domain = '/domain/' in local_file
    data = '/data/' in local_file
    workflow = bool(re.search(r'/(?:application|cubit|bloc|controllers?|notifiers?)/', local_file)
                    or re.search(r'_(?:cubit|bloc|controller|notifier)\.dart$', local_file))
    external_io = re.match(r'(?:dart:(?:io|ffi)|package:(?:dio|http|cloud_firestore|'
                           r'firebase_database|shared_preferences|sqflite|'
                           r'flutter_secure_storage|supabase_flutter)/)', uri)
    ui_target = '/presentation/' in target or re.search(r'/(?:design_system|widgets|pages|views)/', target)
    platform_services = uri == 'package:flutter/services.dart'
    flutter_ui = uri.startswith('package:flutter/') and uri not in (
        'package:flutter/foundation.dart', 'package:flutter/services.dart')
    if domain and (ui_target or '/data/' in target or flutter_ui or platform_services or external_io):
        found.append(('domain-independent', 'keep domain logic independent; inject its integration contract'))
    if data and (ui_target or flutter_ui):
        found.append(('data-no-presentation', 'move UI formatting/composition to its UI or shared logic responsibility'))
    if ui and external_io:
        found.append(('ui-no-direct-io', 'use the existing repository/adapter instead of direct network or storage access'))
    if workflow and (flutter_ui or re.search(r'/(?:design_system|widgets|pages|views)/', target)):
        found.append(('workflow-no-widgets', 'keep application state independent of widgets; compose them in the page'))
    if local_file.startswith(('lib/core/', 'lib/shared/')) and target.startswith('lib/features/'):
        found.append(('shared-no-feature', 'move feature composition to an explicit composition root'))
    return found


def check_boundaries(root, config, files):
    if config['profile'] not in ('flutter-app-cubit', 'flutter-app-riverpod'):
        return []
    errors = []
    for package_root in config['packageRoots']:
        package_path = root / package_root
        pubspec = (package_path / 'pubspec.yaml').read_text()
        name = re.search(r'^name:\s*[\'"]?([a-zA-Z0-9_]+)', pubspec, re.M)
        package_name = name[1] if name else ''
        prefix = '' if package_root == '.' else package_root.rstrip('/') + '/'
        for file in files:
            if not file.startswith(prefix + 'lib/') or not file.endswith('.dart'):
                continue
            if file.endswith(('.g.dart', '.freezed.dart')) or '/generated/' in file:
                continue
            path = root / file
            if not path.is_file():
                continue
            local = file[len(prefix):]
            content = path.read_text()
            # Directives can span lines and contain conditional URIs.
            for directive in re.finditer(r'^\s*(?:import|export)\s+[\'"][^;]+;', content, re.M):
                for uri in re.findall(r'[\'"]([^\'"]+)[\'"]', directive[0]):
                    composition = matches(local, config.get('compositionRoots', []))
                    for rule, action in import_violations(local, uri, package_name, composition):
                        exceptions = config.get('boundaryExceptions', [])
                        if any(e['file'] == file and e['import'] == uri and e['rule'] == rule for e in exceptions):
                            continue
                        line = content.count('\n', 0, directive.start()) + 1
                        errors.append(f'{file}:{line}: [{rule}] {uri}: {action}')
    return errors


def impact(config, files):
    lanes = {'policy': True, 'flutter': False, 'server': False,
             'contracts': False, 'native': False, 'release': False}
    for file in files:
        if matches(file, config.get('contractPaths', [])):
            lanes.update(flutter=True, server=True, contracts=True)
        if matches(file, config.get('releasePaths', [])):
            lanes['release'] = True
        if any(file.startswith(p.rstrip('/') + '/') for p in config.get('serverRoots', [])):
            if not file.endswith(('.md', '.txt')):
                lanes['server'] = True
            continue
        for package_root in config['packageRoots']:
            prefix = '' if package_root == '.' else package_root.rstrip('/') + '/'
            if not file.startswith(prefix):
                continue
            local = file[len(prefix):]
            if matches(local, ['lib/**', 'test/**', 'integration_test/**', 'assets/**',
                               'pubspec.*', 'analysis_options*', 'l10n.yaml', '.fvmrc',
                               'tool/**', 'scripts/quality/**', 'scripts/codegen/**']):
                lanes['flutter'] = True
            if matches(local, ['android/**', 'ios/**', 'macos/**', 'windows/**', 'linux/**', 'web/**']):
                lanes.update(flutter=True, native=True)
        if matches(file, ['.github/workflows/**', '.gitlab-ci.yml', '.gtm/quality.json',
                          'tool/**', 'scripts/quality/**', 'foundation/**']):
            lanes.update(flutter=True, server=bool(config.get('serverRoots')))
    return lanes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['check', 'skills', 'impact', 'package-roots'], nargs='?', default='check')
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument('--skills-dir', type=Path)
    parser.add_argument('--base')
    parser.add_argument('--files', nargs='*')
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        if args.command == 'skills':
            errors = validate_skills(args.skills_dir or root / '.agents/skills')
        else:
            config = read_config(root)
            if args.command == 'package-roots':
                print('\n'.join(config['packageRoots']))
                return 0
            if args.command == 'impact':
                files = args.files
                if files is None:
                    if not args.base:
                        parser.error('impact requires --base or --files')
                    result = subprocess.run(['git', '-C', str(root), 'diff', '--name-only',
                                             '-z', args.base, '--'], check=True, capture_output=True)
                    files = [p for p in result.stdout.decode().split('\0') if p]
                print(json.dumps(impact(config, files), sort_keys=True))
                return 0
            files = tracked_and_new_files(root)
            errors = validate_skills(root / '.agents/skills')
            errors += check_no_visual_baselines(root, files)
            errors += check_boundaries(root, config, files)
        if errors:
            print('\n'.join(errors), file=sys.stderr)
            return 1
        print('Local policy, skills, and selected boundaries are valid.')
        return 0
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        print('Quality configuration error: ' + str(error), file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
