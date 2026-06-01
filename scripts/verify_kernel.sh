#!/bin/bash
# Smoke-test core XPF patchfinding sets (same set list as Dopamine jailbreak path).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KC="${1:?usage: $0 /path/to/kernelcache}"

if [[ ! -f "$KC" ]]; then
	echo "kernelcache missing: $KC" >&2
	exit 1
fi

if [[ ! -d "$ROOT/external/ChOma/src" ]]; then
	echo "ChOma submodule missing — run: git submodule update --init --recursive" >&2
	exit 1
fi

make -C "$ROOT" CHOMA_PATH="$ROOT/external/ChOma" CHOMA_DYLIB_PATH=0 output/macos/libxpf.dylib >/dev/null
clang -O2 -framework Foundation \
	-I"$ROOT/external/ChOma/include" -I"$ROOT/src" \
	-L"$ROOT/output/macos" -lxpf -lcompression \
	-o /tmp/xpf_verify_sets -x c - <<'EOF'
#include <stdio.h>
#include "xpf.h"
static const char *sets[] = {
	"translation", "trustcache", "sandbox", "physmap", "struct", "physrw", NULL
};
int main(int argc, char **argv) {
	if (xpf_start_with_kernel_path(argv[1]) != 0) {
		fprintf(stderr, "xpf_start failed: %s\n", xpf_get_error());
		return 1;
	}
	int fail = 0;
	for (int i = 0; sets[i]; i++) {
		const char *one[] = { sets[i], NULL };
		xpc_object_t d = xpf_construct_offset_dictionary(one);
		if (d) {
			printf("[OK] %s\n", sets[i]);
			xpc_release(d);
		} else {
			fprintf(stderr, "[FAIL] %s: %s\n", sets[i], xpf_get_error() ? xpf_get_error() : "?");
			fail++;
		}
	}
	xpf_stop();
	return fail ? 1 : 0;
}
EOF
DYLD_LIBRARY_PATH="$ROOT/output/macos" /tmp/xpf_verify_sets "$KC"
echo "All core patchfinding sets passed."
