#!/usr/bin/env python3
"""
Add the test targets to a PoopSocial project.pbxproj produced by gen_pbxproj.py.

Two targets are added:

  * ``PoopSocialTests``  — a **standalone** unit-test bundle. It does not use the
    app as a test host. Instead the few app sources it needs are compiled
    straight into the bundle. Those sources are deliberately pure Swift (no
    UIKit, no SwiftData), so this is simpler and far more reliable than a hosted
    test: there is no ``@testable import`` to resolve, no ``TEST_HOST`` path to
    get right, and the tests run in milliseconds.

    (A hosted test was tried first. It kept failing with "no such module
    'PoopSocial'" because the app target's emitted ``.swiftmodule`` never
    surfaced into the products directory the test bundle searches. Adding the
    handful of pure sources is the durable fix.)

  * ``PoopSocialUITests`` — a UI-test bundle, which *does* need the app: it
    drives it through the accessibility layer, so it keeps a real dependency on
    the app target.

Idempotent: running it twice changes nothing.

Usage: add_uitest_target.py <project-root>
"""
import os
import re
import sys

APP_TARGET_NAME = "PoopSocial"

UNIT_TARGET = "PoopSocialTests"
UNIT_DIR = "PoopSocialTests"
UNIT_BUNDLE_ID = "com.poopsocial.app.tests"

# Pure-Swift app sources the unit tests exercise. These carry no framework
# dependencies, so they compile cleanly into the test bundle.
UNIT_SHARED_SOURCES = [
    ("PoopSocial/Models/ContentModerator.swift", "ContentModerator.swift"),
    # Models.swift + Theme.swift are here for PostImagePolicyTests, which
    # reflects over `Post` to prove the no-images policy holds at the type level
    # rather than only in the view tree.
    #
    # This is the *only* place they can live: XCUITest runs out-of-process and
    # has no `@testable import`, so a UI test bundle cannot name `Post` at all
    # ("cannot find 'Post' in scope"). The unit bundle can, provided the app
    # sources it needs are compiled in.
    #
    # Models.swift needs Theme.swift for `Color` values (Closeness.tint,
    # Verdict.tint). Theme.swift is self-contained -- SwiftUI only, no other
    # app-owned type -- so it does not drag in further sources.
    ("PoopSocial/Models/Models.swift", "Models.swift"),
    ("PoopSocial/Design/Theme.swift", "Theme.swift"),
    ("PoopSocial/Data/ContactHasher.swift", "ContactHasher.swift"),
    ("PoopSocial/Data/LLM.swift", "LLM.swift"),
    ("PoopSocial/Data/LLMRouter.swift", "LLMRouter.swift"),
    ("PoopSocial/Data/LLMKeyStore.swift", "LLMKeyStore.swift"),
]
UI_TARGET = "PoopSocialUITests"
UI_DIR = "PoopSocialUITests"
UI_BUNDLE_ID = "com.poopsocial.app.uitests"


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else "."
    pbx = os.path.join(root, "PoopSocial.xcodeproj", "project.pbxproj")

    if not os.path.isfile(pbx):
        raise SystemExit(f"no project at {pbx}")

    with open(pbx) as fh:
        text = fh.read()

    # Continue the generator's AA... counter so ids cannot collide.
    used = re.findall(r"AA[0-9A-F]{22}", text)
    counter = max(int(u[2:], 16) for u in used) + 1

    def uid():
        nonlocal counter
        v = counter
        counter += 1
        return f"AA{v:022X}"

    def swift_files_in(dirname):
        d = os.path.join(root, dirname)
        if not os.path.isdir(d):
            return []
        return sorted(f for f in os.listdir(d) if f.endswith(".swift"))

    m = re.search(
        r"(\w{24}) /\* %s \*/ = \{\s*\n\t\t\tisa = PBXNativeTarget;" % re.escape(APP_TARGET_NAME),
        text,
    )
    if not m:
        raise SystemExit("could not locate the app native target")
    app_target = m.group(1)

    m = re.search(
        r"(\w{24}) /\* %s\.app \*/ = \{isa = PBXFileReference;[^}]*explicitFileType = wrapper\.application" % re.escape(APP_TARGET_NAME),
        text,
    )
    if not m:
        raise SystemExit("could not locate the app product reference")
    app_product = m.group(1)

    products_group = re.search(r"productRefGroup = (\w{24})", text).group(1)
    root_obj = re.search(r"rootObject = (\w{24})", text).group(1)

    added = []

    def add_sources_to_target(name, dirname, new_files):
        """Add extra source files to an already-present test target.

        Used when a new test file appears in a directory whose target was
        created on an earlier run. Appends the file reference, build file,
        group child and Sources-phase entry so the file is actually compiled.
        """
        nonlocal text

        target_m = re.search(
            r"(\w{24}) /\* %s \*/ = \{\s*\n\t\t\tisa = PBXNativeTarget;" % re.escape(name),
            text,
        )
        if not target_m:
            print(f"  (could not locate {name} target; skipping new sources)")
            return
        target_id = target_m.group(1)
        tbody = re.search(
            r"%s /\* %s \*/ = \{(.*?)\n\t\t\};" % (target_id, re.escape(name)), text, re.S
        ).group(1)

        src_phase = re.search(r"(\w{24}) /\* Sources \*/", tbody).group(1)
        group_id = re.search(
            r"(\w{24}) /\* %s \*/ = \{\s*\n\t\t\tisa = PBXGroup;" % re.escape(name), text
        ).group(1)

        file_refs, build_files = [], []
        for f in new_files:
            ref, bf = uid(), uid()
            file_refs.append((f, ref))
            build_files.append((f, bf))

            # PBXBuildFile + PBXFileReference
            text = text.replace(
                "/* End PBXBuildFile section */",
                f"\t\t{bf} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref} /* {f} */; }};\n/* End PBXBuildFile section */",
                1,
            )
            text = text.replace(
                "/* End PBXFileReference section */",
                f'\t\t{ref} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = "{f}"; path = "{dirname}/{f}"; sourceTree = SOURCE_ROOT; }};\n/* End PBXFileReference section */',
                1,
            )

            # group child
            text = text.replace(
                f"\t\t{group_id} /* {name} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n",
                f"\t\t{group_id} /* {name} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\t{ref} /* {f} */,\n",
                1,
            )

            # Sources phase entry
            text = text.replace(
                f"\t\t{src_phase} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n",
                f"\t\t{src_phase} /* Sources */ = {{\n\t\t\tisa = PBXSourcesBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t\t{bf} /* {f} in Sources */,\n",
                1,
            )

    def add_target(name, dirname, bundle_id, product_type, is_unit):
        nonlocal text

        own_sources = swift_files_in(dirname)
        if not own_sources:
            print(f"  (skipping {name}: no sources in {dirname}/)")
            return

        # Idempotency has to be per-*file*, not per-target. If we skipped
        # whenever the target existed, any new test file dropped into an
        # existing test directory would be silently left out of the build.
        target_exists = re.search(
            r"/\* %s \*/ = \{\s*\n\t\t\tisa = PBXNativeTarget;" % re.escape(name), text
        )
        if target_exists:
            missing = [
                f for f in own_sources
                if f"/* {f} */ = {{isa = PBXFileReference;" not in text
            ]
            if not missing:
                print(f"  ({name} already present and up to date, skipping)")
                return
            print(f"  ({name} exists; adding {len(missing)} new file(s))")
            add_sources_to_target(name, dirname, missing)
            added.append((name, len(missing)))
            return

        entries = [(f, f"{dirname}/{f}", dirname) for f in own_sources]

        # A standalone unit bundle also compiles the pure app sources it needs.
        for rel, base in UNIT_SHARED_SOURCES if is_unit else []:
            if os.path.isfile(os.path.join(root, rel)):
                entries.append((base, rel, os.path.dirname(rel)))

        fileref = {lbl: uid() for lbl, _, _ in entries}
        buildfile = {lbl: uid() for lbl, _, _ in entries}
        product = uid()
        group = uid()
        target = uid()
        src_phase = uid()
        fw_phase = uid()
        res_phase = uid()
        cfg_list = uid()
        dbg = uid()
        rel_cfg = uid()
        dep = uid()
        cproxy = uid()

        # --- PBXBuildFile ---
        lines = [
            f"\t\t{buildfile[lbl]} /* {lbl} in Sources */ = {{isa = PBXBuildFile; fileRef = {fileref[lbl]} /* {lbl} */; }};"
            for lbl, _, _ in entries
        ]
        text = text.replace(
            "/* End PBXBuildFile section */",
            "\n".join(lines) + "\n/* End PBXBuildFile section */",
            1,
        )

        # --- PBXFileReference ---
        lines = [
            f'\t\t{fileref[lbl]} /* {lbl} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = "{lbl}"; path = "{path}"; sourceTree = SOURCE_ROOT; }};'
            for lbl, path, _ in entries
        ]
        lines.append(
            f"\t\t{product} /* {name}.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {name}.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};"
        )
        text = text.replace(
            "/* End PBXFileReference section */",
            "\n".join(lines) + "\n/* End PBXFileReference section */",
            1,
        )

        # --- build phases ---
        text = text.replace(
            "/* End PBXFrameworksBuildPhase section */",
            f"""\t\t{fw_phase} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */""",
            1,
        )
        text = text.replace(
            "/* End PBXResourcesBuildPhase section */",
            f"""\t\t{res_phase} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */""",
            1,
        )
        block = f"""\t\t{src_phase} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
"""
        for lbl, _, _ in entries:
            block += f"\t\t\t\t{buildfile[lbl]} /* {lbl} in Sources */,\n"
        block += """\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXSourcesBuildPhase section */"""
        text = text.replace("/* End PBXSourcesBuildPhase section */", block, 1)

        # --- group ---
        gblock = f"""\t\t{group} /* {name} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
"""
        for lbl, _, _ in entries:
            gblock += f"\t\t\t\t{fileref[lbl]} /* {lbl} */,\n"
        gblock += """\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t};
"""
        text = text.replace("/* End PBXGroup section */", gblock + "/* End PBXGroup section */", 1)
        text = text.replace(
            f"\t\t\t\t{products_group} /* Products */,\n",
            f"\t\t\t\t{products_group} /* Products */,\n\t\t\t\t{group} /* {name} */,\n",
            1,
        )
        text = text.replace(
            f"\t\t\t\t{app_product} /* {APP_TARGET_NAME}.app */,\n",
            f"\t\t\t\t{app_product} /* {APP_TARGET_NAME}.app */,\n\t\t\t\t{product} /* {name}.xctest */,\n",
            1,
        )

        # --- dependency on the app (UI tests only) ---
        #
        # UI tests drive the app from a separate runner, so they need it built
        # first. The standalone unit bundle shares no binary with the app, so it
        # must *not* depend on it — and it must not be embedded in the app
        # either, which would close a build cycle.
        if not is_unit:
            text = text.replace(
                "/* Begin PBXGroup section */",
                f"""/* Begin PBXTargetDependency section */
\t\t{dep} /* PBXTargetDependency */ = {{
\t\t\tisa = PBXTargetDependency;
\t\t\ttarget = {app_target} /* {APP_TARGET_NAME} */;
\t\t\ttargetProxy = {cproxy} /* PBXContainerItemProxy */;
\t\t}};
/* End PBXTargetDependency section */

/* Begin PBXContainerItemProxy section */
\t\t{cproxy} /* PBXContainerItemProxy */ = {{
\t\t\tisa = PBXContainerItemProxy;
\t\t\tcontainerPortal = {root_obj} /* Project object */;
\t\t\tproxyType = 1;
\t\t\tremoteGlobalIDString = {app_target};
\t\t\tremoteInfo = {APP_TARGET_NAME};
\t\t}};
/* End PBXContainerItemProxy section */

/* Begin PBXGroup section */""",
                1,
            )

        deps_body = "" if is_unit else f"\t\t\t\t{dep} /* PBXTargetDependency */,\n"

        text = text.replace(
            "/* End PBXNativeTarget section */",
            f"""\t\t{target} /* {name} */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {cfg_list} /* Build configuration list for PBXNativeTarget "{name}" */;
\t\t\tbuildPhases = (
\t\t\t\t{src_phase} /* Sources */,
\t\t\t\t{fw_phase} /* Frameworks */,
\t\t\t\t{res_phase} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
{deps_body}\t\t\t);
\t\t\tname = {name};
\t\t\tproductName = {name};
\t\t\tproductReference = {product} /* {name}.xctest */;
\t\t\tproductType = "{product_type}";
\t\t}};
/* End PBXNativeTarget section */""",
            1,
        )

        # Register the target, anchoring on the app entry so this works however
        # many targets were added before.
        text = text.replace(
            f"\t\t\t\t{app_target} /* {APP_TARGET_NAME} */,\n",
            f"\t\t\t\t{app_target} /* {APP_TARGET_NAME} */,\n\t\t\t\t{target} /* {name} */,\n",
            1,
        )

        # TargetAttributes: give UI tests their host app so XCTest wires up the
        # runner. The standalone unit bundle needs no TestTargetID.
        extra_attr = (
            f"\t\t\t\t\t{target} = {{\n"
            f"\t\t\t\t\t\tCreatedOnToolsVersion = 15.2;\n"
            f"\t\t\t\t\t\tTestTargetID = {app_target};\n"
            f"\t\t\t\t\t}};\n"
        ) if not is_unit else (
            f"\t\t\t\t\t{target} = {{\n"
            f"\t\t\t\t\t\tCreatedOnToolsVersion = 15.2;\n"
            f"\t\t\t\t\t}};\n"
        )
        text = text.replace(
            f"\t\t\t\t\t{app_target} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.2;\n\t\t\t\t\t}};\n",
            f"\t\t\t\t\t{app_target} = {{\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.2;\n\t\t\t\t\t}};\n" + extra_attr,
            1,
        )

        # --- configurations ---
        settings = [
            "CODE_SIGN_STYLE = Automatic;",
            "CURRENT_PROJECT_VERSION = 1;",
            "GENERATE_INFOPLIST_FILE = YES;",
            "MARKETING_VERSION = 1.0;",
            f"PRODUCT_BUNDLE_IDENTIFIER = {bundle_id};",
            'PRODUCT_NAME = "$(TARGET_NAME)";',
            "SWIFT_EMIT_LOC_STRINGS = NO;",
            "SWIFT_VERSION = 5.0;",
            'TARGETED_DEVICE_FAMILY = "1,2";',
        ]
        if not is_unit:
            settings.append("ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES;")
            settings.append(f"TEST_TARGET_NAME = {APP_TARGET_NAME};")

        def cfg_body(obj_id, cname):
            body = f"""\t\t{obj_id} /* {cname} */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
"""
            for s in settings:
                body += f"\t\t\t\t{s}\n"
            body += f"""\t\t\t}};
\t\t\tname = {cname};
\t\t}};
"""
            return body

        text = re.sub(
            r"/\* Begin XCBuildConfiguration section \*/\n",
            "/* Begin XCBuildConfiguration section */\n" + cfg_body(dbg, "Debug") + cfg_body(rel_cfg, "Release"),
            text,
            count=1,
        )

        text = text.replace(
            "/* End XCConfigurationList section */",
            f"""\t\t{cfg_list} /* Build configuration list for PBXNativeTarget "{name}" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{dbg} /* Debug */,
\t\t\t\t{rel_cfg} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */""",
            1,
        )

        added.append((name, len(entries)))

    add_target(UNIT_TARGET, UNIT_DIR, UNIT_BUNDLE_ID, "com.apple.product-type.bundle.unit-test", True)
    add_target(UI_TARGET, UI_DIR, UI_BUNDLE_ID, "com.apple.product-type.bundle.ui-testing", False)

    with open(pbx, "w") as fh:
        fh.write(text)

    if added:
        for name, n in added:
            print(f"added {name} with {n} source file(s)")
    else:
        print("no test targets needed adding")


if __name__ == "__main__":
    main()
