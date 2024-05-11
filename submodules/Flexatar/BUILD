load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")


load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
    "apple_resource_group",
)
load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

filegroup(
    name = "FlxMetalSources",
    srcs = glob([
        "Sources/**/*.metal",
        "Assets/**/*",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "FlexatarMetalSourcesBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.FlexatarMetalSources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>Flexatar</string>
    """
)

apple_resource_bundle(
    name = "FlexatarMetalSourcesBundle",
    infoplists = [
        ":FlexatarMetalSourcesBundleInfoPlist",
    ],
    resources = [
        ":FlxMetalSources",
    ],
)

swift_library(
    name = "Flexatar",
    module_name = "Flexatar",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":FlexatarMetalSourcesBundle",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/MergeLists:MergeLists",
        "//submodules/ComponentFlow:ComponentFlow",

      
    ],
    visibility = [
        "//visibility:public",
    ],
)
