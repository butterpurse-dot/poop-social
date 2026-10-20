#!/usr/bin/env python3
"""
Add `@MainActor` to SwiftUI view types.

The app's model layer (Store, Haptics, AppModel, UIActivityBridge) is
`@MainActor`-isolated. SwiftUI `View`/`ButtonStyle`/`ViewModifier` conformances
are not implicitly isolated under Swift 5.9's stricter checking, so button
actions and `onChange` closures that call into the model layer fail with
"call to main actor-isolated ... in a synchronous nonisolated context".

Marking the view types `@MainActor` is correct (SwiftUI bodies run on the main
actor) and resolves every one of those diagnostics.

Idempotent: re-running will not double-annotate.
"""
import os
import re
import sys

# A declaration line for a type that conforms to one of the SwiftUI view
# protocols we want isolated.
DECL_RE = re.compile(
    r"^(?P<indent>[ \t]*)"
    r"(?P<decl>(?:public |private |internal |fileprivate )?"
    r"struct\s+\w+[^:{]*:\s*(?:View|ButtonStyle|ViewModifier)\b[^)]*?\{)",
    re.MULTILINE,
)


def process(path):
    with open(path) as fh:
        text = fh.read()
    original = text

    out_lines = []
    lines = text.split("\n")
    i = 0
    changed = 0
    while i < len(lines):
        line = lines[i]
        m = DECL_RE.match(line)
        if m:
            # Look back over blanks / attribute-only lines for an existing
            # @MainActor so we don't add a duplicate.
            j = len(out_lines) - 1
            already = False
            while j >= 0:
                prev = out_lines[j].strip()
                if prev == "" or prev.startswith("//") or prev.startswith("///"):
                    j -= 1
                    continue
                if prev.startswith("@"):
                    if "MainActor" in prev:
                        already = True
                    j -= 1
                    continue
                break
            if not already:
                indent = m.group("indent")
                out_lines.append(f"{indent}@MainActor")
                changed += 1
        out_lines.append(line)
        i += 1

    text = "\n".join(out_lines)

    if text != original:
        with open(path, "w") as fh:
            fh.write(text)
    return changed


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    total = 0
    files = 0
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for fn in sorted(filenames):
            if not fn.endswith(".swift"):
                continue
            p = os.path.join(dirpath, fn)
            n = process(p)
            if n:
                files += 1
                total += n
                print(f"  {p}: +{n}")
    print(f"annotated {total} declarations across {files} files")


if __name__ == "__main__":
    main()
