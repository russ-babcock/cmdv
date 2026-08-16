#!/bin/bash
# Runs `swift test` with the flags Swift Testing needs on a bare Command Line
# Tools install (no Xcode): CLT ships Testing.framework and its dependencies
# under Library/Developer/... rather than the standard /usr/lib/swift path
# Xcode installs populate, so both the module and its runtime dylibs need to be
# pointed at explicitly. If Xcode is ever installed, this wrapper is no longer
# needed — plain `swift test` will work.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CLT_FRAMEWORKS="/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
CLT_LIB="/Library/Developer/CommandLineTools/Library/Developer/usr/lib"

swift test \
    -Xswiftc -F -Xswiftc "$CLT_FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$CLT_FRAMEWORKS" \
    -Xlinker -rpath -Xlinker "$CLT_LIB" \
    "$@"
