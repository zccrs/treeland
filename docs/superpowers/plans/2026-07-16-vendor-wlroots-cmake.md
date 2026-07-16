# Vendor wlroots 0.19.3 CMake Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Vendor wlroots 0.19.3 into `3rdparty/wlroots` as a CMake module that builds `libwaylib-wlroots.so` and replaces system `wlroots-0.19` for treeland / waylib / qwlroots without any C/C++ source changes.

**Architecture:** `git subtree` imports full upstream history at `3rdparty/wlroots`. A new CMakeLists mirrors meson 0.19.3 sources, wayland-scanner protocols, shader embed, and config headers. Target alias `Wlroots::wlroots` is linked from qwlroots / waylib / treeland modules. Only the shared library is installed.

**Tech Stack:** CMake 3.25+, C11, wayland-scanner, glslang, pkg-config system deps (not wlroots itself), treeland monorepo CMake.

## Global Constraints

- wlroots version pin: **0.19.3** only
- Do **not** use or invoke `meson.build`
- Do **not** delete upstream meson/docs/examples files
- Preserve full git history via `git subtree add` **without** `--squash`
- Shared library name: **`waylib-wlroots`** (`libwaylib-wlroots.so*`)
- Install **library only** — no headers, no `.pc`
- **No C/C++ changes** under `waylib/`, `qwlroots/`, `src/` (CMake only)
- Feature options default **ON**; soft deps (`libliftoff`, `xcb-errors`) may auto-disable
- Spec: `docs/superpowers/specs/2026-07-16-vendor-wlroots-cmake-design.md`

---

### Task 1: Subtree-vendor wlroots 0.19.3

**Files:**
- Create: `3rdparty/wlroots/**` (upstream tree via subtree)
- Modify: none yet

**Interfaces:**
- Consumes: none
- Produces: `3rdparty/wlroots/` at tag `0.19.3` with full history

- [ ] **Step 1: Confirm clean enough tree for subtree**

```bash
cd /home/zccrs/projects/treeland
git status -sb
test ! -e 3rdparty/wlroots
```

Expected: no existing `3rdparty/wlroots`; working tree may have unrelated untracked files — leave them alone.

- [ ] **Step 2: Ensure parent directory exists**

```bash
mkdir -p 3rdparty
```

- [ ] **Step 3: Add subtree with full history**

```bash
git subtree add --prefix=3rdparty/wlroots \
  https://gitlab.freedesktop.org/wlroots/wlroots.git 0.19.3
```

Expected: a merge commit bringing full wlroots history under `3rdparty/wlroots/`.  
If tag resolution fails, use commit `88a869855742281c98c22cab9641b317b8d065ef` instead of `0.19.3`.

- [ ] **Step 4: Verify tree and version**

```bash
test -f 3rdparty/wlroots/meson.build
grep -n "version: '0.19.3'" 3rdparty/wlroots/meson.build
ls 3rdparty/wlroots/include/wlr/config.h.in
git log --oneline 3rdparty/wlroots | head
```

Expected: version 0.19.3; many historical commits visible.

- [ ] **Step 5: No extra commit needed**

`git subtree add` already creates the vendor commit. Do not amend.

---

### Task 2: Scaffold CMake module skeleton + config headers

**Files:**
- Create: `3rdparty/wlroots/CMakeLists.txt`
- Create: `3rdparty/wlroots/cmake/WlrootsSources.cmake` (stub lists OK first)
- Create: `3rdparty/wlroots/cmake/WlrootsProtocols.cmake` (empty function stub)
- Create: `3rdparty/wlroots/cmake/WlrootsShaders.cmake` (empty function stub)

**Interfaces:**
- Consumes: system pkg-config deps
- Produces: target `waylib-wlroots` / alias `Wlroots::wlroots`; vars `WLROOTS_VERSION*` / `WLR_HAVE_*`

- [ ] **Step 1: Write `3rdparty/wlroots/CMakeLists.txt` skeleton**

Create a CMake file that:

1. `project` is **not** required if included as subdirectory; use:
   ```cmake
   cmake_minimum_required(VERSION 3.25)
   # When used as subdirectory of treeland, do not call project()
   set(WLROOTS_VERSION 0.19.3)
   set(WLROOTS_VERSION_MAJOR 0)
   set(WLROOTS_VERSION_MINOR 19)
   set(WLROOTS_VERSION_PATCH 3)
   ```
2. Declares all feature `option(...)` from the spec (defaults ON).
3. Finds always-required packages via PkgConfig:
   - `wayland-server>=1.23.1`, `libdrm>=2.4.122`, `xkbcommon`, `pixman-1>=0.43.0`, `wayland-protocols>=1.41`, `wayland-scanner`
4. Finds feature packages conditionally.
5. Detects endianness and sets `WLR_LITTLE_ENDIAN` / `WLR_BIG_ENDIAN`.
6. Generates:
   - `${CMAKE_CURRENT_BINARY_DIR}/include/wlr/config.h` from `include/wlr/config.h.in`  
     Map `#mesondefine WLR_HAS_FOO` → CMake `#cmakedefine01 WLR_HAS_FOO` by either:
     - writing a small CMake-native template, or
     - `configure_file` after transforming meson defines to `#cmakedefine01`.
   - `${CMAKE_CURRENT_BINARY_DIR}/include/wlr/version.h`
   - `${CMAKE_CURRENT_BINARY_DIR}/config.h` internal HAVE_* flags
7. Creates empty-ish library target first (will fill sources in Task 3–4):
   ```cmake
   add_library(waylib-wlroots SHARED)
   add_library(Wlroots::wlroots ALIAS waylib-wlroots)
   set_target_properties(waylib-wlroots PROPERTIES
     OUTPUT_NAME waylib-wlroots
     VERSION ${WLROOTS_VERSION}
     SOVERSION ${WLROOTS_VERSION_MAJOR}.${WLROOTS_VERSION_MINOR}
     C_STANDARD 11
     C_STANDARD_REQUIRED ON
     POSITION_INDEPENDENT_CODE ON
   )
   ```
8. Sets include dirs, compile defs, link libs, version-script, install rules per spec.
9. Exports to parent scope / CACHE:
   ```cmake
   set(WLROOTS_VERSION ${WLROOTS_VERSION} CACHE INTERNAL "")
   set(WLROOTS_VERSION_MAJOR 0 CACHE INTERNAL "")
   set(WLROOTS_VERSION_MINOR 19 CACHE INTERNAL "")
   set(WLROOTS_VERSION_PATCH 3 CACHE INTERNAL "")
   # WLR_HAVE_* as true/false strings suitable for #cmakedefine
   ```

**Important config.h generation detail:**

Upstream `config.h.in` uses `#mesondefine`. Prefer generating final headers with `file(WRITE)` / `configure_file` using a CMake template that emits:

```c
#define WLR_HAS_DRM_BACKEND 1
...
```

and version:

```c
#define WLR_VERSION_STR "0.19.3"
#define WLR_VERSION_MAJOR 0
#define WLR_VERSION_MINOR 19
#define WLR_VERSION_MICRO 3
```

Internal `config.h` (included as `"config.h"`) must define `HAVE_*` and `ICONDIR`.

- [ ] **Step 2: Export `WLR_HAVE_*` for qwlroots**

For each feature, set both:

```cmake
set(WLR_HAVE_DRM_BACKEND TRUE) # or FALSE — #cmakedefine needs defined/undefined
```

qwlroots `qwconfig.h.in` uses `#cmakedefine WLR_HAVE_DRM_BACKEND @WLR_HAVE_DRM_BACKEND@`.  
`#cmakedefine VAR @VAR@` requires either:

- `set(WLR_HAVE_DRM_BACKEND 1)` when enabled and `unset` when disabled, **or**
- match existing qwlroots expectation: currently pkg-config returns string `true`/`false` via `pkg_get_variable`, and those are substituted raw.

Check current qwlroots behavior after package: values become the strings from pkg-config (`true`/`false`). Preserve that:

```cmake
set(WLR_HAVE_DRM_BACKEND true)  # lowercase, when enabled
set(WLR_HAVE_DRM_BACKEND false) # when disabled
```

And ensure these variables are visible when qwlroots configures `qwconfig.h`.

- [ ] **Step 3: Install rules (lib only)**

```cmake
include(GNUInstallDirs)
install(TARGETS waylib-wlroots
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
```

Do not call `install(DIRECTORY include...)` or pkgconfig generate.

- [ ] **Step 4: Smoke-include the subdirectory alone**

Temporarily from a throwaway build or by adding only:

```cmake
add_subdirectory(3rdparty/wlroots)
```

at the top of treeland `CMakeLists.txt` (full wiring in Task 5). For this task, after writing skeleton with at least one dummy `.c` or a real small util file, configure:

```bash
cmake --preset default
```

Expected: configure finds deps; may fail link if no sources — minimum: add `util/log.c` temporarily to prove target exists.

Prefer moving straight to Task 3 if skeleton is incomplete without sources.

---

### Task 3: Protocol + shader codegen

**Files:**
- Modify: `3rdparty/wlroots/cmake/WlrootsProtocols.cmake`
- Modify: `3rdparty/wlroots/cmake/WlrootsShaders.cmake`
- Modify: `3rdparty/wlroots/CMakeLists.txt`

**Interfaces:**
- Consumes: `wayland-scanner`, `wayland-protocols` pkgdatadir, `glslang`
- Produces: generated protocol `.c/.h`, gles2 `*_src.h`, vulkan `*.h` attached to `waylib-wlroots`

- [ ] **Step 1: Implement protocol generation**

In `WlrootsProtocols.cmake`, define the full protocol map from `protocol/meson.build` (stable/staging/unstable + local xml under `protocol/`).

For each protocol name → xml path:

```cmake
add_custom_command(
  OUTPUT ${out_c} ${out_server_h}
  COMMAND ${WAYLAND_SCANNER} private-code ${xml} ${out_c}
  COMMAND ${WAYLAND_SCANNER} server-header ${xml} ${out_server_h}
  DEPENDS ${xml}
  VERBATIM
)
```

For client headers required by wayland backend:

```cmake
COMMAND ${WAYLAND_SCANNER} client-header ${xml} ${out_client_h}
```

Add all generated `.c` files to the library via `target_sources(waylib-wlroots PRIVATE ...)`.  
Add binary protocol dir to private includes.

- [ ] **Step 2: Implement GLES2 shader embed**

Reuse `render/gles2/shaders/embed.sh`:

```cmake
add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/shaders/gles2/${name_underscored}_src.h
  COMMAND ${CMAKE_COMMAND} -E make_directory ...
  COMMAND ${embed_sh} ${var} < ${shader_file} > ${output}
  DEPENDS ${shader_file} ${embed_sh}
)
```

Shaders: `common.vert`, `quad.frag`, `tex_rgba.frag`, `tex_rgbx.frag`, `tex_external.frag`.

Optional: run `glslang` as a check custom target (non-fatal or fatal matching meson).

- [ ] **Step 3: Implement Vulkan shader compile**

For each of `common.vert`, `texture.frag`, `quad.frag`, `output.frag`:

```bash
glslang -V input -o output.h --vn <name>_data [--quiet if supported]
```

Add outputs to `target_sources`.

- [ ] **Step 4: DRM pnpids generation**

```cmake
pkg_get_variable(HWDATA_DIR hwdata pkgdatadir)
add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/pnpids.c
  COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/backend/drm/gen_pnpids.sh
          < ${HWDATA_DIR}/pnp.ids > ${CMAKE_CURRENT_BINARY_DIR}/pnpids.c
  DEPENDS ...
)
```

Only when `WLROOTS_BACKEND_DRM` is ON.

---

### Task 4: Full source lists and feature wiring

**Files:**
- Modify: `3rdparty/wlroots/cmake/WlrootsSources.cmake`
- Modify: `3rdparty/wlroots/CMakeLists.txt`

**Interfaces:**
- Consumes: feature options + found deps
- Produces: complete `waylib-wlroots` that links and exports `wlr_*`

- [ ] **Step 1: Port source lists from 0.19.3 meson**

Populate `WlrootsSources.cmake` with explicit file lists from:

- `util/meson.build`
- `types/meson.build` (+ conditional `wlr_drm_lease_v1.c`)
- `xcursor/meson.build`
- `backend/meson.build` + multi/wayland/headless always
- `backend/drm|libinput|session|x11` conditional
- `render/meson.build` + pixman always; gles2/vulkan/allocator/color conditional
- `xwayland/meson.build` conditional

Use paths relative to `3rdparty/wlroots/`.

- [ ] **Step 2: Wire compile definitions and private includes**

Match meson:

```cmake
target_compile_definitions(waylib-wlroots PRIVATE
  _POSIX_C_SOURCE=200809L
  WLR_USE_UNSTABLE
  WLR_PRIVATE=
  WLR_LITTLE_ENDIAN=${...}
  WLR_BIG_ENDIAN=${...}
)
target_compile_definitions(waylib-wlroots PUBLIC WLR_USE_UNSTABLE)
```

Private include must allow:

- `#include <wlr/...>` public
- `#include <backend/...>` private headers under `include/`
- `#include "config.h"` from binary dir
- generated shader headers

- [ ] **Step 3: Link deps and version script**

```cmake
target_link_options(waylib-wlroots PRIVATE
  "-Wl,--version-script=${CMAKE_CURRENT_SOURCE_DIR}/wlroots.syms"
)
set_target_properties(waylib-wlroots PROPERTIES
  LINK_DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/wlroots.syms
)
```

- [ ] **Step 4: Build the library**

```bash
cmake --preset default
cmake --build --preset default --target waylib-wlroots -j$(nproc)
```

Expected: `build/**/libwaylib-wlroots.so.0.19.3` (path depends on preset).

- [ ] **Step 5: Verify symbols and NEEDED**

```bash
SO=$(find build -name 'libwaylib-wlroots.so*' | head -1)
nm -D "$SO" | grep -E 'wlr_backend_autocreate|wlr_renderer_autocreate' | head
readelf -d "$SO" | grep SONAME
```

Expected: SONAME `libwaylib-wlroots.so.0.19`; key `wlr_*` symbols present.

- [ ] **Step 6: Commit CMake module**

```bash
git add 3rdparty/wlroots/CMakeLists.txt 3rdparty/wlroots/cmake
git commit -m "$(cat <<'EOF'
build(wlroots): add CMake module for vendored waylib-wlroots

Build wlroots 0.19.3 with CMake as libwaylib-wlroots, without using
meson, installing only the shared library.

用 CMake 构建 vendored wlroots 0.19.3，产出 libwaylib-wlroots，
不使用 meson，且仅安装动态库。

Log: 添加 vendored wlroots 的 CMake 构建
Influence: 新增 3rdparty/wlroots CMake 目标，尚未切换下游依赖。
EOF
)"
```

---

### Task 5: Wire treeland / waylib / qwlroots to `Wlroots::wlroots`

**Files:**
- Modify: `CMakeLists.txt` (root)
- Modify: `qwlroots/src/CMakeLists.txt`
- Modify: `waylib/src/server/CMakeLists.txt`
- Modify: `src/modules/capture/CMakeLists.txt`
- Modify: `src/modules/shortcut/CMakeLists.txt`
- Modify: `src/modules/virtual-output/CMakeLists.txt`
- Modify: `src/modules/wallpaper-color/CMakeLists.txt`
- Modify: `src/modules/window-management/CMakeLists.txt`

**Interfaces:**
- Consumes: `Wlroots::wlroots`, `WLROOTS_VERSION*`, `WLR_HAVE_*`
- Produces: treeland build graph with no `PkgConfig::WLROOTS` for system wlroots

- [ ] **Step 1: Root CMakeLists**

Before `add_subdirectory(waylib)`:

```cmake
add_subdirectory(3rdparty/wlroots)
```

Remove:

```cmake
pkg_check_modules(WLROOTS REQUIRED IMPORTED_TARGET wlroots-0.19)
```

Keep `find_package(PkgConfig REQUIRED)` for other deps.

- [ ] **Step 2: qwlroots**

Replace the hard `pkg_check_modules(WLROOTS ...)` block with:

```cmake
if (TARGET Wlroots::wlroots)
    set(WLROOTS_TARGET Wlroots::wlroots)
    # WLROOTS_VERSION* and WLR_HAVE_* already set by 3rdparty/wlroots
    message(STATUS "Using vendored Wlroots::wlroots ${WLROOTS_VERSION}")
else()
    if (USE_WLROOTS_19)
        set(wlr wlroots-0.19)
        set(WLROOTS_MINIMUM_REQUIRED 0.19.0)
    else()
        set(wlr wlroots-0.18)
        set(WLROOTS_MINIMUM_REQUIRED 0.18.0)
    endif()
    pkg_check_modules(WLROOTS REQUIRED IMPORTED_TARGET ${wlr}>=${WLROOTS_MINIMUM_REQUIRED})
    pkg_get_variable(WLR_HAVE_DRM_BACKEND ${wlr} have_drm_backend)
    # ... keep existing pkg_get_variable list ...
    setup_package_version_variables(WLROOTS)
    set(WLROOTS_TARGET PkgConfig::WLROOTS)
endif()
```

Change link line:

```cmake
${WLROOTS_TARGET}
```

instead of `PkgConfig::WLROOTS`.

Do **not** edit any qwlroots `.cpp/.h`.

- [ ] **Step 3: waylib server**

```cmake
if (TARGET Wlroots::wlroots)
    set(WLROOTS_TARGET Wlroots::wlroots)
else()
    pkg_search_module(WLROOTS REQUIRED IMPORTED_TARGET wlroots-0.19)
    set(WLROOTS_TARGET PkgConfig::WLROOTS)
endif()
```

Replace `PkgConfig::WLROOTS` in `target_link_libraries` with `${WLROOTS_TARGET}`.

- [ ] **Step 4: treeland modules**

In the five module CMakeLists, replace `PkgConfig::WLROOTS` with `Wlroots::wlroots`.

- [ ] **Step 5: Full configure + build**

```bash
cmake --preset default
cmake --build --preset default -j$(nproc)
```

Expected: success (or only pre-existing unrelated failures).

- [ ] **Step 6: Verify no system wlroots link**

```bash
BIN=$(find build -type f -name treeland -perm -111 | head -1)
WAYLIB=$(find build -name 'libwaylibserver.so*' | head -1)
QWR=$(find build -name 'libqwlroots.so*' | head -1)
for f in "$BIN" "$WAYLIB" "$QWR"; do
  echo "== $f =="
  readelf -d "$f" | grep NEEDED
done
```

Expected: `libwaylib-wlroots.so.0.19` present; **no** `libwlroots-0.19.so`.

- [ ] **Step 7: Install tree smoke**

```bash
DEST=$(mktemp -d)
cmake --install build --prefix "$DEST"
find "$DEST" -name '*wlroots*' -o -name '*waylib-wlroots*'
test ! -d "$DEST/include/wlr"
test ! -f "$DEST/lib/pkgconfig/wlroots-0.19.pc"
ls "$DEST"/lib*/libwaylib-wlroots.so*
rm -rf "$DEST"
```

- [ ] **Step 8: Commit consumer wiring**

```bash
git add CMakeLists.txt qwlroots/src/CMakeLists.txt waylib/src/server/CMakeLists.txt \
  src/modules/capture/CMakeLists.txt src/modules/shortcut/CMakeLists.txt \
  src/modules/virtual-output/CMakeLists.txt src/modules/wallpaper-color/CMakeLists.txt \
  src/modules/window-management/CMakeLists.txt
git commit -m "$(cat <<'EOF'
build: switch treeland stack to vendored waylib-wlroots

Link qwlroots, waylib, and treeland modules against Wlroots::wlroots
instead of system wlroots-0.19, without changing C/C++ sources.

将 treeland/waylib/qwlroots 切换到 vendored waylib-wlroots，
C/C++ 源码保持不变。

Log: 切换到 vendored wlroots
Influence: 构建不再依赖系统 libwlroots-0.19，运行时加载 libwaylib-wlroots。
EOF
)"
```

---

### Task 6: Packaging + REUSE cleanup (light)

**Files:**
- Modify: `debian/control` (treeland root only, if present)
- Modify: `REUSE.toml` (add annotation for `3rdparty/wlroots/**`)

**Interfaces:**
- Consumes: none
- Produces: packaging metadata consistent with vendored lib

- [ ] **Step 1: Drop treeland build-dep on system wlroots if listed**

In root `debian/control`, remove `libwlroots-0.19-dev` from Build-Depends.  
Add any missing transitive build deps that were previously pulled transitively via wlroots-dev if configure fails (e.g. `libdisplay-info-dev`, `libliftoff-dev`, `libseat-dev`, `liblcms2-dev`, `hwdata`).

Do **not** change `qwlroots/debian` or `waylib/debian` unless required.

- [ ] **Step 2: REUSE annotation**

Add to `REUSE.toml`:

```toml
[[annotations]]
path = ["3rdparty/wlroots/**"]
precedence = "aggregate"
SPDX-FileCopyrightText = "wlroots contributors"
SPDX-License-Identifier = "MIT"
```

(Adjust if REUSE scan requires finer granularity; upstream also has other licenses in tree — prefer aggregate MIT matching upstream LICENSE, or use `LicenseRef` only if CI demands.)

- [ ] **Step 3: Commit**

```bash
git add debian/control REUSE.toml
git commit -m "$(cat <<'EOF'
chore: align packaging metadata with vendored wlroots

Drop system libwlroots-0.19-dev build dependency where applicable
and annotate the vendored tree for REUSE.

调整打包元数据以匹配 vendored wlroots，并补充 REUSE 标注。

Log: 更新 wlroots vendor 打包元数据
Influence: 打包构建依赖与许可证扫描路径更新，不影响源码逻辑。
EOF
)"
```

---

### Task 7: Final verification

**Files:** none (commands only)

- [ ] **Step 1: Clean configure/build**

```bash
cmake --preset default
cmake --build --preset default -j$(nproc)
```

- [ ] **Step 2: Unit tests that do not need DRM**

```bash
ctest --test-dir build --output-on-failure -R 'qwlroots|waylib' || true
# Prefer running known-safe tests:
ctest --test-dir build --output-on-failure -E 'manual|live'
```

Record which tests pass/fail. Failures pre-existing on master are OK if documented; **new** link/include failures are not.

- [ ] **Step 3: Confirm no C/C++ diffs**

```bash
git diff master -- 'waylib/**/*.cpp' 'waylib/**/*.h' 'waylib/**/*.c' \
  'qwlroots/**/*.cpp' 'qwlroots/**/*.h' 'qwlroots/**/*.c' \
  'src/**/*.cpp' 'src/**/*.h' 'src/**/*.c' | head
```

Expected: empty (only CMake/docs/vendor/cmake packaging changes on the branch relative to pre-work may exist; relative to Task start, no business C/C++).

- [ ] **Step 4: Summary checklist**

- [ ] `3rdparty/wlroots` exists with history
- [ ] `libwaylib-wlroots.so.0.19` built and installed
- [ ] headers / pc not installed
- [ ] treeland/waylib/qwlroots NEEDED uses waylib-wlroots
- [ ] no system `libwlroots-0.19` NEEDED
- [ ] no C/C++ business source edits

---

## Self-review (plan)

1. **Spec coverage:** subtree history, CMake-not-meson, lib-only install, name `waylib-wlroots`, consumer CMake wiring, feature options, no C/C++ changes — all mapped to Tasks 1–7.
2. **No placeholders:** source lists are directed to copy from concrete meson files; protocol/shader steps name tools and outputs.
3. **Type/name consistency:** target `waylib-wlroots`, alias `Wlroots::wlroots`, vars `WLR_HAVE_*` / `WLROOTS_VERSION*` match qwlroots and the design spec.
)