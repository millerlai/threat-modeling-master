# Threat Modeling Skill for Claude Code

[English](README.md) | 繁體中文

一個 Claude Code skill，用於自動分析專案原始碼並產生專業的 **Threat Modeling Report**。方法論採用業界標準：**STRIDE** / **DREAD** / **MITRE ATT&CK** / **Attack Tree**。

支援兩種執行模式：

| 模式 | 輸入 | 輸出 |
|---|---|---|
| **Full** | 整個專案 codebase | `Threat-Modeling-Report.md`（完整基準報告） |
| **Patch** | 指定 git 時間區間 | `Threat-Modeling-Report-patch.md`（增量分析，可選擇合併回主報告） |

報告會以你提問的語言撰寫，詳見[報告語言](#報告語言)。

---

## 專案結構

```
threat-modeling-master/
├── README.md                                         # 英文說明
├── README.zh-TW.md                                   # 本檔案（繁體中文說明）
├── install.sh                                        # 一鍵安裝腳本
├── verify_install.sh                                 # 安裝驗證腳本
├── threat_modeling_report_template.md                # 報告範本（權威版）
└── .claude/
    └── skills/
        └── threat-modeling/
            ├── SKILL.md                              # Skill 定義與執行指引
            └── threat_modeling_report_template.md    # 範本副本（skill 自包含）
```

其中 `.claude/skills/threat-modeling/` 整個目錄就是這個 skill 的完整內容，安裝腳本會把它複製到 Claude Code 的 skills 目錄。

---

## 安裝

### 方法一：使用 `install.sh`（推薦）

**使用者層級安裝**（所有專案都能用此 skill）：

```sh
chmod +x ./install.sh
./install.sh
# 或顯式指定
./install.sh --user
```

會把 skill 安裝到 `~/.claude/skills/threat-modeling/`。

**專案層級安裝**（只在某個特定專案中啟用）：

```sh
./install.sh --project /path/to/your/project
```

會把 skill 安裝到 `<project>/.claude/skills/threat-modeling/`。

**重新安裝 / 覆蓋既有版本**：

```sh
./install.sh --force
./install.sh --project /path/to/your/project --force
```

**查看說明**：

```sh
./install.sh --help
```

> **Windows 使用者**：請在 Git Bash 或 WSL 中執行這些腳本。不要用 CMD 或 PowerShell。

### 方法二：手動安裝

若不想跑腳本也可以直接複製：

```sh
# 使用者層級
mkdir -p ~/.claude/skills
cp -r .claude/skills/threat-modeling ~/.claude/skills/

# 專案層級
mkdir -p /path/to/project/.claude/skills
cp -r .claude/skills/threat-modeling /path/to/project/.claude/skills/
```

---

## 驗證安裝

用 `verify_install.sh` 確認 skill 正確安裝並可被 Claude Code 載入：

```sh
# 驗證使用者層級安裝
chmod +x ./verify_install.sh
./verify_install.sh

# 驗證專案層級安裝
./verify_install.sh --project /path/to/your/project
```

腳本會檢查：

1. Skill 目錄是否存在
2. `SKILL.md` 是否存在
3. `threat_modeling_report_template.md` 是否存在
4. `SKILL.md` 是否有合法的 YAML frontmatter（開頭 `---`、正確閉合）
5. Frontmatter 是否包含必要的 `name` 與 `description` 欄位
6. `name` 欄位是否等於 `threat-modeling`（必須與資料夾名一致）
7. `SKILL.md` 是否有引用到範本檔
8. 範本是否包含主要章節（STRIDE / DREAD / MITRE / 攻擊樹 / 資產識別 / 信任邊界）

**成功範例**：

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

退出碼：`0` 全部通過、`1` 有檢查失敗、`2` 參數錯誤。可直接用於 CI。

### 進一步在 Claude Code 中驗證

1. 開啟 Claude Code 並進入**任何**專案
2. 輸入：

   ```
   請列出目前可用的 skills
   ```

   Claude 應該會列出 `threat-modeling`（若為使用者層級安裝，則在所有專案都看得到；專案層級則只在該專案看得到）。

3. 試跑一個 smoke test（任何已存在的專案都行）：

   ```
   請用 threat-modeling skill 幫這個專案產生 threat modeling report
   ```

   Claude 會讀取 `SKILL.md` 的指引並開始分析專案。

---

## 使用範例

以下範例假設你已在某個目標專案中開啟 Claude Code，且 skill 已安裝（使用者層級或專案層級皆可）。

### 範例 1：從零產出完整威脅建模報告（Full 模式）

```
請用 threat-modeling skill 幫我產生這個專案的 Threat Modeling Report
```

Claude 會：

1. 先檢查專案根目錄是否已有 `Threat-Modeling-Report.md`（若有會先詢問是否覆蓋）
2. 讀取 README、package manifest、Dockerfile、CI 設定等，理解專案技術棧
3. 盤點 HTTP 入口、DB 查詢、認證邏輯、外部 API 呼叫、依賴清單（中大型專案會平行派發 Explore subagent）
4. 依據實際程式碼證據執行 STRIDE 分析（每條威脅都會引用具體檔案路徑 + 行號）
5. 以 DREAD 評分每個威脅
6. 繪製 Mermaid 架構圖與 Attack Tree
7. 對應到 MITRE ATT&CK Technique
8. 評估既有的安全控制（例如是否用了 helmet、bcrypt、csurf、prepared statement 等）
9. 產出 `Threat-Modeling-Report.md` 到**專案根目錄**

### 範例 2：分析近期變更（Patch 模式）

```
請用 threat-modeling skill 分析最近 30 天的 code change，產生 patch report
```

或用絕對日期：

```
請用 threat-modeling skill 分析 2026-01-01 到 2026-04-14 的變更
```

或用 git revision range：

```
請用 threat-modeling skill 分析 v1.2..v1.3 之間的 code change
```

Claude 會：

1. 轉換時間區間為 git 參數（相對日期會換算為絕對日期並在報告中記錄）
2. 執行 `git log --name-status`、`--shortstat`、`-p` 蒐集變更
3. 聚焦**六類有安全意義的變更**：
   - 新增的攻擊面（新路由 / 新端點 / 新輸入管道 / 新檔案上傳 / 新反序列化點）
   - 依賴變動（新增、升級、移除的套件）
   - 認證 / 授權 / 加密邏輯變動
   - 資料流變動（新的 DB 查詢 / 外部 API 呼叫）
   - 設定變動（Dockerfile、CI、CORS、CSP、security header）
   - **被移除的安全控制**（特別重要）
4. 產出 `Threat-Modeling-Report-patch.md` 到專案根目錄，每條 finding 都會引用 commit hash + 檔案路徑
5. 若專案根目錄已存在 `Threat-Modeling-Report.md`，主動詢問是否合併

### 範例 3：合併 Patch 回主報告

接續範例 2，若同意合併：

```
是，請合併到主報告
```

Claude 會：

- 遞增主報告版本號（如 v1.0 → v1.1）
- 更新封面日期與修訂歷史
- 將 patch 中的新威脅延續既有 THR 編號寫入第 9 節
- 更新第 1.2 節風險概況總覽、第 10 節風險矩陣與第 12 節 MITRE ATT&CK 對應
- 更新第 13 節既有控制（如 patch 修復了某個威脅會標記為 ✅ 已緩解）
- 更新第 14 節緩解措施與第 18.2 節後續行動追蹤表
- 新增內容一律使用主報告的語言
- **不會重新編號既有 THR，不會刪除既有章節內容**
- Patch 檔案不會被刪除，作為變更歷史保留

### 範例 4：指定報告語言

```
請用 threat-modeling skill 產生這個專案的 Threat Modeling Report，報告用英文撰寫
```

---

## 報告語言

報告會以你提問的語言撰寫。範本本身是繁體中文，其他語言由 Claude 在產出時翻譯，所以不同次產出的英文章節用詞可能略有差異。

語言依以下順序決定，前面的優先：

1. 你在本次請求中明確指定的語言（例如「報告用英文撰寫」）
2. Patch 模式：若專案根目錄已有 `Threat-Modeling-Report.md`，patch 報告沿用該報告的語言，避免主報告與 patch 語言混雜
3. 你在 Claude Code 語言設定或 `CLAUDE.md` 中指定的回應語言
4. 你提問所用的語言
5. 以上都無法判斷時，使用繁體中文

合併是例外：合併進主報告的內容一律使用主報告的語言，即使你依第 1 條指定了其他語言也一樣。

不論報告用哪種語言，以下內容都維持原樣：`THR-001`、`CTRL-01` 等編號、STRIDE / DREAD 代號、MITRE ATT&CK Technique ID、檔案路徑、程式碼片段、commit hash，以及輸出檔名。

---

## 移除 Skill

```sh
# 使用者層級
rm -rf ~/.claude/skills/threat-modeling

# 專案層級
rm -rf /path/to/project/.claude/skills/threat-modeling
```

---

## 安全紅線

此 skill 在分析程式碼時會遵守以下原則（寫在 `SKILL.md` 裡，Claude 執行時會遵循）：

- **忠於證據**：每條威脅都要可追溯到實際檔案路徑或 commit。不編造 CVE 編號、不幻想不存在的元件。
- **敏感資料處理**：分析時若看到真實的密碼、API key、私鑰，**絕不寫入報告**；只描述類型與位置，並在結論中提醒使用者立即輪換。
- **不破壞性操作**：整個 skill 全程只讀專案檔案與 git 歷史，只寫入 `Threat-Modeling-Report.md` 或 `Threat-Modeling-Report-patch.md`（合併時會用 Edit 逐段修改原報告，不會整份覆蓋）。

---

## 疑難排解

**Q: 安裝後 Claude Code 找不到 skill**
- 確認 `verify_install.sh` 全綠
- 確認 Claude Code 是**在安裝之後**啟動的。Skill 清單通常在 session 啟動時載入，重開 Claude Code 試試。
- 若是專案層級安裝，確認你現在的工作目錄是那個專案。

**Q: `install.sh: Permission denied`**
- 執行 `chmod +x install.sh verify_install.sh`

**Q: Windows CMD 下跑不起來**
- 請改用 Git Bash 或 WSL

**Q: 驗證時 `[FAIL] SKILL.md frontmatter has name field`**
- 可能是檔案編碼問題（BOM）或 `SKILL.md` 被手動編輯壞掉
- 用 `./install.sh --force` 重裝即可復原

**Q: Patch 模式產出的報告幾乎是空的**
- 代表該區間內沒有安全相關的程式碼變更。這是正常結果，skill 刻意不硬湊內容。

**Q: 報告語言不是我預期的**
- 專案根目錄已有 `Threat-Modeling-Report.md` 時，Patch 與合併會沿用主報告的語言
- `CLAUDE.md` 或 Claude Code 語言設定中的回應語言，優先於你提問的語言
- 在請求中直接指定語言即可覆蓋，例如「報告用英文撰寫」。但合併進既有主報告的內容，仍會沿用主報告的語言。
