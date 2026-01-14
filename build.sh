#!/bin/zsh

export MACOSX_DEPLOYMENT_TARGET=11.0

bazelisk clean --expunge

python configure.py --force_defaults=True

mkdir -p bazel-repo-cache
mkdir -p bazel-distdir

# 如果遇到无法从 GitHub 自动下载的依赖，就手动下载放在 bazel-distdir 目录下

bazelisk build -c opt \
    --repository_cache=./bazel-repo-cache \
    --distdir=./bazel-distdir \
    --enable_bzlmod \
    --toolchain_resolution_debug=1 \
    --verbose_failures \
    --config=macos \
    //reverb/pip_package:build_pip_package

mkdir -p dist
./bazel-bin/reverb/pip_package/build_pip_package --dst $PWD/dist
ls -lh dist/*.whl
