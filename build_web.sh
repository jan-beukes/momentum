#!/bin/bash -eu

# Point this to where you installed emscripten. Optional on systems that already
# have `emcc` in the path.
EMSCRIPTEN_SDK_DIR="$HOME/Software/emsdk"
OUT_DIR="./"

mkdir -p $OUT_DIR

export EMSDK_QUIET=1
[[ -f "$EMSCRIPTEN_SDK_DIR/emsdk_env.sh" ]] && . "$EMSCRIPTEN_SDK_DIR/emsdk_env.sh"

# Note RAYLIB_WASM_LIB=env.o -- env.o is an internal WASM object file. You can
# see how RAYLIB_WASM_LIB is used inside <odin>/vendor/raylib/raylib.odin.

odin build web/ -target:js_wasm32 -build-mode:obj -define:RAYLIB_WASM_LIB=env.o -out:$OUT_DIR/game

ODIN_PATH=$(odin root)

files="$OUT_DIR/game.wasm.o ${ODIN_PATH}/vendor/raylib/wasm/libraylib.a"

# index_template.html contains the javascript code that calls the procedures in
# source/main_web/main_web.odin
flags="-sUSE_GLFW=3 -sWASM_BIGINT -sWARN_ON_UNDEFINED_SYMBOLS=0 -sASSERTIONS --shell-file web/index_template.html" 
#--preload-file assets

# For debugging: Add `-g` to `emcc` (gives better error callstack in chrome)
emcc -o $OUT_DIR/index.html $files $flags

rm $OUT_DIR/game.wasm.o

echo "Web build created in ${OUT_DIR}"
