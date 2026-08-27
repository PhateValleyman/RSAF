#!/usr/bin/env bash
set -euo pipefail

# Build RSAF directly in Termux on a Redmi Note 11.

readonly PROJECT_DIR="/home/phatevalleyman/RSAF"
readonly ENV_FILE="/home/phatevalleyman/redmi-env"
readonly TARGET_ABI="arm64-v8a"
readonly DEFAULT_BUILD_TYPE="debug"

read_env_value() {
	local name="$1"
	awk -F= -v key="$name" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$ENV_FILE"
}

load_path_from_snapshot() {
	local name="$1"
	local current="${!name:-}"
	if [[ -n "$current" ]]; then
		printf '%s' "$current"
		return
	fi
	read_env_value "$name"
}

fail() {
	printf 'build.sh: %s\n' "$1" >&2
	exit 1
}

[[ "$(uname -m)" == "aarch64" ]] || fail "Tento skript je určen pouze pro ARM64 (Redmi Note 11)."
[[ -d "$PROJECT_DIR" ]] || fail "Projekt neexistuje: $PROJECT_DIR"
[[ -x "$PROJECT_DIR/gradlew" ]] || fail "Gradle wrapper není spustitelný: $PROJECT_DIR/gradlew"
[[ -r "$ENV_FILE" ]] || fail "Chybí snapshot prostředí: $ENV_FILE"

export ANDROID_HOME="${ANDROID_HOME:-$(load_path_from_snapshot ANDROID_HOME)}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT:-$(load_path_from_snapshot ANDROID_NDK_ROOT)}"
export NDK="${NDK:-$ANDROID_NDK_ROOT}"
export JAVA_HOME="${JAVA_HOME:-$(load_path_from_snapshot JAVA_HOME)}"

[[ -d "$ANDROID_HOME" ]] || fail "Android SDK není dostupné: $ANDROID_HOME"
[[ -d "$ANDROID_NDK_ROOT" ]] || fail "Android NDK není dostupné: $ANDROID_NDK_ROOT"
[[ -x "$JAVA_HOME/bin/java" ]] || fail "Java není dostupná v JAVA_HOME: $JAVA_HOME"

java_version="$("$JAVA_HOME/bin/java" -version 2>&1 | sed -n '1s/.*version "\([^"]*\)".*/\1/p')"
java_major="${java_version%%.*}"
[[ "$java_major" =~ ^[0-9]+$ ]] || fail "Nelze zjistit verzi Javy."
(( java_major >= 21 )) || fail "RSAF vyžaduje JDK 21 nebo novější; nalezeno JDK $java_version."

build_type="${BUILD_TYPE:-$DEFAULT_BUILD_TYPE}"
case "$build_type" in
	debug|release) ;;
	*) fail "BUILD_TYPE musí být debug nebo release." ;;
esac

cd "$PROJECT_DIR"
./gradlew --no-daemon "-Prsaf.abis=$TARGET_ABI" "assemble${build_type^}"

printf 'APK je v: %s/app/build/outputs/apk/%s/%s/\n' \
	"$PROJECT_DIR" "$TARGET_ABI" "$build_type"
