# Threat Modeling Skill for Claude Code

English | [繁體中文](README.zh-TW.md)

A Claude Code skill that analyzes a project's source code and generates a professional **Threat Modeling Report** using industry-standard methodologies: **STRIDE** / **DREAD** / **MITRE ATT&CK** / **Attack Tree**.

Two modes are supported:

| Mode | Input | Output |
|---|---|---|
| **Full** | The whole project codebase | `Threat-Modeling-Report.md` (complete baseline report) |
| **Patch** | A git time range | `Threat-Modeling-Report-patch.md` (incremental analysis, optionally merged back into the main report) |

The report is written in the language you ask in. See [Report language](#report-language).

---

## Project structure

```
threat-modeling-master/
├── README.md                                         # This file (English)
├── README.zh-TW.md                                   # Traditional Chinese README
├── install.sh                                        # One-step install script
├── verify_install.sh                                 # Installation check script
├── threat_modeling_report_template.md                # Report template (authoritative copy)
└── .claude/
    └── skills/
        └── threat-modeling/
            ├── SKILL.md                              # Skill definition and instructions
            └── threat_modeling_report_template.md    # Template copy (keeps the skill self-contained)
```

The `.claude/skills/threat-modeling/` directory is the entire skill. The install script copies it into Claude Code's skills directory.

---

## Installation

### Option 1: `install.sh` (recommended)

**User-level install** (the skill is available in every project):

```sh
chmod +x ./install.sh
./install.sh
# or explicitly
./install.sh --user
```

This installs the skill to `~/.claude/skills/threat-modeling/`.

**Project-level install** (enabled for one project only):

```sh
./install.sh --project /path/to/your/project
```

This installs the skill to `<project>/.claude/skills/threat-modeling/`.

**Reinstall / overwrite an existing install**:

```sh
./install.sh --force
./install.sh --project /path/to/your/project --force
```

**Help**:

```sh
./install.sh --help
```

> **Windows users**: run these scripts in Git Bash or WSL, not CMD or PowerShell.

### Option 2: Manual install

If you'd rather not run the script, copy the directory yourself:

```sh
# User level
mkdir -p ~/.claude/skills
cp -r .claude/skills/threat-modeling ~/.claude/skills/

# Project level
mkdir -p /path/to/project/.claude/skills
cp -r .claude/skills/threat-modeling /path/to/project/.claude/skills/
```

---

## Verifying the installation

Use `verify_install.sh` to confirm the skill is installed correctly and can be loaded by Claude Code:

```sh
# Check the user-level install
chmod +x ./verify_install.sh
./verify_install.sh

# Check a project-level install
./verify_install.sh --project /path/to/your/project
```

The script checks that:

1. The skill directory exists
2. `SKILL.md` exists
3. `threat_modeling_report_template.md` exists
4. `SKILL.md` has valid YAML frontmatter (starts with `---` and is closed)
5. The frontmatter contains the required `name` and `description` fields
6. `name` equals `threat-modeling` (it must match the folder name)
7. `SKILL.md` references the template file
8. The template contains the key sections (STRIDE / DREAD / MITRE / Attack Tree / Assets / Trust Boundaries)

**Successful run**:

```
Verifying threat-modeling skill at:
  /c/Users/you/.claude/skills/threat-modeling

  [PASS] skill directory exists
  [PASS] SKILL.md exists
  [PASS] threat_modeling_report_template.md exists
  [PASS] SKILL.md starts with YAML frontmatter
  [PASS] SKILL.md frontmatter is closed
  [PASS] SKILL.md frontmatter has name field
  [PASS] SKILL.md frontmatter has description field
  [PASS] SKILL.md name field matches folder ('threat-modeling')
  [PASS] SKILL.md references the template file
  [PASS] template contains all key sections (STRIDE/DREAD/MITRE/Attack Tree/Assets/Trust Boundaries)

Result: 10/10 checks passed

All checks passed. The threat-modeling skill is ready to use.
```

Exit codes: `0` all checks passed, `1` at least one check failed, `2` argument error. Suitable for CI.

### Checking inside Claude Code

1. Open Claude Code in **any** project
2. Ask:

   ```
   List the skills that are currently available
   ```

   Claude should list `threat-modeling` (in every project for a user-level install; only in that project for a project-level install).

3. Run a smoke test (any existing project works):

   ```
   Use the threat-modeling skill to generate a threat modeling report for this project
   ```

   Claude reads the instructions in `SKILL.md` and starts analyzing the project.

---

## Usage examples

These examples assume Claude Code is open in the target project and the skill is installed (user or project level).

### Example 1: Full threat modeling report from scratch (Full mode)

```
Use the threat-modeling skill to generate a Threat Modeling Report for this project
```

Claude will:

1. Check whether `Threat-Modeling-Report.md` already exists in the project root (and ask before overwriting it)
2. Read the README, package manifests, Dockerfile, CI configuration, etc. to understand the tech stack
3. Inventory HTTP entry points, database queries, authentication logic, external API calls and dependencies (dispatching Explore subagents in parallel for medium and large projects)
4. Run a STRIDE analysis grounded in the actual code (every threat cites a concrete file path and line number)
5. Score each threat with DREAD
6. Draw a Mermaid architecture diagram and attack trees
7. Map threats to MITRE ATT&CK techniques
8. Assess existing security controls (e.g. helmet, bcrypt, csurf, prepared statements)
9. Write `Threat-Modeling-Report.md` to the **project root**

### Example 2: Analyze recent changes (Patch mode)

```
Use the threat-modeling skill to analyze code changes from the last 30 days and produce a patch report
```

Or with absolute dates:

```
Use the threat-modeling skill to analyze changes from 2026-01-01 to 2026-04-14
```

Or with a git revision range:

```
Use the threat-modeling skill to analyze the code changes between v1.2..v1.3
```

Claude will:

1. Convert the time range into git arguments (relative dates are resolved to absolute dates and recorded in the report)
2. Collect changes with `git log --name-status`, `--shortstat` and `-p`
3. Focus on **six kinds of security-relevant change**:
   - New attack surface (new routes / endpoints / input channels / file uploads / deserialization points)
   - Dependency changes (added, upgraded or removed packages)
   - Changes to authentication, authorization or cryptography logic
   - Data flow changes (new database queries / external API calls)
   - Configuration changes (Dockerfile, CI, CORS, CSP, security headers)
   - **Removed security controls** (especially important)
4. Write `Threat-Modeling-Report-patch.md` to the project root, with every finding citing a commit hash and file path
5. Ask whether to merge it if `Threat-Modeling-Report.md` already exists in the project root

### Example 3: Merge the patch into the main report

Continuing from Example 2, if you agree to merge:

```
Yes, merge it into the main report
```

Claude will:

- Bump the main report version (e.g. v1.0 → v1.1)
- Update the cover date and revision history
- Add new threats to Section 9, continuing the existing THR numbering
- Update the risk overview in Section 1.2, the risk matrix in Section 10 and the MITRE ATT&CK mapping in Section 12
- Update existing controls in Section 13 (a threat fixed by the patch is marked ✅ mitigated)
- Update mitigations in Section 14 and the follow-up action table in Section 18.2
- Write all new content in the main report's language
- **Never renumber existing THR entries or delete existing sections**
- Keep the patch file as change history

### Example 4: Choose the report language

```
Use the threat-modeling skill to generate a Threat Modeling Report for this project, written in Japanese
```

---

## Report language

The report is written in the language you ask in. The template itself is in Traditional Chinese; Claude translates it when generating other languages, so section wording can vary slightly between runs.

The language is decided in this order, first match wins:

1. A language you explicitly request (e.g. "write the report in English")
2. Patch mode: if `Threat-Modeling-Report.md` already exists in the project root, the patch report reuses its language so the main report and patches don't mix languages
3. A response language set in Claude Code's language setting or in `CLAUDE.md`
4. The language of your request
5. Traditional Chinese, if none of the above can be determined

Merging is the exception: content merged into the main report is always written in the main report's language, even if you asked for a different language in rule 1.

Whatever the language, these stay unchanged: IDs such as `THR-001` and `CTRL-01`, STRIDE / DREAD letters, MITRE ATT&CK technique IDs, file paths, code snippets, commit hashes, and output file names.

---

## Uninstalling

```sh
# User level
rm -rf ~/.claude/skills/threat-modeling

# Project level
rm -rf /path/to/project/.claude/skills/threat-modeling
```

---

## Safety principles

The skill follows these rules while analyzing code (they are written in `SKILL.md`):

- **Evidence only**: every threat must trace back to a real file path or commit. No invented CVE numbers, no imagined components.
- **Secrets handling**: real passwords, API keys or private keys found during analysis are **never written into the report**. Only their type and location are described, and the conclusion reminds you to rotate them immediately.
- **Non-destructive**: the skill only reads project files and git history, and only writes `Threat-Modeling-Report.md` or `Threat-Modeling-Report-patch.md` (merging edits the existing report section by section instead of overwriting it).

---

## Troubleshooting

**Q: Claude Code can't find the skill after installing**
- Make sure `verify_install.sh` passes
- Make sure Claude Code was started **after** the install. The skill list is usually loaded when a session starts, so restart Claude Code.
- For a project-level install, make sure your working directory is that project.

**Q: `install.sh: Permission denied`**
- Run `chmod +x install.sh verify_install.sh`

**Q: The scripts don't run in Windows CMD**
- Use Git Bash or WSL instead

**Q: Verification shows `[FAIL] SKILL.md frontmatter has name field`**
- The file may have an encoding issue (BOM) or `SKILL.md` was broken by a manual edit
- Run `./install.sh --force` to restore it

**Q: The patch report is almost empty**
- There were no security-relevant code changes in that range. This is expected: the skill deliberately doesn't pad the report.

**Q: The report isn't in the language I expected**
- If `Threat-Modeling-Report.md` already exists in the project root, Patch mode and merging reuse its language
- A response language set in `CLAUDE.md` or Claude Code's language setting takes priority over the language of your request
- Name the language in your request to override them, e.g. "write the report in English". Content merged into an existing main report still follows the main report's language.
