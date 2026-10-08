#!/usr/bin/env python3
"""Checks every path the app calls against the backend's NestJS routes.

Usage: python3 tool/api_audit.py [path/to/NPC_ECRVS_API_V2]

Reads `@Controller`/`@Get`/... decorators from the backend and every
`_client.get/post/...` call in lib/features/**/data. Prints the calls with
no matching route (method and path; request and response shapes are not
checked). Exits 1 when any is found.
"""
import glob
import os
import re
import sys

BACKEND = sys.argv[1] if len(sys.argv) > 1 else '../NPC_ECRVS_API_V2'
APP = os.path.join(os.path.dirname(__file__), '..', 'lib', 'features')

# Values of the enums whose `apiPath` or `apiName` builds paths.
API_PATHS = {
    'dashboard': ['birth', 'attestation', 'death', 'stillbirth'],
    'certificate_reissuance': ['birth-reg', 'birth-attest'],
    'modifications': ['birth-registration', 'birth-attestation', 'death-registration'],
}
# Calls to storage (presigned URLs), and paths whose prefix is a variable
# (`'$path$id'`), are checked by hand.
SKIP = {'url.toString()', 'path'}


def backend_routes():
    routes = []
    for f in glob.glob(f'{BACKEND}/src/**/*.controller.ts', recursive=True):
        s = open(f).read()
        # @Controller('x') or @Controller({ path: 'x', ... })
        m = re.search(
            r"@Controller\(\s*(?:['\"`]([^'\"`]*)['\"`]|\{[^}]*path:\s*['\"`]([^'\"`]*)['\"`])?", s)
        base = (m.group(1) or m.group(2) or '') if m else ''
        for d in re.finditer(r"@(Get|Post|Put|Patch|Delete)\(\s*(?:['\"`]([^'\"`]*)['\"`])?\s*\)", s):
            parts = [x.strip('/') for x in (base, d.group(2) or '') if x.strip('/')]
            path = '/' + '/'.join(parts)
            segs = ['[^/]+' if p.startswith(':') else re.escape(p) for p in path.strip('/').split('/')]
            routes.append((d.group(1).upper(), path, re.compile('^/' + '/'.join(segs) + '/?$')))
    return routes


def call_expression(s, start):
    depth, expr = 0, ''
    for ch in s[start:start + 300]:
        if ch in '([{':
            depth += 1
        if ch in ')]}':
            if depth == 0:
                break
            depth -= 1
        if ch == ',' and depth == 0:
            break
        expr += ch
    return expr.strip()


def app_calls():
    for f in sorted(glob.glob(f'{APP}/**/data/*.dart', recursive=True)):
        s = open(f).read()
        feature = os.path.relpath(f, APP).split(os.sep)[0]
        consts = dict(re.findall(r"(?:static )?const (?:String )?(\w+) = '([^']*)';", s))
        for m in re.finditer(r"_client\.(get|post|put|patch|delete)\s*(?:<[^>(]*>)?\(\s*", s):
            expr = call_expression(s, m.end())
            line = s[:m.start()].count('\n') + 1
            where = f'{os.path.relpath(f, os.path.join(APP, ".."))}:{line}'
            if expr in SKIP:
                continue
            literals = re.findall(r"'([^']*)'", expr)
            # A ternary between two paths: check each.
            joined = literals if '?' in expr and len(literals) > 1 else ["".join(literals) or consts.get(expr, '')]
            for raw in joined:
                raw = re.sub(r"\$\{_application\([^)]*\)\}", consts.get('_basePath', ':p') + '/:p', raw)
                variants = [re.sub(r"\$\{[\w.]*api(?:Path|Name)\}", v, raw) for v in API_PATHS.get(feature, [raw])] if re.search('api(Path|Name)', raw) else [raw]
                for v in variants:
                    p = re.sub(r"\$\{[^}]*\}", ':p', v)
                    p = re.sub(r"\$(\w+)", lambda k: consts.get(k.group(1), ':p'), p)
                    if p.startswith(':p'):
                        continue  # The prefix is a parameter; see SKIP.
                    yield m.group(1).upper(), p, where


def main():
    routes = backend_routes()
    if not routes:
        sys.exit(f'No controllers found under {BACKEND}/src')
    missing, checked = [], 0
    for method, path, where in app_calls():
        checked += 1
        probe = path.replace(':p', 'X1')
        if not any(m == method and r.match(probe) for m, _, r in routes):
            missing.append((method, path, where))
    print(f'{checked} calls checked against {len(routes)} backend routes.')
    for method, path, where in missing:
        print(f'  NOT FOUND  {method:6} {path:55} {where}')
    sys.exit(1 if missing else 0)


if __name__ == '__main__':
    main()
