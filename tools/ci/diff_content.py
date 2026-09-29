"""Conservative content facts used by both the selector and its required gate."""
import re
import subprocess

DECLARATION = re.compile(r'^\s*(?:function|classdef|methods)\b')
API_BLOCK = re.compile(r'^\s*(?:properties|arguments|enumeration|events)\b')
END = re.compile(r'^\s*end\s*;?\s*(?:%.*)?$')
DYNAMIC_DOCUMENTATION = re.compile(r'\b\w*Annotation\w*\b|\bdefaultOperations\b|\b(?:eval|evalin)\s*\(')


def matlab_documentation_signature(source):
    """Retain all declarations, help/comments and API definition blocks.

    This is deliberately a proof of a narrow kind of implementation-only edit,
    not a MATLAB parser. Uncertain syntax and dynamic annotation construction
    require documentation validation. Inline-comment changes are conservative.
    """
    # Class reflection also consumes bare external/abstract method prototypes.
    # A line scanner cannot prove arbitrary class-body edits documentation-free.
    if DYNAMIC_DOCUMENTATION.search(source) or re.search(r'^\s*classdef\b', source, re.MULTILINE):
        return None
    lines = source.splitlines()
    signature = []
    has_declaration = False
    declaration_lines = []
    in_api_block = in_block_comment = continuation = False
    for line in lines:
        stripped = line.strip()
        if in_block_comment:
            signature.append(line)
            if stripped == '%}':
                in_block_comment = False
            continue
        if stripped == '%{':
            in_block_comment = True
            signature.append(line)
            continue
        if in_api_block:
            signature.append(line)
            if END.match(line):
                in_api_block = False
            elif re.match(r'^\s*(?:function|classdef|if|for|while|switch|try|properties|arguments)\b', line):
                return None
            continue
        if API_BLOCK.match(line):
            # One-line blocks or comma-separated code are deliberately uncertain.
            if ';' in line or ',' in line.split('%', 1)[0]:
                return None
            in_api_block = True
            signature.append(line)
        elif continuation or DECLARATION.match(line):
            has_declaration |= bool(re.match(r'^\s*(?:function|classdef)\b', line))
            signature.append(line)
            declaration_lines.append(line.split('%', 1)[0])
            continuation = '...' in line.split('%', 1)[0]
            if not continuation:
                declaration = ' '.join(declaration_lines)
                if any(declaration.count(left) != declaration.count(right) for left, right in [('(', ')'), ('[', ']'), ('{', '}')]):
                    return None
                declaration_lines = []
        elif '%' in line:
            signature.append(line)
    if not has_declaration or in_api_block or in_block_comment or continuation:
        return None
    return signature


def documentation_changed(before, after):
    if before is None or after is None:
        return True
    if before == after:
        return False
    left = matlab_documentation_signature(before)
    right = matlab_documentation_signature(after)
    return left is None or right is None or left != right


def git_source(revision, path):
    result = subprocess.run(['git', 'show', f'{revision}:{path}'], capture_output=True)
    if result.returncode:
        return None
    try:
        return result.stdout.decode('utf-8')
    except UnicodeDecodeError:
        return None


def matlab_diff_facts(base, head, paths):
    surviving, implementation_only = [], []
    for path in sorted(set(paths)):
        if not path.endswith('.m'):
            continue
        before, after = git_source(base, path), git_source(head, path)
        if after is not None:
            surviving.append(path)
        if not documentation_changed(before, after):
            implementation_only.append(path)
    return surviving, implementation_only
