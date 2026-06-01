# XPF / Patchfind (iOS 26 / Darwin 25)

Standalone fork of [opa334/XPF](https://github.com/opa334/XPF) — kernel patchfinder used by jailbreak tooling (originally [Dopamine](https://github.com/opa334/Dopamine)). This repository contains **only** XPF + [ChOma](https://github.com/opa334/ChOma) (Mach-O / patchfinder primitives). No Dopamine app, exploits, or research trees.

## What this is

**XPF** (eXtended PatchFinder) scans a decompressed `kernelcache` and resolves kernel symbols/offsets into an XPC dictionary (`translation`, `trustcache`, `sandbox`, `physmap`, `struct`, `physrw`, optional `devmode`, `badRecovery`, etc.).

**ChOma** provides Mach-O parsing, section mapping, and ARM64 pattern/xref search (`PatchFinder`).

## Changes vs upstream XPF (this fork)

Patches validated against **iOS 26.2.1 (23C71)** kernel (A15 / fileset):

| Area | Change |
|------|--------|
| **Memory** | Unmap compressed kernel mapping after `kdecompress` — avoids ~2× RAM peak (jetsam during in-app patchfind). |
| **Sections** | `__TEXT_BOOT_EXEC` → `kernelBootTextSection` for Darwin 25+ boot-time finders. |
| **Darwin 25+** | `arm_vm_init`, `cpu_ttep`, `gPhysBase` via boot section when classic `__PPLTEXT` paths differ. |
| **PPL / trust cache** | `xpf_darwin25_no_ppltext()` — locate `ppl_trust_cache_rt` via `trust_cache_init` when `__PPLTEXT` is absent (iOS 26+). |
| **API** | `xpf_offset_dictionary_add_set_by_name()` for incremental set resolution (matches Dopamine jailbreak flow). |
| **Tooling** | `scripts/verify_kernel.sh` — smoke-test all core patchfinding sets on a local kernelcache. |

Upstream baseline: MIT, Copyright (c) 2024 Lars Fröder. Fork maintenance: see git history.

## Requirements

- macOS with Xcode command-line tools
- `clang`, `ldid` (iOS binaries)
- Optional: `kernelcache` from IPSW or device (`ipsw kernel extract`, libgrabkernel, etc.)

## Build

```bash
# macOS dylib + CLI test binary
make

# iOS dylib (arm64 + arm64e)
make output/ios/libxpf.dylib output/ios/xpf_test
```

ChOma is built **statically** into `libxpf` when `CHOMA_DYLIB_PATH=0` (default). To link against a prebuilt `libchoma.dylib`:

```bash
make -C external/ChOma TARGET=ios DISABLE_SIGNING=1 DISABLE_TESTS=1
make CHOMA_PATH=external/ChOma CHOMA_DYLIB_PATH=external/ChOma/output/ios/lib
```

### Initialize submodules

```bash
git submodule update --init --recursive
```

## Run patchfind (CLI)

```bash
make output/macos/xpf_test
DYLD_LIBRARY_PATH=output/macos ./output/macos/xpf_test /path/to/kernelcache
```

Prints `0x… <- symbol` lines and `kernelConstant.staticBase`.

## Verify (Dopamine-equivalent sets)

```bash
./scripts/verify_kernel.sh /path/to/kernelcache
```

Runs: `translation`, `trustcache`, `sandbox`, `physmap`, `struct`, `physrw`.

## Layout

```
.
├── Makefile              # builds libxpf + xpf_test (macOS / iOS)
├── LICENSE.md
├── external/ChOma/     # git submodule (opa334/ChOma)
├── src/                  # XPF sources
│   ├── xpf.c / xpf.h
│   ├── common.c          # struct / phys / sandbox metrics
│   ├── ppl.c             # PPL + trust cache (Darwin 25+ paths)
│   └── cli/main.c
└── scripts/
    └── verify_kernel.sh
```

## Integration

Link `libxpf.dylib` and include `src/xpf.h`. Typical flow:

1. `xpf_start_with_kernel_path(path)`
2. `xpf_construct_offset_dictionary(sets[])` or `xpf_offset_dictionary_add_set_by_name()` per set
3. Read offsets from returned `xpc_dictionary_t`
4. `xpf_stop()`

## Related projects

- [opa334/XPF](https://github.com/opa334/XPF) — upstream
- [opa334/ChOma](https://github.com/opa334/ChOma) — Mach-O / PatchFinder library
- [opa334/Dopamine](https://github.com/opa334/Dopamine) — jailbreak that embeds XPF (not included here)

## License

MIT — see [LICENSE.md](LICENSE.md). ChOma: see `external/ChOma/LICENSE`.
