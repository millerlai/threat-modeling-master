---
name: threat-modeling
description: Generate a professional Threat Modeling Report by analyzing the project's source code using STRIDE / DREAD / MITRE ATT&CK methodologies. Use this skill when the user asks to create a threat model, perform a security analysis of the codebase, produce a Threat-Modeling-Report.md, or update an existing threat model with changes from a given git time range. Supports two modes — full (from scratch) and patch (delta over a git time window).
---

# Threat Modeling Report Skill

此 skill 用於產生專業的 Threat Modeling Report。透過分析專案實際的程式碼、設定檔、依賴關係與架構，填寫本 skill 附帶的 `threat_modeling_report_template.md` 範本，產出一份結構化、可稽核的威脅建模報告。

此 skill 同目錄下的 `threat_modeling_report_template.md` 為**唯一權威範本**，所有章節結構、欄位定義、方法論（STRIDE / DREAD / MITRE ATT&CK / Attack Tree）皆以該檔為準。執行時請先讀取該範本。

---

## 模式判斷

進入 skill 後，先依使用者輸入判斷執行模式。若無法判斷，主動詢問使用者。

| 使用者意圖 | 模式 | 輸出檔案 |
|---|---|---|
| 「從頭產生威脅建模報告」「分析整個專案的安全性」「產 Threat Modeling Report」 | **Full 模式** | `Threat-Modeling-Report.md` |
| 「分析最近 X 天的變更」「從 YYYY-MM-DD 到 YYYY-MM-DD 的 patch」「產 patch report」 | **Patch 模式** | `Threat-Modeling-Report-patch.md` |

兩個模式的輸出檔案一律寫到**專案根目錄**，不是 skill 目錄。

---

## Full 模式 — 從零產生完整報告

### 步驟 1：前置檢查

1. 檢查專案根目錄是否已存在 `Threat-Modeling-Report.md`。
   - 若存在：詢問使用者要「覆蓋重寫」、「略過」還是「改跑 Patch 模式更新」，依回應執行。**不要未經確認就覆蓋既有報告。**
2. 讀取 skill 目錄下的 `threat_modeling_report_template.md`（若太大可分段讀取）。務必理解每一節的 placeholder 與表格欄位。

### 步驟 2：蒐集專案資訊

以下項目是填好報告的基本資訊來源。依專案實際情況調整，不一定每項都有：

- **專案識別**：`README.md`、`README*`、`package.json` / `pyproject.toml` / `go.mod` / `Cargo.toml` / `pom.xml` / `build.gradle` / `*.csproj` — 取得專案名稱、版本、語言、框架。
- **依賴清單**：上述 manifest 檔 + lock file（`package-lock.json`、`yarn.lock`、`poetry.lock`、`go.sum`、`Cargo.lock`、`Gemfile.lock`）— 用於第 12、14 節供應鏈威脅與 SCA 評估。
- **部署與基礎設施**：`Dockerfile`、`docker-compose*.yml`、`k8s/`、`helm/`、`terraform/`、`cloudformation/`、`.github/workflows/`、`.gitlab-ci.yml`、`Jenkinsfile`、`serverless.yml` — 用於第 5 節架構、第 9 節 CI/CD 威脅、第 13 節既有控制。
- **入口點與路由**：找出對外暴露的介面。典型查找：
  - Web 框架路由定義（`app.route`、`@GetMapping`、`router.get`、`FastAPI`、`express`、`gin`、`echo`…）
  - API schema（`openapi.yaml`、`swagger.json`、`*.proto`、GraphQL schema）
  - 前端進入點（`index.html`、`App.*`、`main.*`）
- **認證與授權**：搜尋 `auth`、`jwt`、`token`、`session`、`login`、`password`、`bcrypt`、`hash`、`oauth`、`saml`、`ldap`、`permission`、`role`、`middleware` 等關鍵字。用於第 9 節 S/E 類威脅與第 13 節 CTRL 評估。
- **資料存取層**：搜尋 SQL 查詢、ORM 使用（`SELECT`、`raw`、`query`、`execute`、`prepare`、Prisma、SQLAlchemy、Hibernate、GORM…）。特別關注字串拼接 SQL — 直接對應 THR-005 SQL Injection 的實作證據。
- **資料驗證與輸出編碼**：`validate`、`sanitize`、`escape`、`encode`、CSP header 設定。用於第 9 節 T/I 威脅與第 13 節控制。
- **敏感資料與秘密**：`.env*`、`secrets`、`config`、硬編碼字串 `password=`、`api_key=`、`secret=` — 找出第 6 節資料資產與潛在的硬編碼秘密。**不要把找到的真實秘密寫進報告**，只敘述類型與位置。
- **檔案上傳、反序列化、外部指令執行**：`upload`、`multipart`、`pickle`、`unserialize`、`eval`、`exec`、`system`、`subprocess` — 對應 THR-010 RCE 類威脅。
- **日誌與監控**：logger 設定、結構化日誌、稽核日誌 — 用於第 9 節 R 類威脅與第 13 節 CTRL-08。
- **外部服務整合**：HTTP client 呼叫、第三方 SDK 匯入、webhook — 對應第 5.1 架構圖 External、第 7 節 TB-04、第 9 節 I 類威脅。

**探索策略**：
- 小專案（< 50 檔）：可直接用 Glob + Read 逐檔看。
- 中大型專案：**使用 Agent（Explore subagent）平行派發多個調查任務**（如「找出所有 HTTP 入口點」「盤點所有 DB 查詢位置」「找出所有外部 API 呼叫」「檢查認證中介軟體」「列出所有依賴與版本」），避免一次把大量內容拉進主 context。
- 每個 Explore 子任務都要求回傳「具體檔案路徑 + 行號 + 一句重點」。

### 步驟 3：建模與撰寫

根據蒐集到的證據，**逐節填寫範本**：

1. **封面**：專案名稱從 README / manifest 推斷；日期用今天；版本 v1.0；作者填 `Claude Code (automated)`；若無法判斷機密等級，填 `內部` 並加備註。
2. **第 2 節 系統概述**：業務目的從 README；技術棧從 manifest；部署模式若有 Dockerfile/k8s 就寫「容器化」；利害關係人若 git log 只有一位作者，可填該作者；否則寫 `{{待填}}` 並在結論章節提醒。
3. **第 5 節 架構分析**：**根據實際程式碼結構繪製 Mermaid DFD**。不要直接複製範本裡的示範圖。元件要以實際在 codebase 中存在的服務、資料庫、外部整合為準。資料流表（5.2）每一列都要能對應到程式碼中的實際呼叫。元件表（5.3）版本欄位從 lock file 查。
4. **第 6 節 資產識別**：資料資產基於實際存取的欄位類型（帳密、PII、金流、API key…）。不要憑空列不存在的資產。
5. **第 7 節 信任邊界**：對應架構圖中不同信任區之間的實際邊界。
6. **第 9 節 STRIDE 威脅識別**：**這是整份報告的核心，必須基於證據**。每一條 THR 都應該對應到一個具體的程式碼現象 — 例如：
   - THR-005 SQL Injection：若在 `src/db/user_repo.py:42` 看到 `f"SELECT * FROM users WHERE id={user_id}"` 的字串拼接，就在威脅描述裡**引用實際檔案路徑**。
   - THR-001 暴力破解：若登入端點 `POST /login` 無 rate limiter 或 failed-login counter，就說明。
   - THR-004 JWT：若看到 `jwt.decode(token, verify=False)` 或沒指定 algorithm 白名單，具體引用。
   - 若某類威脅在此專案**不適用**（例如純 CLI 工具無 web 端點，XSS/CSRF 不適用），明確標 `N/A` 並說明原因。寧可少列、條條扎實，也不要虛構。
7. **第 10 節 DREAD 評分**：評分要反映專案實際 context，不是範本預設值。
8. **第 11 節 Attack Tree**：至少針對 Top 2 嚴重威脅繪製。
9. **第 12 節 MITRE ATT&CK 對應**：只列實際識別出的威脅對應的 Technique。
10. **第 13 節 現有控制評估**：**只列實際在程式碼中看到的控制**。例如：
    - 看到 `helmet()` → 寫入 CSP/安全 header 控制
    - 看到 `csurf` 中介軟體 → CSRF 控制
    - 看到 bcrypt / argon2 → 密碼雜湊控制
    - 看到 Dependabot 設定 → SCA 控制
    - 看不到的就標 ❌ 未實作。
11. **第 14 節 緩解措施**：針對第 9 節列出的威脅逐一給具體可執行的建議，儘量引用要修改的檔案路徑。
12. **第 15-18 節**：依證據填寫殘餘風險、測試建議、合規對應、結論。
13. **第 19 節 附錄**：術語表可直接沿用範本；參考文件保留範本標準條目。

### 步驟 4：輸出與清理

1. 寫入 `<project_root>/Threat-Modeling-Report.md`。
2. **刪除所有 `> 提示：...` 說明行、`{{placeholder}}` 殘留、以及範本開頭的「⚠️ 使用說明（給 Claude）」區塊**。若某 placeholder 無法填寫，標 `N/A` 並說明。
3. 結束時向使用者回報：識別出的威脅總數（依等級分）、未能自動判定需使用者補充的欄位清單、以及 Top 3 建議優先處理項目。

---

## Patch 模式 — 依時間區間產生增量報告

### 步驟 1：確認時間區間與範圍

使用者可能用不同方式指定時間：
- 絕對日期：`2026-01-01 到 2026-04-14`
- 相對：`最近 30 天`、`上週`、`過去一季`
- Commit / tag / branch 範圍：`v1.2..v1.3`、`main..feature/x`

將輸入轉成 git 可接受的參數（`--since`、`--until`，或 revision range）。若不明確，主動詢問確認；相對日期以今天為基準換算為絕對日期，並在報告中明確記錄。

### 步驟 2：蒐集 git 變更

在專案根目錄執行（全部 read-only）：

```bash
# 基本摘要
git log --since="<since>" --until="<until>" --pretty=format:"%h %ad %an %s" --date=short

# 變更檔案清單（含增刪改狀態）
git log --since="<since>" --until="<until>" --name-status --pretty=format:"COMMIT %h %s"

# 統計
git log --since="<since>" --until="<until>" --shortstat --pretty=format:"%h %s"

# 實際 diff（重要 — 看語意變更）
git log --since="<since>" --until="<until>" -p -- <可選：敏感路徑>
```

若 diff 量極大（例如數萬行），不要把完整 diff 塞進 context。改用 Explore agent 派發子任務，請它**只回傳與安全相關的變更摘要**（新路由、認證邏輯變動、依賴升級、加解密/秘密處理、輸入驗證變動、檔案上傳、反序列化、外部呼叫）。

### 步驟 3：安全影響分析

對每個有安全意義的變更，評估：

1. **新增的攻擊面**：新路由、新端點、新的使用者輸入管道、新的檔案上傳、新的反序列化點、新的 `exec`/`eval` 使用。
2. **依賴變動**：`package*.json`、`requirements*.txt`、`go.sum`、`Cargo.lock`、`pom.xml` 的 diff — 新增或升級的套件、移除的套件。若可能，指出已知高風險套件（但**不要憑空編造 CVE 編號**；不確定就寫「建議用 SCA 工具確認」）。
3. **認證 / 授權 / 加密邏輯變動**：任何觸及 auth middleware、JWT 驗證、密碼雜湊、加解密、session 處理、權限檢查的 diff 必須逐一檢視。
4. **資料流變動**：新的 DB 查詢、新的外部 API 呼叫、新的資料匯出端點。
5. **設定變動**：`.env.example`、Dockerfile、CI/CD、security header、CORS、CSP 的變更。
6. **被移除的控制**：diff 中刪掉的 `sanitize`、`validate`、`csrf`、`rate limit`、`auth` 等 — 這類**移除**特別重要。

### 步驟 4：撰寫 Patch 報告

輸出 `Threat-Modeling-Report-patch.md`（寫到專案根目錄），結構如下：

```markdown
# Threat Modeling Report — Patch

## 基本資訊
- 分析區間：<since> ~ <until>
- Git 範圍：<commit-range>
- 分析日期：<today>
- 基準報告：Threat-Modeling-Report.md v<x.x>（若存在）或 N/A

## 1. 變更摘要
- Commit 數：N
- 檔案變更數：N
- 主要變更領域：<依分析結果摘要>

## 2. 安全相關變更清單
| # | Commit | 檔案/位置 | 變更摘要 | 安全意義 |
|---|--------|-----------|----------|----------|
| 1 | abc1234 | src/auth/jwt.py:88 | 新增 alg 白名單 | 正向：緩解 THR-004 |
| 2 | def5678 | src/api/upload.py | 新增檔案上傳端點 | ⚠️ 新攻擊面 |

## 3. 新增 / 更新的威脅
> 沿用 Full 報告的 THR 編號規則；新增的威脅從既有最大編號 +1 開始。
> 每一條威脅必須引用觸發它的 commit 與檔案位置。

### THR-0XX（新增）— <標題>
- STRIDE：<分類>
- 觸發變更：<commit hash, 檔案路徑>
- 威脅描述：...
- 初始風險：<等級>
- DREAD：D/R/E/A/D = .../平均 ...
- 建議緩解：...
- MITRE ATT&CK：T....

## 4. 狀態改變的既有威脅
| 威脅 ID | 原狀態 | 新狀態 | 變動原因 |
|---|---|---|---|

## 5. 風險概況變動
| 風險等級 | 變更前 | 變更後 | 差異 |
|---|---|---|---|
| Critical | N | N | +/-N |
| High | N | N | +/-N |
| Medium | N | N | +/-N |
| Low | N | N | +/-N |

## 6. 建議的後續行動
1. ...
2. ...
```

撰寫原則：
- **每條 finding 必須可追溯到 commit + 檔案路徑**，否則不要列入。
- 區分「正向變更」（修補了既有威脅）與「負向變更」（引入新攻擊面）。
- 若這個區間內沒有任何安全相關變更，明確說明「本區間無顯著安全影響變更」並列出檢視過的提交範圍，不要硬湊內容。

### 步驟 5：詢問是否合併到主報告

**完成 patch 報告後**，檢查 `Threat-Modeling-Report.md` 是否存在於專案根目錄：

- **若存在**：必須主動詢問使用者：
  > 已產生 `Threat-Modeling-Report-patch.md`。偵測到專案根目錄已存在 `Threat-Modeling-Report.md`，是否要將此 patch 的新內容合併到主報告？（是/否）

  若使用者同意合併，執行步驟 6；否則結束。
- **若不存在**：告知使用者「未偵測到主報告，若要建立完整基準報告請執行 Full 模式」，結束。

### 步驟 6：合併 patch 到主報告（僅在使用者確認後執行）

合併時：

1. 先讀完整個 `Threat-Modeling-Report.md`，理解現有 THR 編號、章節結構與版本。
2. **更新封面**：版本號遞增（如 v1.0 → v1.1），報告日期更新為今天。
3. **更新修訂歷史**：新增一列，說明是 patch 合併、區間、commit 範圍。
4. **第 9 節 STRIDE 威脅清單**：將 patch 中的新威脅以正確的 THR 編號（延續原報告最大編號）新增到對應類別表格中。
5. **第 10 節 風險評分矩陣**：新增對應列；更新第 1.2 節「風險概況總覽」的數字。
6. **第 12 節 MITRE ATT&CK 對應**：新增對應列。
7. **第 13 節 既有控制**：若 patch 顯示有新增或修復的控制，更新對應 CTRL 的實作狀態與有效性。
8. **第 14 節 緩解措施**：將 patch 的建議緩解措施加入對應優先級表格。
9. **第 18.2 節 後續行動追蹤表**：加入新威脅對應的行動項目。
10. **保留 patch 檔案**不刪除，作為變更歷史。

**合併注意事項**：
- 不要改動與本次 patch 無關的章節內容。
- 不要重新編號既有 THR — 只在末尾新增。
- 若 patch 顯示某既有威脅已被修復（例如 THR-005 SQL Injection 對應的拼接字串被改成 prepared statement），不要從表格刪除，而是更新「實作後風險」欄或加上 ✅ 已緩解 標註，並在修訂歷史中說明。
- 使用 Edit 工具逐段修改，不要整份 Write 覆蓋（避免遺失原有手動編輯內容）。

---

## 通用原則

- **忠於證據**：每條威脅都要可追溯到實際的程式碼位置或 commit，不編造 CVE 編號、不幻想不存在的元件。
- **敏感資料處理**：分析時若看到實際的密碼、API key、私鑰，**絕對不要**寫進報告；只描述類型與位置，並在結論中提醒使用者立刻輪換。
- **TodoWrite / TaskCreate**：Full 模式步驟多，建議建立 task list 追蹤：蒐集資訊 → 架構分析 → STRIDE 填寫 → 控制評估 → 緩解 → 輸出。Patch 模式任務較少可省略。
- **語言**：報告輸出語言沿用範本（繁體中文）。若使用者明確要求英文或其他語言，以使用者指定為準。
- **不產生周邊檔案**：除了 `Threat-Modeling-Report.md` 或 `Threat-Modeling-Report-patch.md` 外，不要額外建立 summary、README 或其他 markdown，除非使用者明確要求。
