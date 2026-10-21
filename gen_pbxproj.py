#!/usr/bin/env python3
"""
Generate an Xcode 15-compatible project.pbxproj for PoopSocial.

The original project uses `PBXFileSystemSynchronizedRootGroup` and
`objectVersion = 77`, which only Xcode 16+ understands. Xcode 15.2 cannot even
parse it. This rewrites the project into the classic explicit-reference form
(objectVersion 56) that Xcode 15 accepts, enumerating every source file and the
asset catalog.

Run from the directory that contains PoopSocial.xcodeproj, or pass the project
root as argv[1].
"""
import os
import sys

PROJECT_NAME = "PoopSocial"
TARGET_NAME = "PoopSocial"
BUNDLE_ID = "com.poopsocial.app"
DISPLAY_NAME = "poop social"
DEPLOYMENT_TARGET = "17.0"

# Stable, readable 24-hex object ids.
_counter = 0


def uid():
    global _counter
    _counter += 1
    return f"AA{_counter:022X}"


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    app_dir = os.path.join(root, PROJECT_NAME)
    if not os.path.isdir(app_dir):
        raise SystemExit(f"app sources not found at {app_dir}")

    # ---- collect files, grouped by directory -------------------------------
    # relpath (relative to app_dir) -> absolute
    swift_files = []
    asset_catalogs = []

    # Asset catalogues are top-level .xcassets *directories*; they must be
    # passed to Xcode as a single unit. Walking into them would surface their
    # Contents.json and icon PNGs as loose build inputs, which makes actool
    # fail with "failed to read asset tags".
    catalog_dirs = sorted(
        entry for entry in os.listdir(app_dir)
        if entry.endswith(".xcassets") and os.path.isdir(os.path.join(app_dir, entry))
    )

    for dirpath, dirnames, filenames in os.walk(app_dir):
        dirnames.sort()
        # Never descend into an asset catalogue.
        dirnames[:] = [
            d for d in dirnames
            if not d.endswith(".xcassets")
        ]
        for fn in sorted(filenames):
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, app_dir)
            if fn.endswith(".swift"):
                swift_files.append(rel)

    asset_catalogs.extend(catalog_dirs)

    # Only keep the asset catalog once (it was picked up as a dir, not a file).
    asset_catalogs = sorted(set(asset_catalogs))

    # ---- directories -> PBXGroup -------------------------------------------
    # Build a group for EVERY directory in the tree, including intermediate
    # directories that hold no files directly (e.g. `Features`, whose children
    # are all subdirectories). Omitting those leaves their child groups detached
    # from the root, so the files inside them resolve against the wrong base
    # path and xcodebuild reports "Build input files cannot be found".
    dirs = {""}
    for rel in swift_files + asset_catalogs:
        d = os.path.dirname(rel)
        while d:
            dirs.add(d)
            d = os.path.dirname(d)
    dirs = sorted(dirs)
    group_for_dir = {d: uid() for d in dirs}

    # Per-file references and build files.
    fileref = {}
    buildfile = {}
    for rel in swift_files:
        fileref[rel] = uid()
        buildfile[rel] = uid()
    asset_fileref = {}
    asset_buildfile = {}
    for rel in asset_catalogs:
        asset_fileref[rel] = uid()
        asset_buildfile[rel] = uid()

    # Product + phases + target + project
    product_ref = uid()
    main_group = uid()
    products_group = uid()
    sources_phase = uid()
    frameworks_phase = uid()
    resources_phase = uid()
    native_target = uid()
    project_obj = uid()
    proj_cfg_list = uid()
    target_cfg_list = uid()
    proj_debug = uid()
    proj_release = uid()
    tgt_debug = uid()
    tgt_release = uid()

    L = []
    add = L.append

    add("// !$*UTF8*$!")
    add("{")
    add("\tarchiveVersion = 1;")
    add("\tclasses = {")
    add("\t};")
    add("\tobjectVersion = 56;")
    add("\tobjects = {")
    add("")

    # ---- PBXBuildFile ------------------------------------------------------
    add("/* Begin PBXBuildFile section */")
    for rel in swift_files:
        add(f"\t\t{buildfile[rel]} /* {os.path.basename(rel)} in Sources */ = {{isa = PBXBuildFile; fileRef = {fileref[rel]} /* {os.path.basename(rel)} */; }};")
    for rel in asset_catalogs:
        add(f"\t\t{asset_buildfile[rel]} /* {os.path.basename(rel)} in Resources */ = {{isa = PBXBuildFile; fileRef = {asset_fileref[rel]} /* {os.path.basename(rel)} */; }};")
    add("/* End PBXBuildFile section */")
    add("")

    # ---- PBXFileReference --------------------------------------------------
    add("/* Begin PBXFileReference section */")
    for rel in swift_files:
        add(f"\t\t{fileref[rel]} /* {os.path.basename(rel)} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{os.path.basename(rel)}\"; sourceTree = \"<group>\"; }};")
    for rel in asset_catalogs:
        add(f"\t\t{asset_fileref[rel]} /* {os.path.basename(rel)} */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = \"{os.path.basename(rel)}\"; sourceTree = \"<group>\"; }};")
    add(f"\t\t{product_ref} /* {PROJECT_NAME}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {PROJECT_NAME}.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    add("/* End PBXFileReference section */")
    add("")

    # ---- PBXFrameworksBuildPhase ------------------------------------------
    add("/* Begin PBXFrameworksBuildPhase section */")
    add(f"\t\t{frameworks_phase} /* Frameworks */ = {{")
    add("\t\t\tisa = PBXFrameworksBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXFrameworksBuildPhase section */")
    add("")

    # ---- PBXGroup ----------------------------------------------------------
    add("/* Begin PBXGroup section */")

    # main group
    add(f"\t\t{main_group} = {{")
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    add(f"\t\t\t\t{group_for_dir['']} /* {PROJECT_NAME} */,")
    add(f"\t\t\t\t{products_group} /* Products */,")
    add("\t\t\t);")
    add("\t\t\tsourceTree = \"<group>\";")
    add("\t\t};")

    # products group
    add(f"\t\t{products_group} /* Products */ = {{")
    add("\t\t\tisa = PBXGroup;")
    add("\t\t\tchildren = (")
    add(f"\t\t\t\t{product_ref} /* {PROJECT_NAME}.app */,")
    add("\t\t\t);")
    add("\t\t\tname = Products;")
    add("\t\t\tsourceTree = \"<group>\";")
    add("\t\t};")

    # one group per source directory
    for d in dirs:
        name = os.path.basename(d) if d else PROJECT_NAME
        child_groups = []
        direct_files = []
        for sub in dirs:
            if sub and os.path.dirname(sub) == d:
                child_groups.append(sub)
        for rel in swift_files:
            if os.path.dirname(rel) == d:
                direct_files.append(rel)
        for rel in asset_catalogs:
            if os.path.dirname(rel) == d:
                direct_files.append(rel)
        if not child_groups and not direct_files:
            continue

        add(f"\t\t{group_for_dir[d]} /* {name} */ = {{")
        add("\t\t\tisa = PBXGroup;")
        add("\t\t\tchildren = (")
        for sub in sorted(child_groups):
            add(f"\t\t\t\t{group_for_dir[sub]} /* {os.path.basename(sub)} */,")
        for rel in sorted(direct_files):
            kind = "in Sources" if rel.endswith(".swift") else "in Resources"
            ref = fileref[rel] if rel.endswith(".swift") else asset_fileref[rel]
            add(f"\t\t\t\t{ref} /* {os.path.basename(rel)} */,")
        add("\t\t\t);")
        if d:
            add(f"\t\t\tpath = {name};")
        else:
            add(f"\t\t\tpath = {PROJECT_NAME};")
        add("\t\t\tsourceTree = \"<group>\";")
        add("\t\t};")

    add("/* End PBXGroup section */")
    add("")

    # ---- PBXNativeTarget ---------------------------------------------------
    add("/* Begin PBXNativeTarget section */")
    add(f"\t\t{native_target} /* {TARGET_NAME} */ = {{")
    add("\t\t\tisa = PBXNativeTarget;")
    add(f"\t\t\tbuildConfigurationList = {target_cfg_list} /* Build configuration list for PBXNativeTarget \"{TARGET_NAME}\" */;")
    add("\t\t\tbuildPhases = (")
    add(f"\t\t\t\t{sources_phase} /* Sources */,")
    add(f"\t\t\t\t{frameworks_phase} /* Frameworks */,")
    add(f"\t\t\t\t{resources_phase} /* Resources */,")
    add("\t\t\t);")
    add("\t\t\tbuildRules = (")
    add("\t\t\t);")
    add("\t\t\tdependencies = (")
    add("\t\t\t);")
    add(f"\t\t\tname = {TARGET_NAME};")
    add("\t\t\tproductName = {0};".format(TARGET_NAME))
    add(f"\t\t\tproductReference = {product_ref} /* {PROJECT_NAME}.app */;")
    add("\t\t\tproductType = \"com.apple.product-type.application\";")
    add("\t\t};")
    add("/* End PBXNativeTarget section */")
    add("")

    # ---- PBXProject --------------------------------------------------------
    add("/* Begin PBXProject section */")
    add(f"\t\t{project_obj} /* Project object */ = {{")
    add("\t\t\tisa = PBXProject;")
    add("\t\t\tattributes = {")
    add("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    add("\t\t\t\tLastSwiftUpdateCheck = 1520;")
    add("\t\t\t\tLastUpgradeCheck = 1520;")
    add("\t\t\t\tTargetAttributes = {")
    add(f"\t\t\t\t\t{native_target} = {{")
    add("\t\t\t\t\t\tCreatedOnToolsVersion = 15.2;")
    add("\t\t\t\t\t};")
    add("\t\t\t\t};")
    add("\t\t\t};")
    add(f"\t\t\tbuildConfigurationList = {proj_cfg_list} /* Build configuration list for PBXProject \"{PROJECT_NAME}\" */;")
    add("\t\t\tcompatibilityVersion = \"Xcode 15.0\";")
    add("\t\t\tdevelopmentRegion = en;")
    add("\t\t\thasScannedForEncodings = 0;")
    add("\t\t\tknownRegions = (")
    add("\t\t\t\ten,")
    add("\t\t\t\tBase,")
    add("\t\t\t);")
    add(f"\t\t\tmainGroup = {main_group};")
    add(f"\t\t\tproductRefGroup = {products_group} /* Products */;")
    add("\t\t\tprojectDirPath = \"\";")
    add("\t\t\tprojectRoot = \"\";")
    add("\t\t\ttargets = (")
    add(f"\t\t\t\t{native_target} /* {TARGET_NAME} */,")
    add("\t\t\t);")
    add("\t\t};")
    add("/* End PBXProject section */")
    add("")

    # ---- PBXResourcesBuildPhase -------------------------------------------
    add("/* Begin PBXResourcesBuildPhase section */")
    add(f"\t\t{resources_phase} /* Resources */ = {{")
    add("\t\t\tisa = PBXResourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    for rel in asset_catalogs:
        add(f"\t\t\t\t{asset_buildfile[rel]} /* {os.path.basename(rel)} in Resources */,")
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXResourcesBuildPhase section */")
    add("")

    # ---- PBXSourcesBuildPhase ---------------------------------------------
    add("/* Begin PBXSourcesBuildPhase section */")
    add(f"\t\t{sources_phase} /* Sources */ = {{")
    add("\t\t\tisa = PBXSourcesBuildPhase;")
    add("\t\t\tbuildActionMask = 2147483647;")
    add("\t\t\tfiles = (")
    for rel in sorted(swift_files):
        add(f"\t\t\t\t{buildfile[rel]} /* {os.path.basename(rel)} in Sources */,")
    add("\t\t\t);")
    add("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    add("\t\t};")
    add("/* End PBXSourcesBuildPhase section */")
    add("")

    # ---- XCBuildConfiguration ---------------------------------------------
    common_proj = [
        "ALWAYS_SEARCH_USER_PATHS = NO;",
        "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;",
        "CLANG_ANALYZER_NONNULL = YES;",
        "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;",
        "CLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";",
        "CLANG_ENABLE_MODULES = YES;",
        "CLANG_ENABLE_OBJC_ARC = YES;",
        "CLANG_ENABLE_OBJC_WEAK = YES;",
        "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;",
        "CLANG_WARN_BOOL_CONVERSION = YES;",
        "CLANG_WARN_COMMA = YES;",
        "CLANG_WARN_CONSTANT_CONVERSION = YES;",
        "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;",
        "CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;",
        "CLANG_WARN_DOCUMENTATION_COMMENTS = YES;",
        "CLANG_WARN_EMPTY_BODY = YES;",
        "CLANG_WARN_ENUM_CONVERSION = YES;",
        "CLANG_WARN_INFINITE_RECURSION = YES;",
        "CLANG_WARN_INT_CONVERSION = YES;",
        "CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;",
        "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;",
        "CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;",
        "CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;",
        "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;",
        "CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;",
        "CLANG_WARN_STRICT_PROTOTYPES = YES;",
        "CLANG_WARN_SUSPICIOUS_MOVE = YES;",
        "CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;",
        "CLANG_WARN_UNREACHABLE_CODE = YES;",
        "CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;",
        "COPY_PHASE_STRIP = NO;",
        "ENABLE_STRICT_OBJC_MSGSEND = YES;",
        "ENABLE_USER_SCRIPT_SANDBOXING = YES;",
        "GCC_C_LANGUAGE_STANDARD = gnu17;",
        "GCC_NO_COMMON_BLOCKS = YES;",
        "GCC_WARN_64_TO_32_BIT_CONVERSION = YES;",
        "GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;",
        "GCC_WARN_UNDECLARED_SELECTOR = YES;",
        "GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;",
        "GCC_WARN_UNUSED_FUNCTION = YES;",
        "GCC_WARN_UNUSED_VARIABLE = YES;",
        f"IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};",
        "LOCALIZATION_PREFERS_STRING_CATALOGS = YES;",
        "MTL_FAST_MATH = YES;",
        # `SDKROOT = iphoneos` keeps iOS the default, but the app is genuinely
        # built for macOS too (see SUPPORTED_PLATFORMS below). Leaving SDKROOT
        # at iphoneos means a plain `xcodebuild` with no -destination still
        # produces the iOS build, which is what every existing script and the
        # local iMac workflow expects.
        "SDKROOT = iphoneos;",
        #
        # Multiplatform. The code is written to compile for both: the four
        # UIKit touchpoints (haptics, share sheet, bar styling, audio session)
        # are guarded with `#if os(iOS)`, and everything else — SwiftUI,
        # SwiftData, CoreLocation, Speech, App Intents — is cross-platform.
        #
        # This matters because "it runs on a Mac" is a claim that should be
        # checkable, not asserted. Without macosx here there is no way to build
        # the macOS slice at all, so the claim could never be tested.
        "SUPPORTED_PLATFORMS = \"iphoneos iphonesimulator macosx\";",
        "MACOSX_DEPLOYMENT_TARGET = 14.0;",
        # The macOS slice is built as a real app, not a Catalyst translation:
        # Catalyst would require the UIKit paths above to stay, which is the
        # opposite of the goal.
        "SUPPORTS_MACCATALYST = NO;",
    ]

    target_settings = [
        "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;",
        "CODE_SIGN_STYLE = Automatic;",
        "CURRENT_PROJECT_VERSION = 1;",
        "ENABLE_PREVIEWS = YES;",
        "GENERATE_INFOPLIST_FILE = YES;",
        f'INFOPLIST_KEY_CFBundleDisplayName = "{DISPLAY_NAME}";',
        'INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Poop Social uses your location to point you at the nearest throne when nature calls.";',
        'INFOPLIST_KEY_NSMicrophoneUsageDescription = "Poop Social uses the microphone only while you hold the dictate button, to turn your voice into text. Nothing is recorded or kept.";',
        'INFOPLIST_KEY_NSSpeechRecognitionUsageDescription = "Poop Social turns your dictated words into text so you can post hands-free. Your speech is processed for that transcript and not stored.";',
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;",
        "INFOPLIST_KEY_UILaunchScreen_Generation = YES;",
        'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";',
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = UIInterfaceOrientationPortrait;",
        "LD_RUNPATH_SEARCH_PATHS = (",
        "\t\"$(inherited)\",",
        "\t\"@executable_path/Frameworks\",",
        ");",
        "MARKETING_VERSION = 1.0;",
        f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};",
        'PRODUCT_NAME = "$(TARGET_NAME)";',
        "SWIFT_EMIT_LOC_STRINGS = YES;",
        "SWIFT_VERSION = 5.0;",
        'TARGETED_DEVICE_FAMILY = "1,2";',
    ]

    def emit_cfg(oid, name, extra):
        add(f"\t\t{oid} /* {name} */ = {{")
        add("\t\t\tisa = XCBuildConfiguration;")
        add("\t\t\tbuildSettings = {")
        for line in extra:
            add(f"\t\t\t\t{line}")
        add("\t\t\t};")
        add(f"\t\t\tname = {name};")
        add("\t\t};")

    add("/* Begin XCBuildConfiguration section */")
    emit_cfg(proj_debug, "Debug", common_proj + [
        "DEBUG_INFORMATION_FORMAT = dwarf;",
        "ENABLE_TESTABILITY = YES;",
        "GCC_DYNAMIC_NO_PIC = NO;",
        "GCC_OPTIMIZATION_LEVEL = 0;",
        "GCC_PREPROCESSOR_DEFINITIONS = (",
        "\t\"DEBUG=1\",",
        "\t\"$(inherited)\",",
        ");",
        "MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;",
        "ONLY_ACTIVE_ARCH = YES;",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS = \"DEBUG $(inherited)\";",
        "SWIFT_OPTIMIZATION_LEVEL = \"-Onone\";",
    ])
    emit_cfg(proj_release, "Release", common_proj + [
        "DEBUG_INFORMATION_FORMAT = \"dwarf-with-dsym\";",
        "ENABLE_NS_ASSERTIONS = NO;",
        "MTL_ENABLE_DEBUG_INFO = NO;",
        "SWIFT_COMPILATION_MODE = wholemodule;",
        "VALIDATE_PRODUCT = YES;",
    ])
    emit_cfg(tgt_debug, "Debug", target_settings)
    emit_cfg(tgt_release, "Release", target_settings)
    add("/* End XCBuildConfiguration section */")
    add("")

    # ---- XCConfigurationList ----------------------------------------------
    add("/* Begin XCConfigurationList section */")
    add(f"\t\t{proj_cfg_list} /* Build configuration list for PBXProject \"{PROJECT_NAME}\" */ = {{")
    add("\t\t\tisa = XCConfigurationList;")
    add("\t\t\tbuildConfigurations = (")
    add(f"\t\t\t\t{proj_debug} /* Debug */,")
    add(f"\t\t\t\t{proj_release} /* Release */,")
    add("\t\t\t);")
    add("\t\t\tdefaultConfigurationIsVisible = 0;")
    add("\t\t\tdefaultConfigurationName = Release;")
    add("\t\t};")
    add(f"\t\t{target_cfg_list} /* Build configuration list for PBXNativeTarget \"{TARGET_NAME}\" */ = {{")
    add("\t\t\tisa = XCConfigurationList;")
    add("\t\t\tbuildConfigurations = (")
    add(f"\t\t\t\t{tgt_debug} /* Debug */,")
    add(f"\t\t\t\t{tgt_release} /* Release */,")
    add("\t\t\t);")
    add("\t\t\tdefaultConfigurationIsVisible = 0;")
    add("\t\t\tdefaultConfigurationName = Release;")
    add("\t\t};")
    add("/* End XCConfigurationList section */")

    add("\t};")
    add(f"\trootObject = {project_obj} /* Project object */;")
    add("}")

    out = os.path.join(root, f"{PROJECT_NAME}.xcodeproj", "project.pbxproj")
    # The project directory may have been removed (e.g. regenerating from a
    # clean checkout), so create it rather than assuming it exists.
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w") as fh:
        fh.write("\n".join(L) + "\n")

    write_scheme(root)

    print(f"wrote {out}")
    print(f"  swift files : {len(swift_files)}")
    print(f"  asset cats  : {len(asset_catalogs)}")
    print(f"  groups      : {len(dirs)}")


def write_scheme(root):
    """Write a shared scheme for the app.

    Without a *shared* scheme on disk, `xcodebuild -scheme PoopSocial` falls
    back to an autocreated scheme that Xcode builds in memory. That implicit
    scheme is not guaranteed to include the app target in its Build Action,
    and during development it silently stopped compiling the app's Swift
    sources — which also starved the hosted unit tests of the app's
    `.swiftmodule`. An explicit scheme makes the build deterministic and lets
    Xcode 15 open the project with a working scheme out of the box.
    """
    scheme_dir = os.path.join(
        root, f"{PROJECT_NAME}.xcodeproj", "xcshareddata", "xcschemes"
    )
    os.makedirs(scheme_dir, exist_ok=True)
    path = os.path.join(scheme_dir, f"{PROJECT_NAME}.xcscheme")

    container = f"container:{PROJECT_NAME}.xcodeproj"

    xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1520"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{PROJECT_NAME}"
               BuildableName = "{PROJECT_NAME}.app"
               BlueprintName = "{PROJECT_NAME}"
               ReferencedContainer = "{container}">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{PROJECT_NAME}Tests"
               BuildableName = "{PROJECT_NAME}Tests.xctest"
               BlueprintName = "{PROJECT_NAME}Tests"
               ReferencedContainer = "{container}">
            </BuildableReference>
         </TestableReference>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{PROJECT_NAME}UITests"
               BuildableName = "{PROJECT_NAME}UITests.xctest"
               BlueprintName = "{PROJECT_NAME}UITests"
               ReferencedContainer = "{container}">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{PROJECT_NAME}"
            BuildableName = "{PROJECT_NAME}.app"
            BlueprintName = "{PROJECT_NAME}"
            ReferencedContainer = "{container}">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{PROJECT_NAME}"
            BuildableName = "{PROJECT_NAME}.app"
            BlueprintName = "{PROJECT_NAME}"
            ReferencedContainer = "{container}">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
'''
    with open(path, "w") as fh:
        fh.write(xml)
    print(f"wrote {path}")


if __name__ == "__main__":
    main()
