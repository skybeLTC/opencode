# SKY OpenCode Local Maintenance Guide

> 本文件只描述 `sky/vX.Y.Z` release maintenance：stable base、build、versioning、local patches、validation、release migration 與 AI source-editing rules。
>
> Repository-level fresh clone、remote、fetch、tag、GitHub default branch 與 bootstrap policy 以 `main:README.md` / `main:sky-tools/setup-local-repo.sh` 為準，不在此重複維護。
>
> 主要讀者是 AI agent，也必須讓人類可以直接閱讀與操作。

---

## 1. Maintenance Model

目標：

1. 每個 local release 固定在 OpenCode 官方 stable tag。
2. 在 stable release 上只維護必要、可移除的 Sky local patches。
3. 每個 release 使用獨立 branch：

   ```text
   sky/v1.18.32
   sky/v1.18.21
   sky/v1.19.0
   ```

4. local patch 必須可獨立 review、cherry-pick、drop、migration。
5. binary 必須能識別 base release 與 source commit。

模型：

```text
official stable release
        +
small local patch stack
        =
Sky OpenCode build
```

不要變成：

```text
moving upstream/dev
        +
uncontrolled local changes
```

---

## 2. Responsibility Boundary

Release branch 負責：

```text
sky/vX.Y.Z
├── OpenCode source
├── SKY_README.md
├── sky-tools/
│   ├── build-local.sh
│   └── check-release.sh
├── Sky local patches
├── validation
└── release migration
```

Repository bootstrap 由 `main` 負責：

```text
main
├── README.md
├── LICENSE
└── sky-tools/
    ├── setup-local-repo.sh
    └── check-release.sh
```

需要查看 repository policy：

```bash
git show main:README.md | cat
git show main:sky-tools/setup-local-repo.sh | cat
```

上述指令讀取本機 `main`。若本機 `main` 未同步，其內容可能不是 GitHub 上最新的 repository policy。使用前先核對遠端 `main` 的 commit identity；必要時由已驗證的遠端 commit 讀取檔案，不要假設本機 `main` 已同步。

不要把 `sky-tools/setup-local-repo.sh` 或完整 fresh-clone / refspec 流程複製進 release branch。

Public fork affiliation disclaimer 由 `main:README.md` 統一維護。不要只為了加入 disclaimer 而修改 upstream 的 `README.md` / `README.*.md`；這些 product README 預設保持 upstream 原樣，避免多語言文件形成不必要的 permanent local diff。

---

## 3. Current Base

目前：

```text
OpenCode release : v1.19.4
Local branch     : sky/v1.19.4
Required Bun     : 1.4.4
```

確認：

```bash
git status
git branch --show-current
git branch -vv

git describe \
    --tags \
    --match 'v[0-9]*.[0-9]*.[0-9]*' \
    --abbrev=0

grep '"packageManager"' package.json
```

預期核心值：

```text
branch   : sky/v1.19.4
base tag : v1.19.4
tracking : none before publish; origin/sky/v1.19.4 afterward
Bun      : 1.4.4
```

確認 base ancestry：

```bash
git merge-base --is-ancestor v1.19.4 HEAD
```

exit code 必須為 `0`。

---

## 4. Branch / Upstream Rules

`sky/vX.Y.Z` 必須以同名官方 stable tag 為 base。

結構：

```text
v1.19.4
   \
    local maintenance commit
       \
        local patch A
           \
            local patch B
                ↑
           sky/v1.19.4
```

不要把 `upstream/dev` merge / rebase / pull 進 `sky/vX.Y.Z`。

### 不建立 local `dev`

官方 development reference 直接使用：

```text
upstream/dev
```

查看已取得的 `upstream/dev` reference：

```bash
git log --oneline --decorate -20 upstream/dev | cat
```

這只顯示本機已有的 reference，不保證是 upstream 最新的 commit。在 Section 16.3 的 tag-fetch policy 修正前，不要為了更新這項觀察而執行未限定 refspec 的 `git fetch upstream`。

不需要：

```text
local dev
origin/dev
```

除非 Sky 明確改變 repository policy。

---

## 5. Local Build

統一使用：

```bash
./sky-tools/build-local.sh
```

不要每次人工重打一長串 `OPENCODE_VERSION=...`。

### Version format

```text
<base-release>-sky.<git-commit>[.dirty]
```

格式範例：

```text
1.19.4-sky.abcdef1234
```

含意：

```text
1.19.4        upstream stable base
sky           Sky-maintained build
abcdef1234    example 10-character abbreviated source commit
.dirty        tracked staged/unstaged changes exist
```

`.dirty` 代表 binary 無法只靠該 commit 完整重現。

---

本次 `v1.19.4` 的官方 `packageManager` 為 `bun@1.4.4`。遷移驗證應先使用隔離的 Bun 1.4.4 binary，並透過 `PATH` 選擇它。不要僅為了驗證這個候選版本覆蓋現有的 `~/.bun/bin/bun`。

## 6. `sky-tools/build-local.sh`

`sky-tools/build-local.sh` 負責 local build orchestration、build 前的 read-only Bun contract preflight，以及 upstream build 成功後由同一份 checkout 產生 version-matched OpenCode config schema。

### 6.1 Version-pinned host tool

目前 Sky local build 唯一主動做 exact-version contract check 的 host tool 是：

```text
Bun
└── required version source: package.json -> packageManager
```

目前 `v1.19.4`：

```text
packageManager : bun@1.4.4
required Bun   : 1.4.4
```

不另外 pin / preflight：

```text
bash
git
npm
Node.js
uv
Python
Turbo
Vite
TypeScript / tsgo
```

其中 Turbo、Vite、TypeScript / `tsgo` 與其他 JavaScript / TypeScript build dependencies 屬於 repository-managed dependencies，版本應由 target release 自己的 `package.json`、workspace metadata 與 `bun.lock` 管理，不另外要求 global installation。

若 future target official tag 明確新增其他 host-level tool requirement，必須在 Section 10.2 的 target upstream contract review 中辨識，再決定是否加入 preflight；不要因為舊 release 沒有列到就假設永遠只會需要 Bun。

### 6.2 Bun version preflight

每次 build 前，helper 會：

```text
package.json
    ↓
read packageManager
    ↓
require bun@<exact-version>
    ↓
bun --version
    ↓
exact match?
    ├── YES → continue
    └── NO  → stop before build
```

Bun version **不 hard-code 在 helper**。目前 checkout 若是 `v1.19.4`，helper 會從 `package.json` 取得 `bun@1.4.4`。

不要假設較新的 Bun 一定向下相容舊 release。若版本不符，即使只是 newer Bun，也停止 build。

如果 `packageManager` 不再是 `bun@<version>`，表示 target release contract 已改變。helper 應停止，回到 Section 10.2 review / adapt；不要猜測新的 build flow。

### 6.3 Bun version mismatch recovery

`sky-tools/build-local.sh` 會讀取當前 checkout 的 `packageManager`，比對 `bun --version`，不符合時停止並顯示 required / current / binary path。它不自行安裝 Bun 或刪除 dependencies。

本次 `v1.19.4` 移植驗證使用**隔離的 Bun 1.4.4**。先確認現有 Bun 1.3.14 的來源，再另行取得 Bun 1.4.4 並透過此測試指令專屬的 `PATH` 選用，不要覆蓋 `~/.bun/bin/bun`，也不要修改另一個 worktree 的 `node_modules`。

```text
installed Bun 1.3.14 (existing home workflows)
separate Bun 1.4.4 (isolated v1.19.4 verification)
                         ↓
           PATH chooses required 1.4.4
                         ↓
           bun --version == 1.4.4
                         ↓
         bun install --frozen-lockfile
                         ↓
           sky-tools/build-local.sh
```

如果日後明確決定切換 host 的預設 Bun，才依當時的安裝來源與其他環境相依關係另行規劃，不將這種全域變更當成 release migration 的必要前提。

`bun install --frozen-lockfile` 不允許改寫 `bun.lock`，執行前需確認所在位置是本次測試 worktree。不能因為 Bun 版本不符就直接清除其他專案或工作樹的 dependencies。

### 6.4 Repository state preflight

Bun contract 通過後，helper 還會確認目前 build 所需的 repository state：

```text
bun.lock exists
node_modules exists
packages/opencode/script/build.ts exists and is executable
```

這些不是額外 tool-version requirements。

`node_modules` 不存在時，先：

```bash
bun install --frozen-lockfile
```

再重新 build。

### 6.5 Version / build orchestration

preflight 通過後：

```bash
git describe \
    --tags \
    --match 'v[0-9]*.[0-9]*.[0-9]*' \
    --abbrev=0

git rev-parse --short=10 HEAD
```

組合：

```text
<base-release>-sky.<commit>[.dirty]
```

再透過 upstream 已有的：

```text
OPENCODE_VERSION
```

呼叫：

```bash
./packages/opencode/script/build.ts --single
```

不要讓 `sky-tools/build-local.sh` 自動：

```text
下載 / 安裝 / upgrade / downgrade Bun
bun install
刪除 node_modules
修改 product source
commit
push
切 branch
merge upstream/dev
```

---

### 6.4 Version-matched config schema

OpenCode config schema 屬於 release/build artifact，authority 是目前 maintenance branch 的 OpenCode source，而不是 sibling `local-ai` config repository。

`sky-tools/build-local.sh` 在 upstream build 成功返回後產生：

```text
source : packages/opencode/script/schema.ts
output : packages/opencode/dist/opencode.schema.json
```

生成順序不能移到 upstream build 前。`packages/opencode/script/build.ts` 會在 build 過程先清除 `packages/opencode/dist/`；若提前生成 schema，會被 upstream build 刪除。

`packages/opencode/dist/` 是 ignored generated state，因此 `opencode.schema.json` 不 commit。每次執行 local build 都從目前 checkout 重新產生，使 binary 與 config schema 維持相同 source version。

不要手動維護這份 schema，也不要用 published `https://opencode.ai/config.json` 覆蓋它。consumer config 只 reference generated artifact；schema generation 與更新規則由本節維護。

---

## 7. Binary / PATH

binary：

```text
~/local-ai/opencode/packages/opencode/dist/opencode-linux-x64/bin/opencode
```

symlink：

```text
~/.local/bin/opencode
    ->
~/local-ai/opencode/packages/opencode/dist/opencode-linux-x64/bin/opencode
```

確認：

```bash
command -v opencode
readlink -f "$(command -v opencode)"
opencode --version
```

重新 build 後不需要重新建立 symlink。

---

## 8. 日常更新目前 Release Branch

先確認 worktree / tracking：

```bash
git status
git branch -vv
```

只有在 working tree clean、branch 已發布，而且 upstream tracking 指向對應的 `origin/sky/vX.Y.Z` 時才執行：

```bash
git pull --ff-only
```

新建、尚未發布且沒有 upstream tracking 的 branch 不得執行此步驟。

`--ff-only` 用來：

- 阻止意外 merge commit。
- local / remote diverge 時立即停止。
- 維持 patch history 線性。

若 tracking 不正確，先查看：

```bash
git show main:README.md
```

不要猜 remote。

---

## 9. 觀察 upstream 版本與 Release 候選

Upstream published stable release 的權威是 GitHub Releases metadata，不是本機最高版本的 Git tag。`sky-tools/check-release.sh` 在**此 release branch** 使用 read-only 遠端查詢，區分：

- adopted release：遠端 `origin/sky/vX.Y.Z` branches 中最高版本，尚未 push 的 local branch 不視為 adopted；
- published stable release：官方 GitHub Releases `/releases/latest` 回傳、驗證 `draft=false` 與 `prerelease=false` 的 strict `vX.Y.Z`；
- highest upstream tag：透過 `git ls-remote upstream` 觀察的遠端 strict `vX.Y.Z` 最高 tag，不必下載到本機；
- local published tag：若本機已有 published tag，須與 upstream tag object identity 一致；未取得時顯示 `NOT_FETCHED`，不因此拒絕觀察。

本 checker 只執行 `git ls-remote`、GitHub Releases API 查詢及本機唯讀 identity check；**不呼叫 `git fetch`、不建立或刪除任何 refs**。Network/API 失敗、release 格式不合法、published tag 在 upstream 不存在或已存在的 local tag identity 不一致時，應停止並回報失敗，不 fallback 成 highest tag = stable release。

`Upgrade available: YES` 只表示遠端 published stable release 版本高於已 publish 的 Sky adopted branch；**不表示**目前 checkout、相容性、build 或部署狀態，也不授權升級。

此 checker 的安全修改**不會改變** `main:sky-tools/setup-local-repo.sh` 及 `main:sky-tools/check-release.sh`。後者仍可能因既有 upstream tag refspec 在 fetch 時重新取得大量本機 tags；兩者屬 repository-level policy，應在獨立任務 review 後調整。本 release branch checker 的 read-only 設計不表示 global fetch policy 已修正。

在 repository-level fetch policy 調整前，不要將未限定 refspec 的 `git fetch upstream` 當成例行版本觀察。本機 `upstream/dev` 可用於查看最後一次已取得的開發參考，但不代表最新狀態。詳細界線見 Section 16.3。

Stable release branch 不得 merge、rebase 或 pull `upstream/dev`。

---

## 10. 採用新的 Stable Release

只有在 Section 9 的 tag observation 之外，已另外確認 upstream 的 published stable release metadata / announcement 後，才把對應 tag 視為 **available release**。新的 available stable release 不是自動 upgrade event。

必須區分：

```text
latest upstream stable
!=
currently adopted Sky release
```

依目前 fetch policy，未限定 refspec 的 `git fetch upstream` 也會重新取得大量 upstream tags。在 Section 16.3 修正前，不應將其當作例行 release observation。除非 Sky 明確決定採用新版，否則不要：

- 建立新的 `sky/vX.Y.Z` branch。
- 修改目前 adopted release。
- migration local patches。
- rebuild / publish 新 release。

是否採用新版可考慮：

1. 是否包含需要的 bug fix。
2. 是否包含需要的新功能。
3. 是否已 upstream 掉目前的 local patch / workaround。
4. 是否有 security / compatibility 理由。
5. migration 成本是否合理。

沒有明確採用理由時，可以繼續維護目前 release。

### 10.1 允許跳過中間 releases

不需要逐版建立 Sky maintenance branch。

例如：

```text
currently adopted : v1.18.32
available upstream: v1.18.33, v1.18.34, v1.19.0
chosen release     : v1.19.0
```

可以直接：

```text
sky/v1.18.32
    ->
sky/v1.19.0
```

不需要先建立 `sky/v1.18.21`、`sky/v1.18.22`、`sky/v1.18.23`、`sky/v1.18.24`。

### 10.2 建立新的 adopted release branch

以下以 `v1.18.32` → `v1.19.4` 為本次歷史範例；tag 取得與隔離 branch 建立已完成，不要在目前 worktree 重複執行。`v1.19.2` 升級已取消，不會提交或發布；本次 maintenance 草稿使用其 parked source 作為經審查的移植材料，**沒有**繼承該版本的 commit history。

```text
previous : sky/v1.18.32
target   : v1.19.4
branch   : sky/v1.19.4
```

取得單一 target release tag 時，先確認 GitHub published stable release metadata 與 upstream tag identity，再使用明確 refspec：

```bash
git fetch --no-tags upstream \
    refs/tags/v1.19.4:refs/tags/v1.19.4
git show-ref --verify refs/tags/v1.19.4
```

此範例只針對 `v1.19.4`；未來採用其他 release 時須重新驗證並調整版本。這不代表 Section 16.3 的共用 fetch policy 已修正。

tag 不存在就停止，不要自行建立官方同名 tag。

明確決定採用後，才建立新 branch：

```bash
git switch --no-track -c sky/v1.19.4 v1.19.4
```

這裡刻意使用 `--no-track`。

repository 的 upstream fetch policy 包含：

```text
refs/tags/v*:refs/tags/v*
```

因此 local official tag 與 upstream tag ref 有明確 fetch mapping。Git 在從這類 tag 建 branch 時可能自動建立：

```text
branch.sky/vX.Y.Z.remote = upstream
branch.sky/vX.Y.Z.merge  = refs/tags/vX.Y.Z
```

這不是 release maintenance branch 要的 tracking 關係。新的 `sky/vX.Y.Z` 在 publish 前應先沒有 upstream；第一次：

```bash
git push -u origin sky/vX.Y.Z
```

之後才應 tracking 對應的 `origin/sky/vX.Y.Z`。

建立 branch 後先確認：

```bash
git for-each-ref \
    --format='%(upstream:short)' \
    refs/heads/sky/v1.19.4 |
    cat
```

預期沒有輸出。

此時 branch 只有 target official release source。**先不要搬舊版 `SKY_README.md` 或 `sky-tools/`。**

新的 official tag 本身才是該 release 的 build / validation contract authority。不要因為舊 release 使用某個 runtime、package manager、build command、validation command 或 tool version，就假設新版仍相同。也不要因為 local tool 顯示有較新版本可升級，就自行升級到 target tag 沒有要求的版本。

先把 target release 當成 upstream 原生 source review。至少確認：

```text
runtime / package manager
├── Bun / Node / other runtime requirement
└── packageManager / engines / version pinning

dependency model
├── lockfile / workspace layout
└── install procedure

build contract
├── build entry point / arguments
├── environment variables / interfaces
├── build orchestrator and relevant tool versions
└── output binary path / target naming

validation contract
├── typecheck / lint / test commands
├── smoke-test behavior
└── newly added or removed validation helpers

external requirements
├── native compiler / system package / SDK requirements
└── newly introduced build-time tools

CI / release workflow
├── official build / test workflow changes
└── release-script changes that reveal required steps
```

上述清單是最低檢查範圍，不是完整 allowlist。若 target tag 引入新的 tool / helper / workflow，即使舊文件沒有列到，也必須納入 review。

先看完整 changed-file inventory：

```bash
git diff \
    --name-status \
    v1.18.32..v1.19.4 |
    cat
```

再針對 build / validation 相關 source 檢查。以下只是常見 starting points，不是 exhaustive list：

```bash
git show v1.19.4:package.json | cat

git diff \
    v1.18.32..v1.19.4 \
    -- package.json \
       bun.lock \
       turbo.json \
       packages/opencode/script \
       .github/workflows |
    cat
```

某些 path 在未來 release 可能不存在、改名或新增其他位置；AI 必須依 changed-file inventory 與 target source 繼續追查，不可只檢查上面列出的 path 就宣告完成。

每個重要 contract area 至少記錄：

```text
Contract area:
  <runtime / build / validation / CI / ...>

Upstream evidence:
  <target tag source / diff / workflow>

Status:
  UNCHANGED / CHANGED / NEW / REMOVED / NEEDS_REVIEW

Sky impact:
  <whether local maintenance tooling must change>

Required adaptation:
  <what must be changed before validation>

Validation:
  <target-release-appropriate verification>
```

證據不足時使用：

```text
NEEDS_REVIEW
```

不要把「舊 command 還能跑」當成 upstream contract 未改變的證據。

一般未來升級時，完成 target upstream contract review 後，才從**上一個正式採用版本**取得最新 maintenance files，而不是 cherry-pick 固定的 maintenance commit。以下是通用參考程序，**本次 `v1.19.4` 的 maintenance 三檔已另行取得並建立為 untracked，請勿重做**：

```bash
git restore \
    --source=sky/v1.18.32 \
    -- SKY_README.md \
       sky-tools/build-local.sh \
       sky-tools/check-release.sh
```

這樣取得的是舊 release branch 上 maintenance files 的最新狀態，也不會把 maintenance history 中可能已過時的中間版本或其他檔案一起帶入。

接著至少：

1. 更新 `SKY_README.md` 的 current release / branch。
2. 依剛完成的 target upstream contract review，更新 required runtime / package manager / dependency procedure。
3. review 並適配 `sky-tools/build-local.sh` 的 build entry point、arguments、environment interface、output path 與其他 target-specific contract。
4. review current validation commands；如果 target upstream 已改變 typecheck / test / smoke-test 流程，就更新本文件，不要永久綁死舊 release 的 validation command。
5. `sky-tools/check-release.sh` 仍只負責 adopted / available observation，不把它擴張成假裝能涵蓋未知 future tooling 的 compatibility verifier。
6. 審查 maintenance layer 的實際差異。首次還原後若檔案仍是 untracked，普通 `git diff` 不會顯示它們；可先對照舊 branch source blob 與目前檔案，例如 `diff -u`。確認要納入版本控制後再進行 staging，使用 `git diff --cached | cat` 審查 staged changes。
7. 將適配後的 maintenance layer 建立成新 release 的獨立 commit。

不要把舊 release 的 maintenance commit hash 寫死成 migration dependency。maintenance 文件或 build helper 之後可能有額外更新；升版時應以舊 release branch 的最新檔案狀態為來源。

建議 subject：

```text
local(maintenance): migrate release maintenance workflow to v1.19.4
```

不要覆寫：

```text
sky/v1.18.32
```

舊 branch 保留供 rebuild、rollback、comparison、patch migration reference。

maintenance layer 完成後，再依下一節逐顆評估其餘 local product patches。

完成 migration / validation 後 publish：

```bash
git push -u origin sky/v1.19.4
```

後續：

```bash
git push
```

不要 push 到 `upstream`。

---

## 11. Patch Migration

列出舊 release 的 local commits：

```bash
git log \
    --reverse \
    --oneline \
    v1.18.32..sky/v1.18.32
```

先區分：

```text
maintenance infrastructure
vs.
product behavior patches
```

maintenance infrastructure 依上一節先遷移與適配；其餘 product patch 再逐顆重新判斷：

1. upstream 是否已修正？
2. 新 release 是否已有等價行為？
3. patch 是否仍必要？
4. 是否需要修改後再套？
5. validation 是否仍適用？

需要時逐顆：

```bash
git cherry-pick <commit>
```

AI 對每顆 patch 至少輸出：

```text
Patch:
  <commit> <subject>

Purpose:
  原本解決什麼問題。

Upstream status:
  新 release 是否已原生解決。

Decision:
  KEEP / DROP / MODIFY / NEEDS_REVIEW

Evidence:
  支持判斷的 source / commit。

Validation:
  套用後要跑的測試。
```

不能因為 cherry-pick 沒 conflict 就判定 patch 仍需要。

證據不足：

```text
NEEDS_REVIEW
```

不要猜。

---

## 12. Dependencies

跨 release 後，不要先假設仍使用與舊版相同的 runtime / package manager / install procedure。先完成 Section 10.2 的 target upstream contract review。

目前 `v1.19.4` 的已確認要求是：

```text
package manager : Bun
required Bun    : 1.4.4
source          : package.json -> packageManager
lockfile        : bun.lock
```

`sky-tools/build-local.sh` 會在 build 前重新讀取 `package.json` 並 enforce exact Bun version；文件與 helper 都以 release source 為 authority，不另外維護 hard-coded Bun version。

對新的 target release，先從 target tag 自己確認，例如：

```bash
git show v1.19.4:package.json | cat
```

如果 target release 仍確認使用 Bun，再依該 release 的 package metadata / lockfile 重建 dependency state。例如：

```bash
rm -rf node_modules
bun install --frozen-lockfile
```

如果 target release 改用其他 runtime / package manager / install flow，就跟隨 target upstream contract，不要強行保留 Bun 流程。

也不要因為 package manager、Turbo 或其他工具提示「有更新版本」就自行升級；是否要換版本以 target official tag 的 source / lockfile / workflow 為準。

---

## 13. Validation

對目前 `sky/v1.19.4`，local patch 或 maintenance change 完成後至少：

```bash
bun turbo typecheck
./sky-tools/build-local.sh
packages/opencode/dist/opencode-linux-x64/bin/opencode --version
git status
```

這組 command 是 **目前 v1.19.4 經 target upstream contract review 確認的 validation baseline**，不是所有 future release 的永久 contract；migration validation 必須實際通過後才能 publish。

release migration 時，必須先依 Section 10.2 從 target official tag 重新確認 build / validation contract；若 upstream 已改變 typecheck、lint、test、build、smoke test 或其他驗證流程，就以 target release 為準更新這一節，再執行 validation。

基本成功條件：

```text
typecheck passes
build passes
upstream smoke test passes
version-matched config schema is generated from the current checkout
binary version is correct
working tree is clean
```

涉及特定功能時，再增加對應 functional validation。

需要時確認 branch / base：

```bash
git branch --show-current
git branch -vv

git describe \
    --tags \
    --match 'v[0-9]*.[0-9]*.[0-9]*' \
    --abbrev=0

git merge-base --is-ancestor v1.19.4 HEAD
```

---

## 14. Local Commit Rules

每顆 local commit 應：

- 單一目的。
- 可獨立 review。
- 可獨立 cherry-pick。
- 可獨立 drop。
- 不混無關 formatting。
- 不混 generated noise。
- 說明 upstream stable release 為什麼仍需要它。

不要 commit：

```text
node_modules
build output
temporary logs
credentials
tokens
machine-specific secrets
unrelated generated files
```

完成後優先保持：

```bash
git status
```

乾淨。

---

## 15. Commit Message

Commit message 使用 **英文**。

主要讀者：

1. future AI agent。
2. future Sky。
3. code reviewer。

建議格式：

```text
<scope>: <short summary>

Context:
<Why this change is needed and what upstream/local situation exists.>

Changes:
- <Concrete implementation change>
- <Concrete implementation change>

Rationale:
<Why this approach was selected and important trade-offs.>

Validation:
- <Command or test>
- <Observed result>
```

local-only subject 可使用：

```text
local(maintenance): ...
local(build): ...
local(export): ...
local(tui): ...
local(config): ...
local(workaround): ...
```

好的 message 應回答：

```text
What changed?
Why was it needed?
How does it work?
What upstream/base version context matters?
How was it validated?
When can this patch be removed?
```

workaround 最好加入：

```text
Removal condition:
This patch can be dropped when upstream ...
```

---

## 16. Local Maintenance Files

release-specific maintenance files：

```text
SKY_README.md
sky-tools/build-local.sh
sky-tools/check-release.sh
```

角色：

```text
SKY_README.md
└── release maintenance / AI operating context

sky-tools/build-local.sh
└── reproducible local build entry point + version-matched config schema generation

sky-tools/check-release.sh
└── adopted / available release observation
```

`sky/v1.18.32` 的 baseline maintenance infrastructure commit subject：

```text
local(maintenance): migrate release maintenance workflow to v1.18.32
```

需要取得實際 commit identity 時，從 Git history 查，不在文件中寫死 SHA：

```bash
git log \
    --reverse \
    --format='%H %s' \
    v1.18.32..sky/v1.18.32
```

本次 `sky/v1.19.4` migration 應建立獨立的 maintenance commit，並依目標版本重新 review。

它不是 product behavior patch。

升到新 release 時，maintenance layer 也要先 review / adapt，再形成該 release 自己的 maintenance commit；不要把某一顆歷史 maintenance SHA 當成永遠固定的 migration dependency。

後續功能修改使用獨立 commits。

### 16.1 Product Patch: Provider Inheritance

本 release 的 provider inheritance product patch 由 R6 移植，並保留官方 `v1.19.4` 的 `reasoning_options` 行為。此候選已在隔離 Bun 1.4.4 環境通過五組 targeted tests、兩項 typecheck 及 Linux x64 build；實際 commit 與部署狀態應另依 Git history 和目標環境確認。

此 patch 的目的不是保存特定 machine 的 provider inventory，而是提供一個通用機制，讓 **config-only provider ID** 可以重用 built-in provider 的 catalog 與 provider-specific behavior，同時保持自己的 runtime / auth identity。

核心 identity boundary：

```text
provider.id
└── config / runtime / auth namespace

provider.baseProviderID
└── inherited catalog / provider behavior identity
```

兩者不能混為同一個 namespace。

Base provider 的推導規則：

1. 如果 config provider ID 本身已存在於 built-in catalog，不建立 inheritance。
2. `npm` 為 canonical `@ai-sdk/<provider>` 時，若 catalog 中存在同名 provider 且 `npm` 完全一致，優先繼承該 provider。
3. 其他 package 只有在 `npm` **唯一對應**一個 built-in catalog provider 時才允許 inheritance。
4. 無法唯一、確定地推導 base provider 時，不猜測、不 inheritance。

目前這顆 patch 沿著需要 alias-safe 的主要 provider paths 傳遞 base identity：

```text
built-in provider catalog / model metadata
provider model hooks
plugin auth loaders
custom provider loaders
selected provider-specific transforms
selected LLM runtime behavior
```

這是 **current patch coverage**，不是「所有 source 內只要比較 provider ID 就會自動 inheritance」的全域保證。OpenCode 未來仍可能新增或保留 raw provider-ID branch；migration / source edit 時必須重新 audit 與目前功能相關的 provider-specific checks，不能只因 `baseProviderID` 已存在就假設所有 path 都 alias-safe。

Alias 自己仍負責：

```text
provider ID
credential / auth storage key
config options
model sparse overrides / additions
whitelist / blacklist
```

因此：

- inherited models 會重新綁定到 alias provider ID，同時保留 `baseProviderID` 供 provider-specific logic 判斷；
- config `models` 應優先作為 sparse override / addition，而不是複製完整 built-in model metadata；
- `whitelist` / `blacklist` 在 inheritance 後限制 alias 最終暴露的 model set；
- config options 可以覆寫 inherited provider options；
- 若 explicit model 改用與 inherited provider 不同的 SDK package，不應保留錯誤的 base-provider behavior；
- auth lookup、OAuth/API credential 與 refresh persistence 必須以 alias provider ID 為 namespace，不可 fallback 或寫回 base provider credential；
- plugin 需要持久化更新 auth state 時，必須使用實際 runtime provider ID，而不是 hard-code plugin 的 built-in provider ID。

Plugin auth login discovery 也沿用 inherited base provider。若 alias 繼承的 base provider 提供 interactive / OAuth login hook，CLI 可以在 alias ID 下暴露同一個 login flow。

這個 login flow **不是 read-only**：

- 完成 login 後，新的 credential 會寫回該 alias 自己的 auth namespace；
- 不會 fallback、覆寫或共用 base provider 的 credential；
- 但如果 alias 原本已保存另一種 credential type，例如 API credential，完成 OAuth login 可能會以新的 OAuth credential 取代該 alias 原本的 credential entry；
- 因此在 inherited alias 上執行 plugin auth login 前，必須先確認「替換該 alias 現有 credential type」是刻意操作，而不是單純想查看或測試 login capability。

這是目前 generic auth inheritance 的 operator-facing behavior。若未來需要讓「catalog / provider behavior inheritance」與「interactive auth login inheritance」可以獨立控制，應新增明確的 auth-inheritance policy，而不是依賴 alias naming convention 或 machine-specific 特判。

Implementation entry point：

```text
packages/opencode/src/provider/inheritance.ts
```

實際 behavior 會跨 provider construction、auth、CLI login、plugin hooks、transforms 與 LLM runtime。Migration 時應以該 product patch 的 commit diff 與 target release source 為完整 review inventory，不要把目前 touched-file list 當成 future release 的固定 allowlist；也要搜尋 target source 中與 base provider 有關的 raw `providerID` / `provider.id` / provider-name checks，逐項判斷是否需要改用 effective base identity、是否必須保留原本 exact / prefix / substring matching semantics，或是否刻意只適用 built-in provider。

Public source / documentation 只描述 generic mechanism 與 maintenance contract。Machine-specific provider alias、model inventory、endpoint 與 credential 不屬於這個 public product patch。

#### Migration / removal decision

採用新的 official release 時，除了 Section 11 的一般 patch review，這顆 patch 必須另外確認 upstream 是否已提供等價能力：

```text
config-only provider inheritance / aliasing
catalog and model metadata inheritance
provider/plugin behavior inheritance
independent alias auth namespace
alias-safe credential refresh persistence
required provider-specific runtime / transform behavior
raw provider-ID checks reviewed for alias compatibility without narrowing upstream semantics
```

判斷：

```text
DROP
└── upstream 已完整提供等價 contract

MODIFY
└── upstream 只提供部分能力，或 internal provider / plugin contract 已改變

KEEP
└── target release 仍缺少此能力，且 patch 經 target source review 後仍相容

NEEDS_REVIEW
└── 無法從 target source / behavior 確認
```

不要只因 cherry-pick 無 conflict 或 typecheck 成功就判定可直接 KEEP。

#### Functional validation

除 Section 13 baseline 外，修改或 migration 此 patch 時至少驗證：

```text
unfiltered alias
└── inherited model inventory 符合 base provider

restricted alias
└── whitelist / blacklist 正確限制 inherited catalog

runtime routing
├── base provider path 可用
├── inherited alias path 可用
└── API / custom endpoint override 仍使用 alias 自己的 transport/config

credential isolation
├── alias credential 不依賴 base credential
└── auth refresh / persistence 寫回 alias namespace

auth login discovery
├── inherited login flow 以 alias ID 暴露
├── successful login 只寫回 alias credential namespace
└── 若 credential type 會被替換，該替換必須是刻意操作

regression
└── unrelated built-in providers / plugin paths 沒有因 base identity 判斷而改變行為
```

若 provider 使用可 refresh 的 auth，credential-isolation smoke test 應在不輸出 credential 本身的前提下，暫時使 base credential 不可用並確認 alias 仍可獨立運作；測試後恢復原 auth state。

驗證紀錄只保留 durable contract；某次 migration 的 exact commands、PASS output 與具體 provider/model smoke results 放在該 logical change 的 commit message，不在本節累積 chronological transcript。

### 16.2 Removed Product Patch: GPT-6 Sol / Luna Codex OAuth Backport

`sky/v1.18.32` 曾以 local patch 加入 GPT-6 Sol / Luna
的 Codex OAuth allowlist 支援。

`v1.19.4` 的 upstream `packages/opencode/src/plugin/openai/codex.ts`
及相應 tests 已包含等價功能，因此此 patch 判定為 DROP，
不得再次 cherry-pick。

歷史 patch 保留於 `sky/v1.18.32`。此項移除不改變
Section 16.1 所定義的 provider identity 與 credential
isolation contract。

Functional validation 仍須涵蓋原生 OpenAI OAuth、
inherited OpenAI OAuth alias、適用的 GPT-6 model filtering
及可執行的 runtime request。Model listing 不等於
end-to-end request 已成功。

### 16.3 Deferred: Repository-Level Tag Fetch and Local Retention

**現行界線：** 本 release branch 的 `sky-tools/check-release.sh` 改用遠端唯讀 release observation，已在 home 驗證能取得官方 published release，且執行前後 Git refs、index、設定與 source 不變。`main` 上的 `check-release.sh` 及 `setup-local-repo.sh` 未修改，repository-level upstream fetch 與 tag retention policy 仍待獨立審查。

2026-10-21 home 清理 1,143 個未使用的 local tags，當時保留已採用版本的 base tags：`v1.18.18`、`v1.18.20`、`v1.18.32`。`v1.19.4` 是 2026-10-22 才發布，於本次 2026-10-24 migration 透過單一 tag refspec 另外取得；**不是**前述清理當天的既有保留項。

已知根因：`main:sky-tools/setup-local-repo.sh` 仍設定 `refs/tags/v*:refs/tags/v*`，一般 `git fetch upstream` 會重新建立未採用版本的 tags。`main:sky-tools/check-release.sh` 也會觸發該 fetch。這是 repository-level 行為，**不會因 release branch 的 checker 修改而解決**。

後續 repository-level 修正須以 `main:README.md` 作為政策權威，沿實際相依關係一起審查 `main:sky-tools/setup-local-repo.sh`、`main:sky-tools/check-release.sh` 與 release branch 引用；不得自行套用改動到 work 專用配置。

驗收條件：

- 查詢 GitHub published stable release，並確認對應 upstream tag identity；
- 一般 fetch 不再無意長期保留未採用版本的 tags；
- 保留中的 Sky release branches 仍能取得對應 base tags；
- `origin` 不成為 upstream 全量 tag mirror；
- 按實際相依關係分別回報 home / work 的受影響項目及驗證狀態。

這是 repository bootstrap / observation 待辦，不屬 provider inheritance、Codex 或 local build patch。未經單獨授權及檢查，不修改 `main` 的 Git config/bootstrap policy。

---

## 17. AI Agent Rules

### Rule 1 — 修改前確認 branch / base / worktree

```bash
git status
git branch --show-current

git describe \
    --tags \
    --match 'v[0-9]*.[0-9]*.[0-9]*' \
    --abbrev=0
```

### Rule 2 — 不混入 `upstream/dev`

不要 merge / rebase / pull `upstream/dev` 到 `sky/vX.Y.Z`。

### Rule 3 — 不自動追 latest stable

新的 official `vX.Y.Z` tag 只代表新的 version tag 被觀察到；Git tag 本身不能證明它已發布成 stable release。先依 Section 9 另外驗證 upstream release metadata / announcement，再決定它是否是 available stable release。

即使已確認是 available stable release，除非 Sky 明確決定採用，否則不要：

```text
建立新的 sky/vX.Y.Z
修改目前 adopted release
migration local patches
rebuild / publish 新 release
```

允許跳過中間 stable releases。

### Rule 4 — 採用新版時建立新 branch

從 official tag 建立：

```bash
git switch --no-track -c sky/vNEW_VERSION vNEW_VERSION
```

不要覆寫舊 release branch。

publish 前 branch 不應 tracking upstream tag；第一次 publish 後才用：

```bash
git push -u origin sky/vNEW_VERSION
```

建立正確的 `origin/sky/vNEW_VERSION` tracking。

### Rule 5 — target tag 定義 build / validation contract

採用新 release 時，先 review target official tag 原生的 runtime、package manager、dependencies、build interface、tooling、validation、CI / release workflow。

不要用：

```text
舊 release 的工具版本
目前 machine 安裝的最新版
tool 的 update available 提示
舊 validation command 還能成功
```

取代 target upstream evidence。

若 target contract 尚未釐清：

```text
NEEDS_REVIEW
```

不要先搬 product patches 或宣告 migration-ready。

### Rule 6 — local patch 逐顆評估

新 release 已包含等價修正時：

```text
DROP
```

優先移除 local patch。

### Rule 7 — 證據不足就停止

```text
NEEDS_REVIEW
```

不要猜。

### Rule 8 — Repository policy 回 `main` 查

```bash
git show main:README.md
git show main:sky-tools/setup-local-repo.sh
```

不要在 release branch 建立第二份 bootstrap policy。

### Rule 9 — 不建立 local / origin `dev`

官方 development reference：

```text
upstream/dev
```

### Rule 10 — Sky maintenance 只 push 到 `origin`

不要 push 到 `upstream`。

### Rule 11 — 保持可重現

結果應盡量能由：

```text
base tag
+
commit history
+
documented commands
```

重現。

### Rule 12 — Provider inheritance 依 Section 16.1

修改、review 或 migration provider-inheritance product patch 時，先讀 Section 16.1 的 identity boundary、migration / removal decision 與 functional validation。

不要把 machine-specific provider alias、model inventory、endpoint 或 credential 寫進 public product source / documentation。

### Rule 13 — 已 upstream 的 Codex backport 依 Section 16.2

v1.19.4 已包含對應 Sol / Luna Codex OAuth allowlist 及 tests；不得再次移植已移除的 local backport。

不要把 model list 可見性當成完整 runtime validation；具備 entitlement 時仍需做實際 request smoke test。

---

## 18. Quick Reference

目前維護的 release branch：

```text
sky/v1.19.4
```

查看目前 Git 狀態：

```bash
git branch --show-current
git status --short --untracked-files=all
git branch -vv
```

只有在 branch 已發布、working tree clean，且 tracking 指向
`origin/sky/v1.19.4` 時，才依 Section 8 使用 `git pull --ff-only`。

### Release observation

未限定 refspec 的 `git fetch upstream` 仍可能重新建立未採用版本的本機 tags。本 release branch 的 checker 已在 home 通過遠端唯讀驗證；`main` checker 與 bootstrap 仍不得當成安全的例行版本觀察流程。

需要確認 upstream published stable release，查閱官方 GitHub
Releases metadata。存在 strict `vX.Y.Z` tag 不代表已發布 stable release。

查看本機保留的 base tags：

```bash
git tag --list 'v*' |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
    sort -V |
    cat
```

這份清單只表示本機保留的 tags，不是完整的 upstream release 清單。

查看本機最後取得的 upstream development reference：

```bash
git log --oneline --decorate -20 upstream/dev | cat
```

此 reference 可能不是 upstream 最新狀態。

### Repository policy

Repository bootstrap、fetch refspec、tag retention 與 origin archive
policy 由 `main:README.md` 與 `main:sky-tools/setup-local-repo.sh` 持有。
讀取本機 `main` 前須確認它是否與遠端同步，不能假設它就是最新 policy。

本次已採用的 `v1.19.4` branch 不需要重新建立。未來採用新 release，
依 Section 10.2 確認 target contract、取得 tag、建立獨立 branch。

### Previous release patch history

```bash
git log --reverse --oneline v1.18.32..sky/v1.18.32 | cat
```

這是前一版 local patch history，不是 `sky/v1.19.4` 的 commit inventory。

### Dependencies and validation

重建 dependencies 前先確認 Section 12 與目前 official release 的
lockfile contract。相關 validation workflow：

```bash
bun install --frozen-lockfile
bun turbo typecheck
./sky-tools/build-local.sh
packages/opencode/dist/opencode-linux-x64/bin/opencode --version
git status
```

這是驗證步驟，不表示已實際執行通過。Provider inheritance 仍需
依 Section 16.1 完成 source review 與 functional validation。

Commit、release publication 與 origin archive 操作，應在各階段
review 與驗證後分別處理。

---

## 19. Maintenance Philosophy

優先順序：

```text
stability
    >
reproducibility
    >
traceability
    >
minimal local divergence
    >
convenience
```

local patch 越少越好。

能 upstream 解決，就不要永久維護 local patch。

需要 local patch 時，讓它：

```text
small
explicit
documented
testable
removable
```

Repository bootstrap 與 release maintenance 保持分離。
