# Vendor wlroots 0.19.3 as CMake Module — Design Spec

**Date:** 2026-07-16  
**Status:** Approved for planning  
**Scope:** Vendor wlroots 0.19.3 into treeland at `3rdparty/wlroots` as an internal CMake module named `waylib-wlroots`.

## Problem

Treeland, waylib, and qwlroots currently depend on the system package `wlroots-0.19` via `pkg_check_modules` / `pkg_search_module` and link `PkgConfig::WLROOTS`. That couples the monorepo to distro packaging, risks version skew, and makes controlled feature builds harder.

## Goals

1. Vendor **wlroots 0.19.3** under `3rdparty/wlroots`.
2. Preserve the **full upstream git history** (git subtree, no squash).
3. Build with **CMake only** — do **not** use upstream `meson.build` (leave meson files in-tree; do not delete them).
4. Replace waylib / qwlroots / treeland wlroots dependency wiring with the vendored CMake target.
5. **Install only the shared library**; do **not** install headers or pkg-config files.
6. Expose all public headers via the CMake target so consumers can still `#include <wlr/...>`.
7. Shared library name: **`waylib-wlroots`** (`libwaylib-wlroots.so*`) to avoid colliding with system `libwlroots-0.19.so`.
8. **No C/C++ source changes** in waylib, qwlroots, or treeland. CMake wiring may change.
9. Feature set is **CMake-option configurable**, defaults **all on** (aligned with current system package capability).
10. Vendored wlroots is **mandatory** for treeland builds (no system-wlroots fallback at the treeland top level).

## Non-Goals

- Using or wrapping meson at build time.
- Deleting upstream meson / docs / examples / tinywl files.
- Upgrading beyond 0.19.3.
- Changing any waylib / qwlroots / treeland C/C++ API or call sites.
- Installing headers, `.pc` files, or CMake package config for wlroots.
- Fully redesigning qwlroots / waylib standalone packaging (optional follow-up).

## Decisions (locked)

| Topic | Decision |
|---|---|
| Integration method | Approach A: hand-written CMake that mirrors meson 0.19.3 sources/features |
| History | `git subtree add` without `--squash` |
| Always-on | Treeland always `add_subdirectory(3rdparty/wlroots)` |
| Consumer CMake | May change: link `Wlroots::wlroots` instead of `PkgConfig::WLROOTS` |
| Standalone qwlroots/waylib | Keep pkg-config fallback when `Wlroots::wlroots` is absent |
| Feature defaults | All major features ON |
| Library soname style | `OUTPUT_NAME waylib-wlroots`, `VERSION 0.19.3`, `SOVERSION 0.19` |

## Architecture

```text
treeland/
  3rdparty/
    wlroots/                      # subtree @ 0.19.3 + new CMake files
      CMakeLists.txt              # NEW
      cmake/                      # NEW helpers
        WlrootsSources.cmake
        WlrootsProtocols.cmake
        WlrootsShaders.cmake
      backend/ render/ types/ ... # upstream sources (unchanged)
      meson.build                 # kept, unused by treeland
  CMakeLists.txt                  # add_subdirectory(3rdparty/wlroots) first
  qwlroots/src/CMakeLists.txt     # prefer Wlroots::wlroots
  waylib/src/server/CMakeLists.txt
  src/modules/*/CMakeLists.txt    # link Wlroots::wlroots
```

Build flow:

1. Top-level CMake adds `3rdparty/wlroots` before waylib/qwlroots.
2. Module defines shared target `waylib-wlroots` and alias `Wlroots::wlroots`.
3. qwlroots / waylib / treeland modules link that target.
4. Include paths come from the target (`include/` + generated `wlr/config.h` / `wlr/version.h`).
5. Install step ships only `libwaylib-wlroots.so*`.

## CMake Module Design

### Target

| Property | Value |
|---|---|
| Target name | `waylib-wlroots` |
| Alias | `Wlroots::wlroots` |
| Type | `SHARED` only |
| `OUTPUT_NAME` | `waylib-wlroots` |
| `VERSION` | `0.19.3` |
| `SOVERSION` | `0.19` |
| C standard | C11 (match upstream) |

Compile definitions:

- Private: `_POSIX_C_SOURCE=200809L`, `WLR_USE_UNSTABLE`, `WLR_PRIVATE=`, `WLR_LITTLE_ENDIAN` / `WLR_BIG_ENDIAN`
- Public / interface: `WLR_USE_UNSTABLE` (consumers already rely on unstable APIs)

Include directories:

- **PUBLIC BUILD_INTERFACE:**  
  - `${CMAKE_CURRENT_SOURCE_DIR}/include`  
  - `${CMAKE_CURRENT_BINARY_DIR}/include` (generated `wlr/config.h`, `wlr/version.h`)
- **PRIVATE:**  
  - source `include/` private trees (`backend/`, `types/`, `render/`, …)  
  - binary dir for internal `config.h`, protocol outputs, shader headers
- **No INSTALL_INTERFACE include dirs** (headers are not installed)

Link:

- Always: `wayland-server`, `libdrm`, `xkbcommon`, `pixman-1`, `m`, `rt`
- Conditional: `egl`, `gbm`, `glesv2`, `vulkan`, `libinput`, `libseat`, `libudev`, `libdisplay-info`, `libliftoff`, `lcms2`, `wayland-client`, XCB family, `xwayland`, …
- Version script: `wlroots.syms` via `-Wl,--version-script=...`

Install:

```cmake
install(TARGETS waylib-wlroots
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
)
# Explicitly do NOT install headers or generate wlroots-0.19.pc
```

### Feature options (defaults ON)

```text
WLROOTS_BACKEND_DRM
WLROOTS_BACKEND_LIBINPUT
WLROOTS_BACKEND_X11
WLROOTS_RENDERER_GLES2
WLROOTS_RENDERER_VULKAN
WLROOTS_ALLOCATOR_GBM
WLROOTS_ALLOCATOR_UDMABUF
WLROOTS_SESSION
WLROOTS_XWAYLAND
WLROOTS_COLOR_MANAGEMENT
WLROOTS_LIBLIFTOFF          # soft: disable if missing
WLROOTS_XCB_ERRORS          # soft: disable if missing
```

Rules:

- If DRM or libinput is ON, session must be ON (else fatal).
- Hard features with missing deps → `FATAL_ERROR` when option is ON.
- Soft features (`libliftoff`, `xcb-errors`) auto-disable when not found.

### Generated files

| Output | Source / method |
|---|---|
| `include/wlr/config.h` | From `include/wlr/config.h.in` with `WLR_HAS_*` 0/1 |
| `include/wlr/version.h` | From `include/wlr/version.h.in` for 0.19.3 |
| internal `config.h` | `HAVE_*` flags: libliftoff, xcb-errors, eventfd, GBM APIs, xwayland features, `ICONDIR`, … |
| protocol `*-protocol.c/.h` | `wayland-scanner private-code` + `server-header` (client-header as needed for wayland backend) |
| GLES2 `*_src.h` | `render/gles2/shaders/embed.sh` |
| Vulkan `*.h` | `glslang -V --vn` |
| `pnpids.c` | `backend/drm/gen_pnpids.sh` + hwdata `pnp.ids` |

### Source list policy

- Mirror wlroots **0.19.3** `meson.build` file lists in CMake (static lists + conditionals).
- Do **not** parse meson at configure time.
- Always build: util, most of types, xcursor, core backend/render, all protocol gens.
- Conditional: drm / libinput / x11 / gles2 / vulkan / gbm / udmabuf / xwayland / color_lcms2 vs color_fallback / drm_lease / libliftoff.

### Variables exported for consumers

Replace pkg-config variables used by qwlroots:

```text
WLROOTS_VERSION=0.19.3
WLROOTS_VERSION_MAJOR=0
WLROOTS_VERSION_MINOR=19
WLROOTS_VERSION_PATCH=3
WLR_HAVE_DRM_BACKEND
WLR_HAVE_X11_BACKEND
WLR_HAVE_LIBINPUT_BACKEND
WLR_HAVE_XWAYLAND
WLR_HAVE_GLES2_RENDERER
WLR_HAVE_VULKAN_RENDERER
WLR_HAVE_GBM_ALLOCATOR
WLR_HAVE_SESSION
WLR_HAVE_COLOR_MANAGEMENT   # if qwlroots needs it later
```

Values must work with existing `qwconfig.h.in` (`#cmakedefine WLR_HAVE_*`).

## Consumer wiring

### treeland root `CMakeLists.txt`

- Add `add_subdirectory(3rdparty/wlroots)` **before** waylib.
- Remove `pkg_check_modules(WLROOTS REQUIRED IMPORTED_TARGET wlroots-0.19)`.

### qwlroots `src/CMakeLists.txt`

```cmake
if (TARGET Wlroots::wlroots)
  set(WLROOTS_TARGET Wlroots::wlroots)
  # use pre-set WLROOTS_VERSION / WLR_HAVE_* from vendored module
else()
  # standalone CI / external build
  pkg_check_modules(WLROOTS REQUIRED IMPORTED_TARGET ${wlr}>=...)
  pkg_get_variable(...)
  set(WLROOTS_TARGET PkgConfig::WLROOTS)
endif()

target_link_libraries(qwlroots PUBLIC ${WLROOTS_TARGET} ...)
```

No C/C++ or `qwconfig.h.in` changes.

### waylib `src/server/CMakeLists.txt`

Same pattern: prefer `Wlroots::wlroots`, else `pkg_search_module(... wlroots-0.19)`.

### treeland modules

Files that currently link `PkgConfig::WLROOTS`:

- `src/modules/capture/CMakeLists.txt`
- `src/modules/shortcut/CMakeLists.txt`
- `src/modules/virtual-output/CMakeLists.txt`
- `src/modules/wallpaper-color/CMakeLists.txt`
- `src/modules/window-management/CMakeLists.txt`

Change to `Wlroots::wlroots` (target always exists under treeland).

## Vendor procedure

```bash
git subtree add --prefix=3rdparty/wlroots \
  https://gitlab.freedesktop.org/wlroots/wlroots.git 0.19.3
```

- No `--squash` → full history retained.
- Pin tag **0.19.3**.
- Follow-up commit adds only CMake scaffolding under `3rdparty/wlroots/` (plus consumer CMake edits).

## Packaging notes (secondary)

- Treeland packaging should stop requiring `libwlroots-0.19-dev` once vendored build is the only path; runtime package should ship `libwaylib-wlroots.so*`.
- qwlroots / waylib debian metadata may keep system wlroots for standalone builds; out of primary scope unless touched for consistency.

## REUSE / licensing

- Upstream wlroots sources remain MIT (and other upstream licenses as present).
- New CMake files under `3rdparty/wlroots/cmake/` and root `CMakeLists.txt` edits follow treeland REUSE rules for CMake (`GPL-2.0-only` annotations already cover `**.cmake` / `CMakeLists.txt` paths where applicable).
- Add a REUSE annotation for `3rdparty/wlroots/**` if needed so license scan ignores or correctly attributes vendored tree.

## Verification

1. Configure with `cmake --preset default` succeeds; feature summary shows vendored wlroots 0.19.3.
2. Build targets: `waylib-wlroots`, `qwlroots`, `waylibserver`, treeland binaries.
3. `readelf -d` / `ldd` on treeland/waylib shows NEEDED `libwaylib-wlroots.so.0.19`, **not** `libwlroots-0.19.so`.
4. `nm -D libwaylib-wlroots.so` exports `wlr_*` symbols.
5. Install staging dir contains only the shared library for this module (no `include/wlr`, no `wlroots*.pc`).
6. Existing unit tests that do not need a live DRM session still pass.
7. Confirm no C/C++ diffs under `waylib/`, `qwlroots/`, `src/` except CMakeLists.

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| CMake source list drifts from meson on patch releases | Pin 0.19.3; document sync checklist for future bumps |
| Shader / protocol codegen mismatch | Reuse upstream scripts (`embed.sh`, `gen_pnpids.sh`) and same scanner args |
| Missing soft deps on CI images | Soft options auto-disable; hard options fail loudly |
| SO name / RPATH issues at runtime | Explicit `OUTPUT_NAME` + install into `${CMAKE_INSTALL_LIBDIR}`; same prefix as treeland |
| qwlroots standalone CI break | Keep pkg-config fallback when alias target missing |

## Implementation outline (for plan phase)

1. Subtree-add wlroots 0.19.3 into `3rdparty/wlroots`.
2. Author CMake module (sources, protocols, shaders, config headers, options, install).
3. Wire treeland root + qwlroots + waylib + modules to `Wlroots::wlroots`.
4. Build and verify linking/install artifacts.
5. Optional: adjust treeland `debian/control` build deps.
6. Commit in logical chunks (vendor tree, cmake module, consumer wiring).
)