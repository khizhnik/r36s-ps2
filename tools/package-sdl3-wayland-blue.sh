#!/usr/bin/env bash
set -euo pipefail

die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

require_file() {
	local path="$1"
	local label="${2:-file}"
	[[ -f "$path" ]] || die "missing ${label}: ${path}"
}

require_dir() {
	local path="$1"
	local label="${2:-directory}"
	[[ -d "$path" ]] || die "missing ${label}: ${path}"
}

sha256_of() {
	sha256sum "$1" | awk '{print $1}'
}

repo_root="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
build_root="$repo_root/build/sdl3-wayland-blue"
bundle_root="$repo_root/deploy/sdl3-wayland-blue"
smoke_lib_root="$repo_root/deploy/sdl3-wayland-smoke/lib"
support_lib_root="$repo_root/deploy/r36s-pcsx2-eerunner-smoke/lib"

binary_src="$build_root/bin/sdl3-wayland-blue"
sdl3_src="$repo_root/build/sdl3-wayland-rebuild/build/libSDL3.so.0.2.6"
expected_sdl3_sha="7c8e71e6ccfd2673f1a9e3181d422d623fdb5773e9dece02474ee7c93be1d731"

require_file "$binary_src" "built blue diagnostic"
require_file "$sdl3_src" "proven SDL3 shared library"
require_dir "$smoke_lib_root" "proven SDL3 Wayland runtime directory"
require_dir "$support_lib_root" "support runtime directory"

actual_sdl3_sha="$(sha256_of "$sdl3_src")"
[[ "$actual_sdl3_sha" == "$expected_sdl3_sha" ]] || die "unexpected SDL3 SHA256: $actual_sdl3_sha (expected $expected_sdl3_sha)"

rm -rf "$bundle_root"
mkdir -p "$bundle_root/bin" "$bundle_root/lib"

install -m 0755 "$binary_src" "$bundle_root/bin/sdl3-wayland-blue"
cp -a "$smoke_lib_root"/. "$bundle_root/lib/"
cp -a "$support_lib_root/libplutosvg.so.0" "$bundle_root/lib/"
cp -a "$support_lib_root/libplutovg.so.1" "$bundle_root/lib/"
install -m 0644 "$sdl3_src" "$bundle_root/lib/libSDL3.so.0.2.6"
ln -sfn libSDL3.so.0.2.6 "$bundle_root/lib/libSDL3.so.0"
ln -sfn libSDL3.so.0 "$bundle_root/lib/libSDL3.so"

for link in libSDL3.so libSDL3.so.0 libSDL3.so.0.2.6; do
	target="$(readlink -f "$bundle_root/lib/$link")"
	[[ "$target" == "$bundle_root/lib/libSDL3.so.0.2.6" ]] || die "SDL3 symlink mismatch for $link -> $target"
done

bundle_sdl3_sha="$(sha256_of "$bundle_root/lib/libSDL3.so.0.2.6")"
[[ "$bundle_sdl3_sha" == "$expected_sdl3_sha" ]] || die "packaged SDL3 SHA256 mismatch: $bundle_sdl3_sha"

cat >"$bundle_root/launch.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LD_LIBRARY_PATH="${bundle_dir}/lib"
exec "${bundle_dir}/bin/sdl3-wayland-blue" "$@"
EOF
chmod 0755 "$bundle_root/launch.sh"

cat >"$bundle_root/diagnostic.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

bundle_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
binary="${bundle_dir}/bin/sdl3-wayland-blue"

printf 'bundle_dir=%s\n' "$bundle_dir"
printf 'binary=%s\n' "$binary"
printf 'sha256(binary)=%s\n' "$(sha256sum "$binary" | awk '{print $1}')"
printf 'sha256(SDL3)=%s\n' "$(sha256sum "${bundle_dir}/lib/libSDL3.so.0.2.6" | awk '{print $1}')"
printf '\n'
LD_LIBRARY_PATH="${bundle_dir}/lib" ldd "$binary" || true
EOF
chmod 0755 "$bundle_root/diagnostic.sh"

manifest_tmp="$(mktemp /tmp/sdl3-wayland-blue-manifest.XXXXXX)"
{
	printf 'path\ttype\tsize\tsha256\tsymlink_target\n'
	while IFS= read -r -d '' rel; do
		path="$bundle_root/$rel"
		if [[ -L "$path" ]]; then
			printf '%s\tsymlink\t%s\t-\t%s\n' \
				"$rel" \
				"$(stat -c '%s' "$path")" \
				"$(readlink "$path")"
		elif [[ -f "$path" ]]; then
			printf '%s\tfile\t%s\t%s\t-\n' \
				"$rel" \
				"$(stat -c '%s' "$path")" \
				"$(sha256sum "$path" | awk '{print $1}')"
		fi
	done < <(cd "$bundle_root" && find . -mindepth 1 -printf '%P\0' | sort -z)
} >"$manifest_tmp"
mv "$manifest_tmp" "$bundle_root/MANIFEST.txt"

printf 'Packaged bundle: %s\n' "$bundle_root"
printf 'SDL3 SHA256: %s\n' "$bundle_sdl3_sha"
printf 'Binary SHA256: %s\n' "$(sha256_of "$bundle_root/bin/sdl3-wayland-blue")"
