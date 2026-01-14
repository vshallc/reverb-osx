#!/bin/bash
# Copyright 2019 The TensorFlow Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ==============================================================================
set -e

function build_wheel() {
  TMPDIR="$1"
  DESTDIR="$2"
  RELEASE_FLAG="$3"
  TF_VERSION_FLAG="$4"

  # Before we leave the top-level directory, make sure we know how to
  # call python.
  if [[ -e python_bin_path.sh ]]; then
    echo $(date)  "Setting PYTHON_BIN_PATH equal to what was set with configure.py."
    source python_bin_path.sh
  fi
  PYTHON_BIN_PATH=${PYTHON_BIN_PATH:-$(which python3)}

  pushd ${TMPDIR} > /dev/null

  echo $(date) : "=== Building wheel"
  if [[ "$(uname)" == "Darwin" ]]; then
    "${PYTHON_BIN_PATH}" setup.py bdist_wheel ${PKG_NAME_FLAG} ${RELEASE_FLAG} ${TF_VERSION_FLAG} > /dev/null
  else
    "${PYTHON_BIN_PATH}" setup.py bdist_wheel ${PKG_NAME_FLAG} ${RELEASE_FLAG} ${TF_VERSION_FLAG} --plat manylinux2014_x86_64 > /dev/null
  fi
  DEST=${TMPDIR}/dist/
  if [[ ! "$TMPDIR" -ef "$DESTDIR" ]]; then
    mkdir -p ${DESTDIR}
    cp dist/* ${DESTDIR}
    DEST=${DESTDIR}
  fi
  popd > /dev/null
  echo $(date) : "=== Output wheel file is in: ${DEST}"
}

function prepare_src() {
  TMPDIR="${1%/}"
  mkdir -p "$TMPDIR"

  echo $(date) : "=== Preparing sources in dir: ${TMPDIR}"

  if [ ! -d bazel-bin/reverb ]; then
    echo "Could not find bazel-bin.  Did you run from the root of the build tree?"
    exit 1
  fi

  RUNFILES=bazel-bin/reverb/pip_package/build_pip_package.runfiles/_main

  cp ${RUNFILES}/LICENSE ${TMPDIR}
  cp -L -R ${RUNFILES}/reverb ${TMPDIR}/reverb

  # Copy Bazel solib tree into the python package so dlopen can find it at runtime.
  if [ -d "${RUNFILES}/_solib_darwin_arm64" ]; then
    mkdir -p "${TMPDIR}/reverb/_solib_darwin_arm64"
    cp -L -R "${RUNFILES}/_solib_darwin_arm64/"* "${TMPDIR}/reverb/_solib_darwin_arm64/"
  fi
  # Make sure solib subdirs are treated consistently by packaging tools.
  if [ -d "${TMPDIR}/reverb/_solib_darwin_arm64" ]; then
    find "${TMPDIR}/reverb/_solib_darwin_arm64" -type d -exec sh -c 'test -f "$1/__init__.py" || : > "$1/__init__.py"' _ {} \;
  fi


  mv ${TMPDIR}/reverb/pip_package/setup.py ${TMPDIR}
  mv ${TMPDIR}/reverb/pip_package/MANIFEST.in ${TMPDIR}
  mv ${TMPDIR}/reverb/pip_package/reverb_version.py ${TMPDIR}

  # Copies README.md to temp dir so setup.py can use it as the long description.
  cp README.md ${TMPDIR}

  # TODO(b/155300149): Don't move .so files to the top-level directory.
  # This copies all .so files except for those found in the ops directory, which
  # must remain where they are for TF to find them.
  find "${TMPDIR}/reverb/cc" -type d -name ops -prune -o \( -name '*.so' -o -name '*.dylib' \) \
    -exec mv {} "${TMPDIR}/reverb" \;

  # Fix Mach-O deps to point to the wheel layout under reverb/_solib_darwin_arm64.
  # For each .so, rewrite any dep containing "_solib_darwin_arm64/" to the correct
  # @loader_path/<relative>/_solib_darwin_arm64/... based on the .so location.
  if command -v install_name_tool >/dev/null 2>&1; then
    find "${TMPDIR}/reverb" -name "*.so" -print0 | while IFS= read -r -d '' so; do
      so_dir="$(dirname "$so")"
      # Compute relative path from so_dir to ${TMPDIR}/reverb
      rel_to_reverb="$(python3 - <<PY
import os
print(os.path.relpath("${TMPDIR}/reverb", "${so_dir}"))
PY
)"
      # Normalize "." -> ""
      if [ "$rel_to_reverb" = "." ]; then rel_to_reverb=""; fi

      otool -L "$so" | awk '{print $1}' | grep '_solib_darwin_arm64/' | while read -r dep; do
        # Keep the tail starting from "_solib_darwin_arm64/..."
        tail="${dep#*@loader_path/}"
        tail="${tail#*/}"  # in case it was @loader_path/../...
        # Extract suffix from first occurrence of _solib_darwin_arm64
        suffix="$(echo "$dep" | sed -n 's#.*\(_solib_darwin_arm64/.*\)#\1#p')"
        [ -z "$suffix" ] && continue

        if [ -n "$rel_to_reverb" ]; then
          newdep="@loader_path/${rel_to_reverb}/${suffix}"
        else
          newdep="@loader_path/${suffix}"
        fi

        if [ "$dep" != "$newdep" ]; then
          echo "patching $so: $dep -> $newdep"
          install_name_tool -change "$dep" "$newdep" "$so" || true
        fi
      done
    done
  fi

}

function usage() {
  echo "Usage:"
  echo "$0 [options]"
  echo "  Options:"
  echo "    --release         build a release version"
  echo "    --dst             path to copy the .whl into."
  echo "    --tf-version      tensorflow version dependency passed to setup.py."
  echo ""
  exit 1
}

function main() {
  RELEASE_FLAG=""
  # Tensorflow version dependency passed to setup.py, e.g. tensorflow>=2.3.0.
  TF_VERSION_FLAG=""
  # This is where the source code is copied and where the whl will be built.
  DST_DIR=""

  while true; do
    if [[ "$1" == "--help" ]]; then
      usage
      exit 1
    elif [[ "$1" == "--release" ]]; then
      RELEASE_FLAG="--release"
    elif [[ "$1" == "--dst" ]]; then
      shift
      DST_DIR=$1
    elif [[ "$1" == "--tf-version" ]]; then
      shift
      TF_VERSION_FLAG="--tf-version $1"
    fi

    if [[ -z "$1" ]]; then
      break
    fi
    shift
  done

  TMPDIR="$(mktemp -d -t tmp.XXXXXXXXXX)"
  if [[ -z "$DST_DIR" ]]; then
    DST_DIR=${TMPDIR}
  fi

  prepare_src "$TMPDIR"
  build_wheel "$TMPDIR" "$DST_DIR" "$RELEASE_FLAG" "$TF_VERSION_FLAG"
}

main "$@"
