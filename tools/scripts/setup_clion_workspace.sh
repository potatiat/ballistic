#!/bin/sh

if command -v git >/dev/null 2>&1; then
    PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || PROJECT_ROOT=""
fi

if [ -z "$PROJECT_ROOT" ] || [ ! -d "$PROJECT_ROOT" ]; then
    SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd) || SCRIPT_DIR=""
    if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/../.." ]; then
        PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
    else
        echo "Warning: Could not determine project root. Falling back to current directory."
        PROJECT_ROOT=$(pwd)
    fi
fi

RUN_DIR="$PROJECT_ROOT/.run"

if ! mkdir -p "$RUN_DIR" 2>/dev/null; then
    if [ ! -d "$RUN_DIR" ]; then
        echo "Error: Could not create $RUN_DIR and it does not exist."
        exit 1
    fi
fi

create_run_config() {
    name="$1"
    target="$2"
    args="$3"

    safe_name=$(printf '%s' "$name" | tr ' ' '_') || safe_name="$name"
    filename="$RUN_DIR/${safe_name}.run.xml"

    write_xml() {
        {
            cat <<EOF
<component name="ProjectRunConfigurationManager">
  <configuration default="false" name="$name" type="MAKEFILE_TARGET_RUN_CONFIGURATION" factoryName="Makefile">
    <makefile filename="\$PROJECT_DIR\$/Makefile" target="$target" workingDirectory="" arguments="$args">
      <envs />
    </makefile>
    <method v="2" />
  </configuration>
</component>
EOF
        } > "$1" 2>/dev/null
    }

    if write_xml "$filename"; then
        return 0
    fi

    echo "Warning: Direct write to $filename failed. Attempting recovery..."

    # Remove anything not alphanumeric, dash, or underscore)
    strict_name=$(printf '%s' "$name" | tr -cd 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-') || strict_name="config_$$"

    if [ -z "$strict_name" ]; then
        strict_name="config_$$"
    fi

    strict_filename="$RUN_DIR/${strict_name}.run.xml"

    if write_xml "$strict_filename"; then
        echo "Recovered: Wrote to sanitized filename $strict_filename"
        return 0
    fi

    # Fallback to current directory if .run is completely broken/unwritable
    fallback_filename="./${safe_name}.run.xml"

    if write_xml "$fallback_filename"; then
        echo "Recovered: Wrote to current directory as $fallback_filename (move it to $RUN_DIR/ manually)"
        return 0
    fi

    echo "Error: All recovery attempts failed for $name. Skipping."
    return 1
}

generate_configs() {
    failed=0
    total=0

    run_config() {
        total=$((total + 1))

        if ! create_run_config "$1" "$2" "$3"; then
            failed=$((failed + 1))
        fi
    }

    run_config "Ballistic All Build" "build-all" ""
    run_config "Ballistic All Clean" "clean-all" ""
    run_config "Ballistic All Configure" "configure-all" ""
    run_config "Ballistic Debug Build" "build" "BUILD_TYPE=Debug"
    run_config "Ballistic Debug Clean" "clean" "BUILD_TYPE=Debug"
    run_config "Ballistic Debug Configure" "configure" "BUILD_TYPE=Debug SANITIZER=General"
    run_config "Ballistic Debug Test" "test" "BUILD_TYPE=Debug"
    run_config "Ballistic Release Build" "build" "BUILD_TYPE=Release"
    run_config "Ballistic Release Clean" "clean" "BUILD_TYPE=Release"
    run_config "Ballistic Release Configure" "configure" "BUILD_TYPE=Release"
    run_config "Ballistic Release Test" "test" "BUILD_TYPE=Release"
    echo ""

    if [ "$failed" -gt 0 ]; then
        echo "Completed with warnings: $failed out of $total configurations failed to generate."
    else
        echo "Successfully generated all $total $RUN_DIR/ configurations."
    fi
}

generate_configs