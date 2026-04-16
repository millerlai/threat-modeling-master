#!/usr/bin/env sh
#
# install.sh — Install the threat-modeling Claude Code skill.
#
# Usage:
#   ./install.sh                     # install to user-level (~/.claude/skills/)
#   ./install.sh --user              # same as default
#   ./install.sh --project <path>    # install to <path>/.claude/skills/
#   ./install.sh --force             # overwrite existing installation
#   ./install.sh --help              # show help
#
# Works on Linux, macOS, and Windows (via Git Bash / WSL).

set -eu

SKILL_NAME="threat-modeling"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/.claude/skills/$SKILL_NAME"

SCOPE="user"
PROJECT_PATH=""
FORCE=0

print_help() {
    cat <<EOF
Install the threat-modeling Claude Code skill.

Usage:
  $0 [OPTIONS]

Options:
  --user                 Install at user level: ~/.claude/skills/$SKILL_NAME (default)
  --project <path>       Install at project level: <path>/.claude/skills/$SKILL_NAME
  --force                Overwrite existing installation without prompting
  -h, --help             Show this help

Examples:
  $0                                  # install for current user
  $0 --user --force                   # reinstall at user level
  $0 --project ~/my-app               # install into a specific project
EOF
}

# --- arg parsing -------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --user)
            SCOPE="user"
            shift
            ;;
        --project)
            SCOPE="project"
            if [ $# -lt 2 ]; then
                echo "ERROR: --project requires a path argument" >&2
                exit 2
            fi
            PROJECT_PATH="$2"
            shift 2
            ;;
        --force)
            FORCE=1
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            print_help >&2
            exit 2
            ;;
    esac
done

# --- resolve target dir ------------------------------------------------------
if [ "$SCOPE" = "user" ]; then
    TARGET_BASE="$HOME/.claude/skills"
else
    if [ ! -d "$PROJECT_PATH" ]; then
        echo "ERROR: project path does not exist: $PROJECT_PATH" >&2
        exit 2
    fi
    TARGET_BASE="$PROJECT_PATH/.claude/skills"
fi
TARGET_DIR="$TARGET_BASE/$SKILL_NAME"

# --- sanity check source -----------------------------------------------------
if [ ! -f "$SOURCE_DIR/SKILL.md" ]; then
    echo "ERROR: SKILL.md not found at: $SOURCE_DIR/SKILL.md" >&2
    echo "  Make sure you are running install.sh from the threat-modeling-master project root." >&2
    exit 1
fi
if [ ! -f "$SOURCE_DIR/threat_modeling_report_template.md" ]; then
    echo "ERROR: template not found at: $SOURCE_DIR/threat_modeling_report_template.md" >&2
    exit 1
fi

# --- overwrite protection ----------------------------------------------------
if [ -d "$TARGET_DIR" ] && [ "$FORCE" -ne 1 ]; then
    echo "ERROR: target directory already exists: $TARGET_DIR" >&2
    echo "  Re-run with --force to overwrite." >&2
    exit 1
fi

# --- install -----------------------------------------------------------------
echo "Installing $SKILL_NAME skill"
echo "  from: $SOURCE_DIR"
echo "  to:   $TARGET_DIR"

mkdir -p "$TARGET_BASE"
if [ -d "$TARGET_DIR" ]; then
    rm -rf "$TARGET_DIR"
fi
cp -r "$SOURCE_DIR" "$TARGET_DIR"

echo ""
echo "Installed successfully."
echo ""
echo "Files:"
ls -1 "$TARGET_DIR" | sed 's/^/  /'
echo ""
echo "Next steps:"
echo "  1. Verify the installation:   ./verify_install.sh ${SCOPE:+--$SCOPE}${PROJECT_PATH:+ $PROJECT_PATH}"
echo "  2. In Claude Code, ask:       \"use the threat-modeling skill to generate a report\""
