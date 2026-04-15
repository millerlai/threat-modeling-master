#!/usr/bin/env sh
#
# verify_install.sh — Verify the threat-modeling Claude Code skill installation.
#
# Usage:
#   ./verify_install.sh                     # check user-level install
#   ./verify_install.sh --user              # same
#   ./verify_install.sh --project <path>    # check project-level install
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed
#   2 — argument error

set -u

SKILL_NAME="threat-modeling"

SCOPE="user"
PROJECT_PATH=""

print_help() {
    cat <<EOF
Verify the threat-modeling Claude Code skill installation.

Usage:
  $0 [OPTIONS]

Options:
  --user                 Check user-level install at ~/.claude/skills/$SKILL_NAME (default)
  --project <path>       Check project-level install at <path>/.claude/skills/$SKILL_NAME
  -h, --help             Show this help
EOF
}

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

if [ "$SCOPE" = "user" ]; then
    TARGET_DIR="$HOME/.claude/skills/$SKILL_NAME"
else
    TARGET_DIR="$PROJECT_PATH/.claude/skills/$SKILL_NAME"
fi

PASS=0
FAIL=0

check() {
    DESC="$1"
    RESULT="$2"
    if [ "$RESULT" -eq 0 ]; then
        echo "  [PASS] $DESC"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $DESC"
        FAIL=$((FAIL + 1))
    fi
}

echo "Verifying $SKILL_NAME skill at:"
echo "  $TARGET_DIR"
echo ""

# --- check 1: skill directory exists ----------------------------------------
if [ -d "$TARGET_DIR" ]; then
    check "skill directory exists" 0
else
    check "skill directory exists" 1
    echo ""
    echo "FAILED: skill is not installed. Run ./install.sh first." >&2
    exit 1
fi

# --- check 2: SKILL.md exists -----------------------------------------------
SKILL_FILE="$TARGET_DIR/SKILL.md"
if [ -f "$SKILL_FILE" ]; then
    check "SKILL.md exists" 0
else
    check "SKILL.md exists" 1
fi

# --- check 3: template exists -----------------------------------------------
TEMPLATE_FILE="$TARGET_DIR/threat_modeling_report_template.md"
if [ -f "$TEMPLATE_FILE" ]; then
    check "threat_modeling_report_template.md exists" 0
else
    check "threat_modeling_report_template.md exists" 1
fi

# --- check 4: SKILL.md has valid YAML frontmatter ---------------------------
if [ -f "$SKILL_FILE" ]; then
    FIRST_LINE=$(head -n 1 "$SKILL_FILE")
    if [ "$FIRST_LINE" = "---" ]; then
        check "SKILL.md starts with YAML frontmatter" 0
    else
        check "SKILL.md starts with YAML frontmatter" 1
    fi

    # find closing ---
    if awk 'NR>1 && /^---$/ {found=1; exit} END {exit !found}' "$SKILL_FILE"; then
        check "SKILL.md frontmatter is closed" 0
    else
        check "SKILL.md frontmatter is closed" 1
    fi

    # check for name field
    if awk '/^---$/{c++; next} c==1 && /^name:[[:space:]]*.+/' "$SKILL_FILE" | grep -q .; then
        check "SKILL.md frontmatter has name field" 0
    else
        check "SKILL.md frontmatter has name field" 1
    fi

    # check for description field
    if awk '/^---$/{c++; next} c==1 && /^description:[[:space:]]*.+/' "$SKILL_FILE" | grep -q .; then
        check "SKILL.md frontmatter has description field" 0
    else
        check "SKILL.md frontmatter has description field" 1
    fi

    # check name matches skill folder
    NAME_VALUE=$(awk '/^---$/{c++; next} c==1 && /^name:/{sub(/^name:[[:space:]]*/, ""); print; exit}' "$SKILL_FILE")
    if [ "$NAME_VALUE" = "$SKILL_NAME" ]; then
        check "SKILL.md name field matches folder ('$SKILL_NAME')" 0
    else
        check "SKILL.md name field matches folder (got: '$NAME_VALUE')" 1
    fi
fi

# --- check 5: template references work --------------------------------------
if [ -f "$SKILL_FILE" ] && [ -f "$TEMPLATE_FILE" ]; then
    if grep -q "threat_modeling_report_template.md" "$SKILL_FILE"; then
        check "SKILL.md references the template file" 0
    else
        check "SKILL.md references the template file" 1
    fi
fi

# --- check 6: template looks complete ---------------------------------------
if [ -f "$TEMPLATE_FILE" ]; then
    # spot-check: template should have the main section headers
    MISSING=0
    for H in "STRIDE" "DREAD" "MITRE" "攻擊樹" "資產識別" "信任邊界"; do
        if ! grep -q "$H" "$TEMPLATE_FILE"; then
            MISSING=1
            break
        fi
    done
    if [ "$MISSING" -eq 0 ]; then
        check "template contains all key sections (STRIDE/DREAD/MITRE/Attack Tree/Assets/Trust Boundaries)" 0
    else
        check "template contains all key sections" 1
    fi
fi

# --- summary -----------------------------------------------------------------
TOTAL=$((PASS + FAIL))
echo ""
echo "Result: $PASS/$TOTAL checks passed"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "FAILED: $FAIL check(s) did not pass. Re-run ./install.sh --force to repair." >&2
    exit 1
fi

echo ""
echo "All checks passed. The threat-modeling skill is ready to use."
echo ""
echo "Try it in Claude Code:"
echo "  \"use the threat-modeling skill to generate a Threat Modeling Report for this project\""
echo "  \"use the threat-modeling skill to analyze changes in the last 30 days\""
exit 0
