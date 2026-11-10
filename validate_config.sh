#!/bin/bash
# validate_config.sh - Validate the Cline MCP configuration template or the
# operator's own secrets file.
#
# Usage:
#   bazelisk test //:validate_config             # your .devcontainer/.env
#   bazelisk test //:validate_config_template    # the committed template
#   bazelisk test //:gate                        # the whole hermetic lane

echo " validating Cline MCP configuration..."
echo "================================================"

CONFIG_FILE=".devcontainer/.env"
TEMPLATE_MODE=false
ALLOWLIST="tools/bazel/secrets-allowlist.txt"

usage() {
    echo "Usage: validate_config.sh [--config-file PATH] [--template] [--allowlist PATH]"
}

# A value-taking flag has to be given a value. Reading $2 when it is absent and
# then shifting twice leaves the loop looking at the same argument forever, so a
# truncated command line hangs instead of failing.
require_value() {
    if [ "$1" -lt 2 ]; then
        echo "error: $2 requires a value"
        usage
        exit 2
    fi
}

while [ $# -gt 0 ]; do
    case "$1" in
        --config-file)
            require_value $# "--config-file"
            CONFIG_FILE="$2"
            shift 2
            ;;
        --template)
            TEMPLATE_MODE=true
            shift
            ;;
        --allowlist)
            require_value $# "--allowlist"
            ALLOWLIST="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            exit 2
            ;;
    esac
done

# Check config file exists
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "Error: Configuration file '${CONFIG_FILE}' not found!"
    if [ "${TEMPLATE_MODE}" = true ]; then
        echo "   The committed template is missing from the repository."
        exit 1
    fi
    echo "   Please create it by copying '.devcontainer/.env.example'"
    echo "   and filling in your actual values."
    exit 1
fi

echo "Configuration file found: ${CONFIG_FILE}"

# Check file permissions
if [ -r "${CONFIG_FILE}" ]; then
    echo "Configuration file is readable"
else
    echo "Error: Configuration file is not readable"
    exit 1
fi

# A template is committed at 644 by design; only a real secrets file is held to
# 600. The template lane checks content instead of mode.
if [ "${TEMPLATE_MODE}" != true ]; then
    PERMS=$(stat -c "%a" "${CONFIG_FILE}" 2>/dev/null || stat -f "%p" "${CONFIG_FILE}" 2>/dev/null | cut -c 4-6)
    if [ "${PERMS:-000}" -le 600 ]; then
        echo "Configuration file has secure permissions (${PERMS})"
    else
        echo "Error: Configuration file permissions (${PERMS}) are too permissive"
        echo "   Please run: chmod 600 ${CONFIG_FILE}"
        exit 1
    fi
fi

# Check for common required variables
REQUIRED_VARS=(
    "GH_TOKEN"
    "PERPLEXITY_API_KEY"
    "TAVILY_API_KEY"
    "MCP_MONGODB_URI"
    "REDIS_PWD"
    "SLACK_MCP_XOXC_TOKEN"
)

echo ""
echo "Checking for required configuration variables..."
missing=0
placeholder=0
secretlike=0
for var in "${REQUIRED_VARS[@]}"; do
    if grep -q "^${var}=" "${CONFIG_FILE}" 2>/dev/null; then
        # Check if variable is set (not empty)
        VALUE=$(grep "^${var}=" "${CONFIG_FILE}" | cut -d'=' -f2-)
        if [ -z "${VALUE}" ] || [ "${VALUE}" = "your_$(echo "${var}" | tr '[:upper:]' '[:lower:]')_here" ] || [ "${VALUE}" = "YOUR_${var}_HERE" ]; then
            echo "WARN  ${var} is a placeholder - please update it"
            placeholder=$((placeholder + 1))
        else
            echo "OK    ${var} is configured"
            if [ "${TEMPLATE_MODE}" = true ]; then
                # A committed template must never carry a value that could be a
                # real credential. Names only are ever printed.
                if grep -qE -- '-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|xox[bpars]-[0-9A-Za-z-]{20,}|AIza[0-9A-Za-z_-]{35}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.eyJ' "${CONFIG_FILE}"; then
                    echo "FAIL  ${var} carries a value that looks like a real credential"
                    secretlike=$((secretlike + 1))
                fi
            fi
        fi
    else
        echo "WARN  ${var} is not set in configuration file"
        missing=$((missing + 1))
    fi
done

# In template mode every required key must be present, because the template is
# the documentation of what an operator has to fill in.
if [ "${TEMPLATE_MODE}" = true ]; then
    if [ "${missing}" -gt 0 ]; then
        echo ""
        echo "Error: ${missing} required key(s) missing from the template"
        exit 1
    fi
    if [ "${secretlike}" -gt 0 ]; then
        echo ""
        echo "Error: ${secretlike} key(s) in the template carry credential-shaped values"
        echo "   Keep placeholders in .devcontainer/.env.example; real values belong"
        echo "   in .devcontainer/.env, which git never sees."
        exit 1
    fi
    if [ -f "${ALLOWLIST}" ]; then
        echo "Secrets allowlist in use: ${ALLOWLIST}"
    fi
    echo ""
    echo "================================================"
    echo "Template validation complete: all required keys present, no real values."
    exit 0
fi

echo ""
echo "================================================"
echo "Configuration validation complete!"
echo ""
echo "Next steps:"
echo "1. Make sure all sensitive values are properly set"
echo "2. Set secure file permissions: chmod 600 ${CONFIG_FILE}"
echo "3. Load configuration: export \$(grep -v '^#' ${CONFIG_FILE} | xargs)"
