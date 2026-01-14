workspace(name = "reverb")

# To change to a version of protoc compatible with tensorflow:
#  1. Convert the required header version to a version string, e.g.:
#     3011004 => "3.11.4"
#  2. Calculate the sha256 of the binary:
#     PROTOC_VERSION="3.11.4"
#     curl -L "https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip" | sha256sum
#  3. Update the two variables below.
#
PROTOC_VERSION = "21.0"
PROTOC_SHA256 = "a2a92003da7b8c0c08aab530a3c1967d377c2777723482adb9d2eb38c87a9d5f"

PROTOC_SHA256_LINUX_X86_64 = PROTOC_SHA256
PROTOC_SHA256_DARWIN_ARM64 = "4cd865cfe59c18bdae7eaa08f2e18b2ddd29ef8d71602c90ab8ea402c5ba5555"

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "rules_cc",
    sha256 = "458b658277ba51b4730ea7a2020efdf1c6dcadf7d30de72e37f4308277fa8c01",
    strip_prefix = "rules_cc-0.2.16",
    url = "https://github.com/bazelbuild/rules_cc/releases/download/0.2.16/rules_cc-0.2.16.tar.gz",
)

http_archive(
    name = "bazel_features",
    sha256 = "a660027f5a87f13224ab54b8dc6e191693c554f2692fcca46e8e29ee7dabc43b",
    strip_prefix = "bazel_features-1.30.0",
    url = "https://github.com/bazel-contrib/bazel_features/releases/download/v1.30.0/bazel_features-v1.30.0.tar.gz",
)

http_archive(
    name = "upb",
    urls = [
        "https://storage.googleapis.com/grpc-bazel-mirror/github.com/protocolbuffers/upb/archive/60607da72e89ba0c84c84054d2e562d8b6b61177.tar.gz",
        "https://github.com/protocolbuffers/upb/archive/60607da72e89ba0c84c84054d2e562d8b6b61177.tar.gz",
    ],
    sha256 = "c0b97bf91dfea7e8d7579c24e2ecdd02d10b00f3c5defc3dce23d95100d0e664",
    strip_prefix = "upb-60607da72e89ba0c84c84054d2e562d8b6b61177",
    patches = [
        "//third_party/patches:upb_platforms.patch",
        "//third_party/patches:upb_no_pedantic_werror.patch",
    ],
    patch_args = ["-p1"],
)

http_archive(
    name = "zlib",
    urls = ["https://storage.googleapis.com/grpc-bazel-mirror/github.com/madler/zlib/archive/cacf7f1d4e3d44d871b605da3b647f07d718623f.tar.gz"],
    strip_prefix = "zlib-cacf7f1d4e3d44d871b605da3b647f07d718623f",
    sha256 = "6d4d6640ca3121620995ee255945161821218752b551a1a180f4215f7d124d45",
    build_file_content = """
package(default_visibility = ["//visibility:public"])

cc_library(
    name = "zlib",
    srcs = glob(["*.c"]),
    hdrs = glob(["*.h"]),
    includes = ["."],
    defines = ["ZLIB_CONST"],
)
""",
    patches = [
        "//third_party/patches:zlib_fdopen_undef.patch",
        "//third_party/patches:zlib_unistd_lseek.patch",
    ],
    patch_args = ["-p1"],
)

load("@bazel_features//:deps.bzl", "bazel_features_deps")

bazel_features_deps()

load(
    "//reverb/cc/platform/default:repo.bzl",
    "absl_deps",
    "cc_tf_configure",
    "github_apple_deps",
    "github_grpc_deps",
    "googletest_deps",
    "protoc_deps",
    "python_deps",
)

load("@rules_cc//cc:extensions.bzl", "compatibility_proxy_repo")
compatibility_proxy_repo()

googletest_deps()

absl_deps()

# Note that the Python dependencies are not tracked by bazel here, but
# in setup.py.

github_apple_deps()

## Begin GRPC related deps
github_grpc_deps()

load("@com_github_grpc_grpc//bazel:grpc_deps.bzl", "grpc_deps")

grpc_deps()

load("@com_github_grpc_grpc//bazel:grpc_extra_deps.bzl", "grpc_extra_deps")

grpc_extra_deps()


load("@upb//bazel:workspace_deps.bzl", "upb_deps")

upb_deps()

load(
    "@build_bazel_rules_apple//apple:repositories.bzl",
    "apple_rules_dependencies",
)

apple_rules_dependencies()

load(
    "@build_bazel_apple_support//lib:repositories.bzl",
    "apple_support_dependencies",
)

apple_support_dependencies()
## End GRPC related deps

load("@rules_cc//cc/private/toolchain:cc_configure.bzl", "cc_configure")
cc_configure()

cc_tf_configure()

python_deps()

protoc_deps(version = PROTOC_VERSION, sha256_darwin_arm64 = PROTOC_SHA256_DARWIN_ARM64)
