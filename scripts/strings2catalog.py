import json, re, sys
import xml.etree.ElementTree as ET

src, out_catalog, out_swift = sys.argv[1], sys.argv[2], sys.argv[3]

def unescape(s):
    if s is None: return ''
    s = s.replace("\\'", "'").replace('\\"', '"').replace('\\n', '\n')
    return s

def convert_fmt(s):
    # Android format specifiers -> Foundation ones.
    s = re.sub(r'%(\d+\$)?s', lambda m: f"%{m.group(1) or ''}@", s)
    s = re.sub(r'%(\d+\$)?d', lambda m: f"%{m.group(1) or ''}lld", s)
    return s

def text_of(el):
    return unescape(''.join(el.itertext()))

tree = ET.parse(src)
strings = {}   # key -> ('plain'|'fmt'|'plural', value or {qty: value})
for el in tree.getroot():
    if el.tag == 'string':
        strings[el.get('name')] = ('plain', convert_fmt(text_of(el)))
    elif el.tag == 'plurals':
        qty = {item.get('quantity'): convert_fmt(text_of(item)) for item in el}
        strings[el.get('name')] = ('plural', qty)

def args_of(fmt):
    # positional or sequential specifiers, in order
    found = re.findall(r'%(\d+\$)?(@|lld|\.?\d*f)', fmt)
    if any(pos for pos, _ in found):
        ordered = sorted(found, key=lambda f: int(f[0][:-1]))
    else:
        ordered = found
    def kind_of(kind):
        if kind == '@': return 'String'
        if kind == 'lld': return 'Int'
        return 'Double'
    return [kind_of(kind) for _, kind in ordered]

# Which argument a plural counts on. Android names it at every call site and
# Swift cannot infer it once a string carries more than one number, so the few
# that do are listed here, read off those calls.
PLURAL_ARG = {
    'days_completed_format': 2,
    'regenerate_week_message_trained': 1,
    'delete_week_message_trained': 1,
}

catalog = {"sourceLanguage": "en", "strings": {}, "version": "1.0"}
for key, (kind, value) in sorted(strings.items()):
    if kind == 'plural':
        variations = {"plural": {q: {"stringUnit": {"state": "translated", "value": v}}
                                 for q, v in value.items()}}
        # A plural carrying other numbers cannot say which one it counts on, so
        # the whole sentence becomes a substitution that names the argument.
        if max(len(args_of(v)) for v in value.values()) > 1:
            catalog["strings"][key] = {"extractionState": "manual", "localizations": {"en": {
                "stringUnit": {"state": "translated", "value": "%#@count@"},
                "substitutions": {"count": {
                    "argNum": PLURAL_ARG.get(key, 1),
                    "formatSpecifier": "lld",
                    "variations": variations}}}}}
        else:
            catalog["strings"][key] = {"extractionState": "manual", "localizations": {"en": {
                "variations": variations}}}
    else:
        catalog["strings"][key] = {"extractionState": "manual", "localizations": {"en": {
            "stringUnit": {"state": "translated", "value": value}}}}

json.dump(catalog, open(out_catalog, 'w'), indent=2, ensure_ascii=False, sort_keys=True)

def camel(key):
    parts = key.split('_')
    return parts[0] + ''.join(p.capitalize() for p in parts[1:])

lines = [
    '// Generated from the Android app\'s strings.xml by scripts/generate-strings.sh.',
    '// Regenerate rather than editing: the catalog and these accessors move together.',
    'import Foundation',
    '',
    '// swiftlint:disable all',
    'nonisolated enum L10n {',
]
for key, (kind, value) in sorted(strings.items()):
    name = camel(key)
    if name == 'continue': name = 'continueLabel'
    if kind == 'plural':
        args = max((args_of(v) for v in value.values()), key=len)
        params = ', '.join(f'_ p{i}: {t}' for i, t in enumerate(args, 1)) or '_ p1: Int'
        call = ', '.join(f'p{i}' for i in range(1, max(len(args), 1) + 1))
        lines.append(f'    static func {name}({params}) -> String {{')
        lines.append(f'        String.localizedStringWithFormat(String(localized: "{key}"), {call})')
        lines.append('    }')
    else:
        args = args_of(value)
        if not args:
            lines.append(f'    static var {name}: String {{ String(localized: "{key}") }}')
        else:
            params = ', '.join(f'_ p{i}: {t}' for i, t in enumerate(args, 1))
            call = ', '.join(f'p{i}' for i in range(1, len(args) + 1))
            lines.append(f'    static func {name}({params}) -> String {{')
            lines.append(f'        String.localizedStringWithFormat(String(localized: "{key}"), {call})')
            lines.append('    }')
lines.append('}')
lines.append('// swiftlint:enable all')
open(out_swift, 'w').write('\n'.join(lines) + '\n')
print(f'{len(strings)} strings')
