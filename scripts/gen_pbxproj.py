#!/usr/bin/env python3
"""Generate GlassStore.xcodeproj/project.pbxproj + shared scheme from the
source tree. Deterministic UUIDs (SHA-1 of target-relative path) so the file
is stable across regenerations.

Usage: python3 scripts/gen_pbxproj.py
Rerun whenever Swift files are added/removed under GlassStore/ or GlassStoreTests/.
"""
import hashlib
import os
from pathlib import Path

REPO = Path("/home/z/my-project/download/GlassStore")
APP_DIR = REPO / "GlassStore"
TESTS_DIR = REPO / "GlassStoreTests"
PROJ_DIR = REPO / "GlassStore.xcodeproj"
SCHEMES_DIR = PROJ_DIR / "xcshareddata" / "xcschemes"


def uuid_for(kind: str, path: str) -> str:
    raw = hashlib.sha1(f"GlassStore|{kind}|{path}".encode()).hexdigest()[:24].upper()
    return raw


def collect(root: Path, suffixes):
    """All files under root with given suffixes, as posix paths relative to repo."""
    out = []
    for p in sorted(root.rglob("*")):
        if p.is_file() and p.suffix.lower() in suffixes and ".xcassets" not in p.parts:
            out.append(p.relative_to(REPO).as_posix())
    return out


def group_for(path: str) -> str:
    """Parent group path for a file, e.g. GlassStore/Views/Today/x.swift -> GlassStore/Views/Today."""
    return "/".join(path.split("/")[:-1])


# ---------------------------------------------------------------- sources
app_swift = collect(APP_DIR, {".swift"})
test_swift = collect(TESTS_DIR, {".swift"})
test_resources = collect(TESTS_DIR, {".json"})
app_resources = ["GlassStore/Assets.xcassets"]
info_plist = "GlassStore/Info.plist"
icon_png = "GlassStore/Assets.xcassets/AppIcon.appiconset/AppIcon1024.png"

all_paths = app_swift + test_swift + test_resources + app_resources + [info_plist]

# Deterministic object IDs
pid = uuid_for("project", "GlassStore")                      # PBXProject
main_group = uuid_for("group", "main")
products_group = uuid_for("group", "Products")
app_target = uuid_for("target", "GlassStore")
tests_target = uuid_for("target", "GlassStoreTests")
app_product = uuid_for("product", "GlassStore.app")
tests_product = uuid_for("product", "GlassStoreTests.xctest")
container_proxy = uuid_for("proxy", "tests->app")
dep_tests_app = uuid_for("dep", "tests->app")
app_sources_phase = uuid_for("phase", "app-sources")
app_resources_phase = uuid_for("phase", "app-resources")
app_frameworks_phase = uuid_for("phase", "app-frameworks")
tests_sources_phase = uuid_for("phase", "tests-sources")
tests_resources_phase = uuid_for("phase", "tests-resources")
tests_frameworks_phase = uuid_for("phase", "tests-frameworks")
configlist_project = uuid_for("configlist", "project")
configlist_app = uuid_for("configlist", "GlassStore")
configlist_tests = uuid_for("configlist", "GlassStoreTests")
cfg = lambda label: uuid_for("config", label)

CONFIG_DEBUG_PROJECT = cfg("project-debug")
CONFIG_RELEASE_PROJECT = cfg("project-release")
CONFIG_DEBUG_APP = cfg("app-debug")
CONFIG_RELEASE_APP = cfg("app-release")
CONFIG_DEBUG_TESTS = cfg("tests-debug")
CONFIG_RELEASE_TESTS = cfg("tests-release")

# Build files
build_files = []  # (uuid, file_uuid, name, group_comment)
file_refs = {}    # path -> uuid


def file_uuid(path: str) -> str:
    if path not in file_refs:
        file_refs[path] = uuid_for("file", path)
    return file_refs[path]


def add_build_file(path: str, phase_owner: str):
    fu = file_uuid(path)
    bu = uuid_for(f"buildfile-{phase_owner}", path)
    build_files.append((bu, fu, Path(path).name, path))
    return bu


app_source_buids = [add_build_file(p, "app") for p in app_swift]
app_resource_buids = [add_build_file(p, "app-res") for p in app_resources]
test_source_buids = [add_build_file(p, "tests") for p in test_swift]
test_resource_buids = [add_build_file(p, "tests-res") for p in test_resources]

# File reference types
FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".json": "text.json",
    ".xcassets": "folder.assetcatalog",
    ".plist": "text.plist",
}

# ---------------------------------------------------------------- groups
# group path -> children (file paths or subgroup paths)
subgroups = {}


def ensure_group(path: str) -> str:
    if path in subgroups:
        return uuid_for("group", path)
    subgroups[path] = []
    parent = "/".join(path.split("/")[:-1])
    if parent:
        ensure_group(parent)  # create the whole chain first
        subgroups[parent].append(("group", path))
    return uuid_for("group", path)


for path in app_swift + [info_plist]:
    g = group_for(path)
    ensure_group(g)
    subgroups[g].append(("file", path))
ensure_group("GlassStore/Views")
for path in app_swift:
    g = group_for(path)
    if g not in subgroups:
        ensure_group(g)
        subgroups[g].append(("file", path))
subgroups.setdefault("GlassStore", [])
subgroups["GlassStore"].append(("file", "GlassStore/Assets.xcassets"))
subgroups["GlassStore"].append(("file", "GlassStore/Info.plist"))

ensure_group("GlassStoreTests")
for path in test_swift:
    subgroups["GlassStoreTests"].append(("file", path))
ensure_group("GlassStoreTests/Fixtures")
for path in test_resources:
    subgroups["GlassStoreTests/Fixtures"].append(("file", path))

# Every intermediate directory under GlassStore/Views/* etc. must exist as group
for path in list(subgroups):
    parts = path.split("/")
    for i in range(1, len(parts)):
        ensure_group("/".join(parts[:i]))

# ---------------------------------------------------------------- rendering


def xstr(s):
    return f'"{s}"' if (" " in s or "/" in s or "." in s) else s


lines = []
lines.append("// !$*UTF8*$!")
lines.append("{")
lines.append("\tarchiveVersion = 1;")
lines.append("\tobjectVersion = 56;")
lines.append("\tclasses = {")
lines.append("\t};")
lines.append("\tobjects = {")
lines.append("")

# PBXBuildFile
lines.append("/* Begin PBXBuildFile section */")
for bu, fu, name, path in build_files:
    lines.append(f"\t\t{bu} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fu} /* {name} */; }};")
lines.append("/* End PBXBuildFile section */")
lines.append("")

# PBXContainerItemProxy
lines.append("/* Begin PBXContainerItemProxy section */")
lines.append(f"\t\t{container_proxy} /* PBXContainerItemProxy */ = {{")
lines.append("\t\t\tisa = PBXContainerItemProxy;")
lines.append(f"\t\t\tcontainerPortal = {pid} /* Project object */;")
lines.append("\t\t\tproxyType = 1;")
lines.append(f"\t\t\tremoteGlobalIDString = {app_target};")
lines.append('\t\t\tremoteInfo = GlassStore;')
lines.append("\t\t};")
lines.append("/* End PBXContainerItemProxy section */")
lines.append("")

# PBXFileReference
lines.append("/* Begin PBXFileReference section */")
for path in all_paths:
    fu = file_uuid(path)
    ft = FILE_TYPES.get(Path(path).suffix.lower(), "text")
    if path == "GlassStore/Assets.xcassets":
        lines.append(f"\t\t{fu} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
    elif path.endswith(".app") or path.endswith(".xctest"):
        pass
    else:
        lines.append(f"\t\t{fu} /* {Path(path).name} */ = {{isa = PBXFileReference; lastKnownFileType = {ft}; path = {Path(path).name}; sourceTree = \"<group>\"; }};")
lines.append(f"\t\t{app_product} /* GlassStore.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = GlassStore.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
lines.append(f"\t\t{tests_product} /* GlassStoreTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = GlassStoreTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")
lines.append("/* End PBXFileReference section */")
lines.append("")

# PBXFrameworksBuildPhase
lines.append("/* Begin PBXFrameworksBuildPhase section */")
for phase, owner in ((app_frameworks_phase, "GlassStore"), (tests_frameworks_phase, "GlassStoreTests")):
    lines.append(f"\t\t{phase} /* Frameworks */ = {{")
    lines.append("\t\t\tisa = PBXFrameworksBuildPhase;")
    lines.append("\t\t\tbuildActionMask = 2147483647;")
    lines.append("\t\t\tfiles = (")
    lines.append("\t\t\t);")
    lines.append(f"\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    lines.append("\t\t};")
lines.append("/* End PBXFrameworksBuildPhase section */")
lines.append("")

# PBXGroup
lines.append("/* Begin PBXGroup section */")
lines.append(f"\t\t{main_group} = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{uuid_for('group', 'GlassStore')} /* GlassStore */,")
lines.append(f"\t\t\t\t{uuid_for('group', 'GlassStoreTests')} /* GlassStoreTests */,")
lines.append(f"\t\t\t\t{products_group} /* Products */,")
lines.append("\t\t\t);")
lines.append('\t\t\tsourceTree = "<group>";')
lines.append("\t\t};")
lines.append(f"\t\t{products_group} /* Products */ = {{")
lines.append("\t\t\tisa = PBXGroup;")
lines.append("\t\t\tchildren = (")
lines.append(f"\t\t\t\t{app_product} /* GlassStore.app */,")
lines.append(f"\t\t\t\t{tests_product} /* GlassStoreTests.xctest */,")
lines.append("\t\t\t);")
lines.append('\t\t\tname = Products;')
lines.append('\t\t\tsourceTree = "<group>";')
lines.append("\t\t};")

for gpath, children in sorted(subgroups.items()):
    if not gpath:
        continue
    gu = uuid_for("group", gpath)
    gname = gpath.split("/")[-1]
    lines.append(f"\t\t{gu} /* {gname} */ = {{")
    lines.append("\t\t\tisa = PBXGroup;")
    lines.append("\t\t\tchildren = (")
    for kind, target in children:
        if kind == "group":
            lines.append(f"\t\t\t\t{uuid_for('group', target)} /* {target.split('/')[-1]} */,")
        else:
            lines.append(f"\t\t\t\t{file_uuid(target)} /* {Path(target).name} */,")
    lines.append("\t\t\t);")
    lines.append(f'\t\t\tpath = {gname};')
    lines.append('\t\t\tsourceTree = "<group>";')
    lines.append("\t\t};")
lines.append("/* End PBXGroup section */")
lines.append("")

# PBXNativeTarget
lines.append("/* Begin PBXNativeTarget section */")
lines.append(f"\t\t{app_target} /* GlassStore */ = {{")
lines.append("\t\t\tisa = PBXNativeTarget;")
lines.append("\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget \"GlassStore\" */;" % configlist_app)
lines.append("\t\t\tbuildPhases = (")
lines.append(f"\t\t\t\t{app_sources_phase} /* Sources */,")
lines.append(f"\t\t\t\t{app_frameworks_phase} /* Frameworks */,")
lines.append(f"\t\t\t\t{app_resources_phase} /* Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\tbuildRules = (")
lines.append("\t\t\t);")
lines.append("\t\t\tdependencies = (")
lines.append("\t\t\t);")
lines.append("\t\t\tname = GlassStore;")
lines.append("\t\t\tpackageProductDependencies = (")
lines.append("\t\t\t);")
lines.append("\t\t\tproductName = GlassStore;")
lines.append(f"\t\t\tproductReference = {app_product} /* GlassStore.app */;")
lines.append("\t\t\tproductType = \"com.apple.product-type.application\";")
lines.append("\t\t};")
lines.append(f"\t\t{tests_target} /* GlassStoreTests */ = {{")
lines.append("\t\t\tisa = PBXNativeTarget;")
lines.append(f"\t\t\tbuildConfigurationList = %s /* Build configuration list for PBXNativeTarget \"GlassStoreTests\" */;" % configlist_tests)
lines.append("\t\t\tbuildPhases = (")
lines.append(f"\t\t\t\t{tests_sources_phase} /* Sources */,")
lines.append(f"\t\t\t\t{tests_frameworks_phase} /* Frameworks */,")
lines.append(f"\t\t\t\t{tests_resources_phase} /* Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\tbuildRules = (")
lines.append("\t\t\t);")
lines.append("\t\t\tdependencies = (")
lines.append(f"\t\t\t\t{dep_tests_app} /* PBXTargetDependency */,")
lines.append("\t\t\t);")
lines.append("\t\t\tname = GlassStoreTests;")
lines.append("\t\t\tpackageProductDependencies = (")
lines.append("\t\t\t);")
lines.append("\t\t\tproductName = GlassStoreTests;")
lines.append(f"\t\t\tproductReference = {tests_product} /* GlassStoreTests.xctest */;")
lines.append("\t\t\tproductType = \"com.apple.product-type.bundle.unit-test\";")
lines.append("\t\t};")
lines.append("/* End PBXNativeTarget section */")
lines.append("")

# PBXProject
lines.append("/* Begin PBXProject section */")
lines.append(f"\t\t{pid} /* Project object */ = {{")
lines.append("\t\t\tisa = PBXProject;")
lines.append(f"\t\t\tbuildConfigurationList = {configlist_project} /* Build configuration list for PBXProject \"GlassStore\" */;")
lines.append('\t\t\tcompatibilityVersion = "Xcode 14.0";')
lines.append('\t\t\tdevelopmentRegion = en;')
lines.append("\t\t\thasScannedForEncodings = 0;")
lines.append("\t\t\tknownRegions = (")
lines.append("\t\t\t\ten,")
lines.append("\t\t\t\tBase,")
lines.append("\t\t\t);")
lines.append(f"\t\t\tmainGroup = {main_group};")
lines.append(f"\t\t\tproductRefGroup = {products_group} /* Products */;")
lines.append('\t\t\tprojectDirPath = "";')
lines.append('\t\t\tprojectRoot = "";')
lines.append("\t\t\ttargets = (")
lines.append(f"\t\t\t\t{app_target} /* GlassStore */,")
lines.append(f"\t\t\t\t{tests_target} /* GlassStoreTests */,")
lines.append("\t\t\t);")
lines.append("\t\t\tTargetAttributes = {")
lines.append(f"\t\t\t\t{tests_target} = {{")
lines.append("\t\t\t\t\tCreatedOnToolsVersion = 26.0;")
lines.append(f"\t\t\t\t\tTestTargetID = {app_target};")
lines.append("\t\t\t\t};")
lines.append("\t\t\t};")
lines.append("\t\t};")
lines.append("/* End PBXProject section */")
lines.append("")

# PBXResourcesBuildPhase
lines.append("/* Begin PBXResourcesBuildPhase section */")
lines.append(f"\t\t{app_resources_phase} /* Resources */ = {{")
lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for bu, fu, name, path in build_files:
    if path in app_resources:
        lines.append(f"\t\t\t\t{bu} /* Assets.xcassets in Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append(f"\t\t{tests_resources_phase} /* Resources */ = {{")
lines.append("\t\t\tisa = PBXResourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for bu, fu, name, path in build_files:
    if path in test_resources:
        lines.append(f"\t\t\t\t{bu} /* {name} in Resources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXResourcesBuildPhase section */")
lines.append("")

# PBXSourcesBuildPhase
lines.append("/* Begin PBXSourcesBuildPhase section */")
lines.append(f"\t\t{app_sources_phase} /* Sources */ = {{")
lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for p, bu in zip(app_swift, app_source_buids):
    lines.append(f"\t\t\t\t{bu} /* {Path(p).name} in Sources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append(f"\t\t{tests_sources_phase} /* Sources */ = {{")
lines.append("\t\t\tisa = PBXSourcesBuildPhase;")
lines.append("\t\t\tbuildActionMask = 2147483647;")
lines.append("\t\t\tfiles = (")
for p, bu in zip(test_swift, test_source_buids):
    lines.append(f"\t\t\t\t{bu} /* {Path(p).name} in Sources */,")
lines.append("\t\t\t);")
lines.append("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
lines.append("\t\t};")
lines.append("/* End PBXSourcesBuildPhase section */")
lines.append("")

# PBXTargetDependency
lines.append("/* Begin PBXTargetDependency section */")
lines.append(f"\t\t{dep_tests_app} /* GlassStoreTests -> GlassStore */ = {{")
lines.append("\t\t\tisa = PBXTargetDependency;")
lines.append(f"\t\t\ttarget = {app_target} /* GlassStore */;")
lines.append(f"\t\t\ttargetProxy = {container_proxy} /* PBXContainerItemProxy */;")
lines.append("\t\t};")
lines.append("/* End PBXTargetDependency section */")
lines.append("")

PROJECT_DEBUG_SETTINGS = """\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCLANG_WARN__DUPLICATE_MATCHING_IS_DELETE = NO;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) DEBUG";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
"""

PROJECT_RELEASE_SETTINGS = """\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;
\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;
\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;
\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES;
\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;
\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;
\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;
\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;
\t\t\t\tLOCALIZATION_PREFERS_STRING_CATALOGS = YES;
\t\t\t\tMTL_ENABLE_DEBUG_INFO = NO;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tVALIDATE_PRODUCT = YES;
"""

APP_COMMON = """\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = GlassStore/Info.plist;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.glassstore.app;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
"""

APP_DEBUG_EXTRA = """\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) DEBUG";
"""

TESTS_COMMON = """\t\t\t\tBUNDLE_LOADER = "$(TEST_HOST)";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@loader_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.glassstore.tests;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = NO;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t\tTEST_HOST = "$(BUILT_PRODUCTS_DIR)/GlassStore.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/GlassStore";
"""

TESTS_DEBUG_EXTRA = """\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "$(inherited) DEBUG";
"""

# XCBuildConfiguration
lines.append("/* Begin XCBuildConfiguration section */")
lines.append(f"\t\t{CONFIG_DEBUG_PROJECT} /* Debug */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append(PROJECT_DEBUG_SETTINGS.rstrip("\n"))
lines.append("\t\t\t};")
lines.append('\t\t\tname = Debug;')
lines.append("\t\t};")
lines.append(f"\t\t{CONFIG_RELEASE_PROJECT} /* Release */ = {{")
lines.append("\t\t\tisa = XCBuildConfiguration;")
lines.append("\t\t\tbuildSettings = {")
lines.append(PROJECT_RELEASE_SETTINGS.rstrip("\n"))
lines.append("\t\t\t};")
lines.append('\t\t\tname = Release;')
lines.append("\t\t};")
for conf_id, name, settings, extra in (
    (CONFIG_DEBUG_APP, "Debug", APP_COMMON, APP_DEBUG_EXTRA),
    (CONFIG_RELEASE_APP, "Release", APP_COMMON, ""),
    (CONFIG_DEBUG_TESTS, "Debug", TESTS_COMMON, TESTS_DEBUG_EXTRA),
    (CONFIG_RELEASE_TESTS, "Release", TESTS_COMMON, ""),
):
    lines.append(f"\t\t{conf_id} /* {name} */ = {{")
    lines.append("\t\t\tisa = XCBuildConfiguration;")
    lines.append("\t\t\tbuildSettings = {")
    lines.append(settings.rstrip("\n"))
    if extra:
        lines.append(extra.rstrip("\n"))
    lines.append("\t\t\t};")
    lines.append(f'\t\t\tname = {name};')
    lines.append("\t\t};")
lines.append("/* End XCBuildConfiguration section */")
lines.append("")

# XCConfigurationList
lines.append("/* Begin XCConfigurationList section */")
lines.append(f"\t\t{configlist_project} /* Build configuration list for PBXProject \"GlassStore\" */ = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{CONFIG_DEBUG_PROJECT} /* Debug */,")
lines.append(f"\t\t\t\t{CONFIG_RELEASE_PROJECT} /* Release */,")
lines.append("\t\t\t);")
lines.append('\t\t\tdefaultConfigurationIsVisible = 0;')
lines.append('\t\t\tdefaultConfigurationName = Release;')
lines.append("\t\t};")
lines.append(f"\t\t{configlist_app} /* Build configuration list for PBXNativeTarget \"GlassStore\" */ = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{CONFIG_DEBUG_APP} /* Debug */,")
lines.append(f"\t\t\t\t{CONFIG_RELEASE_APP} /* Release */,")
lines.append("\t\t\t);")
lines.append('\t\t\tdefaultConfigurationIsVisible = 0;')
lines.append('\t\t\tdefaultConfigurationName = Release;')
lines.append("\t\t};")
lines.append(f"\t\t{configlist_tests} /* Build configuration list for PBXNativeTarget \"GlassStoreTests\" */ = {{")
lines.append("\t\t\tisa = XCConfigurationList;")
lines.append("\t\t\tbuildConfigurations = (")
lines.append(f"\t\t\t\t{CONFIG_DEBUG_TESTS} /* Debug */,")
lines.append(f"\t\t\t\t{CONFIG_RELEASE_TESTS} /* Release */,")
lines.append("\t\t\t);")
lines.append('\t\t\tdefaultConfigurationIsVisible = 0;')
lines.append('\t\t\tdefaultConfigurationName = Release;')
lines.append("\t\t};")
lines.append("/* End XCConfigurationList section */")
lines.append("")

lines.append("\t};")
lines.append(f"\trootObject = {pid} /* Project object */;")
lines.append("}")

out = PROJ_DIR / "project.pbxproj"
out.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"wrote {out} ({out.stat().st_size} bytes)")

# ---------------------------------------------------------------- scheme
scheme = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2600"
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
               BlueprintIdentifier = "{app_target}"
               BuildableName = "GlassStore.app"
               BlueprintName = "GlassStore"
               ReferencedContainer = "container:GlassStore.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{tests_target}"
               BuildableName = "GlassStoreTests.xctest"
               BlueprintName = "GlassStoreTests"
               ReferencedContainer = "container:GlassStore.xcodeproj">
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
            BlueprintIdentifier = "{app_target}"
            BuildableName = "GlassStore.app"
            BlueprintName = "GlassStore"
            ReferencedContainer = "container:GlassStore.xcodeproj">
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
            BlueprintIdentifier = "{app_target}"
            BuildableName = "GlassStore.app"
            BlueprintName = "GlassStore"
            ReferencedContainer = "container:GlassStore.xcodeproj">
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
"""
SCHEMES_DIR.mkdir(parents=True, exist_ok=True)
(SCHEMES_DIR / "GlassStore.xcscheme").write_text(scheme, encoding="utf-8")
print(f"wrote {SCHEMES_DIR / 'GlassStore.xcscheme'}")

print("targets:", len(app_swift), "app sources,", len(test_swift), "test sources,",
      len(test_resources), "fixtures")
