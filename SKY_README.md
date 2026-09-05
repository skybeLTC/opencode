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
   sky/v1.18.20
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
git show main:README.md
git show main:sky-tools/setup-local-repo.sh
```

不要把 `sky-tools/setup-local-repo.sh` 或完整 fresh-clone / refspec 流程複製進 release branch。

Public fork affiliation disclaimer 由 `main:README.md` 統一維護。不要只為了加入 disclaimer 而修改 upstream 的 `README.md` / `README.*.md`；這些 product README 預設保持 upstream 原樣，避免多語言文件形成不必要的 permanent local diff。

---

## 3. Current Base

目前：

```text
OpenCode release : v1.18.20
Local branch     : sky/v1.18.20
Required Bun     : 1.3.14
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
branch   : sky/v1.18.20
base tag : v1.18.20
tracking : origin/sky/v1.18.20
Bun      : 1.3.14
```

確認 base ancestry：

```bash
git merge-base --is-ancestor v1.18.20 HEAD
```

exit code 必須為 `0`。

---

## 4. Branch / Upstream Rules

`sky/vX.Y.Z` 必須以同名官方 stable tag 為 base。

結構：

```text
v1.18.20
   \
    local maintenance commit
       \
        local patch A
           \
            local patch B
                ↑
           sky/v1.18.20
```

不要把 `upstream/dev` merge / rebase / pull 進 `sky/vX.Y.Z`。

### 不建立 local `dev`

官方 development reference 直接使用：

```text
upstream/dev
```

查看：

```bash
git fetch upstream
git log --oneline --decorate -20 upstream/dev
```

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
1.18.20-sky.abcdef1234
```

含意：

```text
1.18.20       upstream stable base
sky           Sky-maintained build
abcdef1234    example 10-character abbreviated source commit
.dirty        tracked staged/unstaged changes exist
```

`.dirty` 代表 binary 無法只靠該 commit 完整重現。

---

## 6. `sky-tools/build-local.sh`

`sky-tools/build-local.sh` 負責 local build orchestration、build 前的 read-only Bun contract preflight，以及 upstream build 成功後由同一份 checkout 產生 version-matched OpenCode config schema。

### 6.1 Version-pinned host tool

目前 Sky local build 唯一主動做 exact-version contract check 的 host tool 是：

```text
Bun
└── required version source: package.json -> packageManager
```

目前 `v1.18.20`：

```text
packageManager : bun@1.3.14
required Bun   : 1.3.14
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

Bun version **不 hard-code 在 helper**。目前 checkout 若是 `v1.18.20`，helper 會從 `package.json` 取得 `bun@1.3.14`。

不要假設較新的 Bun 一定向下相容舊 release。若版本不符，即使只是 newer Bun，也停止 build。

如果 `packageManager` 不再是 `bun@<version>`，表示 target release contract 已改變。helper 應停止，回到 Section 10.2 review / adapt；不要猜測新的 build flow。

### 6.3 Bun version mismatch recovery

Bun 官方 installer 支援用指定 release tag 安裝舊版，因此同一套 exact-version install command 可用於 upgrade 或 downgrade。

對本 WSL / Linux setup，若 Bun 是使用官方 installer 安裝在 `~/.bun/bin`，version mismatch 時 helper 會顯示 required / current / binary path，並提示：

```bash
curl -fsSL https://bun.com/install |
    bash -s "bun-v<required-version>"

hash -r

command -v bun
type -a bun
bun --version
bun --revision

rm -rf node_modules
bun install --frozen-lockfile

./sky-tools/build-local.sh
```

例如 `v1.18.20`：

```bash
curl -fsSL https://bun.com/install |
    bash -s "bun-v1.3.14"
```

這個流程的目的：

```text
install exact release-required Bun
→ refresh shell command cache
→ verify active Bun
→ discard dependency state produced by another Bun version
→ reconstruct node_modules from committed bun.lock
→ retry build
```

`bun install --frozen-lockfile` 不允許修改 `bun.lock`；若 `package.json` 與 lockfile 不一致就直接失敗。

不要在這裡使用：

```bash
bun upgrade
```

因為它的語意是 upgrade Bun，而不是切到目前 release 明確要求的 arbitrary exact version。

若 `command -v bun` 顯示 Bun 不是來自 `~/.bun/bin/bun`，或 `type -a bun` 顯示同時存在多套 Bun，不要直接混用不同安裝方式。先確認目前 PATH 實際使用哪一套、原本由哪個 installer / package manager 管理，再用相同方式切到 exact version；若要改用官方 installer，先明確移除衝突的舊安裝。

helper **只顯示 recovery instructions，不會自動下載、upgrade、downgrade、刪除 `node_modules` 或執行 `bun install`**。

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

working tree clean 後：

```bash
git pull --ff-only
```

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

## 9. 取得官方最新資訊

日常只要檢查 adopted / available stable release 時，使用：

```bash
./sky-tools/check-release.sh
```

它會 fetch `origin` 與 `upstream`，並比較：

```text
Latest adopted
└── origin/sky/vX.Y.Z 中版本最高的 adopted release

Latest available
└── upstream fetch 後 strict vX.Y.Z official tags 中版本最高的 release
```

範例輸出（版本號只代表當時的 repository state）：

```text
Latest adopted   : v1.18.20
Latest available : v1.18.25
Upgrade available: YES
```

這個工具只觀察 release state，不會建立 branch、migration patches、build 或 publish。
`Latest adopted` 也不代表目前 checkout 的 branch。

`Upgrade available: YES` 只表示存在版本更高的 official stable tag，不代表：

```text
compatibility reviewed
migration-safe
build-ready
validation-ready
ready-to-adopt
```

target release 的 runtime、package manager、dependency model、build interface、build tooling、validation tooling、CI / release workflow 與其他 upstream contract，必須在真正採用該 release 時重新從 target official tag 檢查。

需要進一步查看 upstream development / tags 時，再執行：

```bash
git fetch upstream
```

對 release maintenance 需要的官方資訊只有：

```text
upstream/dev
official v* tags
```

看官方 dev：

```bash
git log --oneline --decorate -20 upstream/dev
```

看 stable-looking tags：

```bash
git tag -l 'v*' |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
    sort -V |
    tail -20
```

`git fetch upstream` 可能讓 local strict official tags 比 `origin` 的 stable-tag archive 更新；這是正常的 repository state，直到明確執行 archive publication 為止。

`sky-tools/check-release.sh` 只負責 adopted / available observation，不會把 tags push 到 `origin`。official stable tag 的 authority / archive boundary、strict tag filtering、identity audit 與 publication procedure 以：

```bash
git show main:README.md
```

中的 repository-level tag policy 為準。

不要在 stable branch 執行：

```bash
git pull upstream dev
git merge upstream/dev
git rebase upstream/dev
```

也不要用：

```bash
git fetch upstream --tags --prune
```

繞過 `main` 定義的 repository fetch policy。

---

## 10. 採用新的 Stable Release

新的官方 stable release 出現時，先視為 **available release**，不是自動 upgrade event。

必須區分：

```text
latest upstream stable
!=
currently adopted Sky release
```

`git fetch upstream` 只更新 observation refs。除非 Sky 明確決定採用新版，否則不要：

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
currently adopted : v1.18.20
available upstream: v1.18.21, v1.18.22, v1.18.23, v1.18.24, v1.18.25
chosen release     : v1.18.25
```

可以直接：

```text
sky/v1.18.20
    ->
sky/v1.18.25
```

不需要先建立 `sky/v1.18.21`、`sky/v1.18.22`、`sky/v1.18.23`、`sky/v1.18.24`。

### 10.2 建立新的 adopted release branch

假設：

```text
current : sky/v1.18.20
new tag : v1.18.25
```

先：

```bash
git fetch upstream
git show-ref --verify refs/tags/v1.18.25
```

tag 不存在就停止，不要自行建立官方同名 tag。

明確決定採用後，才建立新 branch：

```bash
git switch --no-track -c sky/v1.18.25 v1.18.25
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
    refs/heads/sky/v1.18.25 |
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
    v1.18.20..v1.18.25 |
    cat
```

再針對 build / validation 相關 source 檢查。以下只是常見 starting points，不是 exhaustive list：

```bash
git show v1.18.25:package.json | cat

git diff \
    v1.18.20..v1.18.25 \
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

完成 target upstream contract review 後，才從舊 release 取目前最新的 maintenance files，而不是 cherry-pick 某一顆固定 maintenance commit：

```bash
git restore \
    --source=sky/v1.18.20 \
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
6. 用 `git diff -- SKY_README.md sky-tools/build-local.sh sky-tools/check-release.sh | cat` 確認 maintenance layer 的適配內容。
7. 將適配後的 maintenance layer 建立成新 release 的獨立 commit。

不要把舊 release 的 maintenance commit hash 寫死成 migration dependency。maintenance 文件或 build helper 之後可能有額外更新；升版時應以舊 release branch 的最新檔案狀態為來源。

建議 subject：

```text
local(maintenance): migrate release maintenance workflow to v1.18.25
```

不要覆寫：

```text
sky/v1.18.20
```

舊 branch 保留供 rebuild、rollback、comparison、patch migration reference。

maintenance layer 完成後，再依下一節逐顆評估其餘 local product patches。

完成 migration / validation 後 publish：

```bash
git push -u origin sky/v1.18.25
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
    v1.18.20..sky/v1.18.20
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

目前 `v1.18.20` 的已確認要求是：

```text
package manager : Bun
required Bun    : 1.3.14
source          : package.json -> packageManager
lockfile        : bun.lock
```

`sky-tools/build-local.sh` 會在 build 前重新讀取 `package.json` 並 enforce exact Bun version；文件與 helper 都以 release source 為 authority，不另外維護 hard-coded Bun version。

對新的 target release，先從 target tag 自己確認，例如：

```bash
git show v1.18.25:package.json | cat
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

對目前 `sky/v1.18.20`，local patch 或 maintenance change 完成後至少：

```bash
bun turbo typecheck
./sky-tools/build-local.sh
opencode --version
git status
```

這組 command 是 **目前 v1.18.20 經 target upstream contract review 確認的 validation baseline**，不是所有 future release 的永久 contract；migration validation 必須實際通過後才能 publish。

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

git merge-base --is-ancestor v1.18.20 HEAD
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

`sky/v1.18.20` 的 baseline maintenance infrastructure commit subject：

```text
local(maintenance): migrate release maintenance workflow to v1.18.20
```

需要取得實際 commit identity 時，從 Git history 查，不在文件中寫死 SHA：

```bash
git log \
    --reverse \
    --format='%H %s' \
    v1.18.20..sky/v1.18.20
```

它不是 product behavior patch。

升到新 release 時，maintenance layer 也要先 review / adapt，再形成該 release 自己的 maintenance commit；不要把某一顆歷史 maintenance SHA 當成永遠固定的 migration dependency。

後續功能修改使用獨立 commits。

### 16.1 Current Product Patch: Provider Inheritance

目前 release branch 維護一個 provider-inheritance product patch。它的目的不是保存特定 machine 的 provider inventory，而是提供一個通用機制，讓 **config-only provider ID** 可以重用 built-in provider 的 catalog 與 provider-specific behavior，同時保持自己的 runtime / auth identity。

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

新的 official `vX.Y.Z` tag 只代表 available release。

除非 Sky 明確決定採用，否則不要：

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

---

## 18. Quick Reference

更新目前 branch：

```bash
git switch sky/v1.18.20
git pull --ff-only
```

取得 upstream：

```bash
git fetch upstream
```

快速檢查 adopted / available release：

```bash
./sky-tools/check-release.sh
```

看 available stable releases：

```bash
git tag -l 'v*' |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
    sort -V |
    tail -20
```

看到新版不代表自動採用。

若要確認 / 同步 `origin` 的 official stable tag archive，依：

```bash
git show main:README.md
```

中的 Section 4.2 先做 strict tag set / identity audit；不要直接 `git push --tags`。

看官方 dev：

```bash
git log --oneline --decorate -20 upstream/dev
```

看 bootstrap policy：

```bash
git show main:README.md
git show main:sky-tools/setup-local-repo.sh
```

明確決定採用新版後建立 branch：

```bash
git fetch upstream
git show-ref --verify refs/tags/v1.18.25
git switch --no-track -c sky/v1.18.25 v1.18.25
```

先依 Section 10.2 review target upstream build / validation contract；完成後才 restore Sky maintenance files、適配 tooling、migration product patches。

列舊 patch：

```bash
git log \
    --reverse \
    --oneline \
    v1.18.20..sky/v1.18.20
```

搬 patch：

```bash
git cherry-pick <commit>
```

dependencies：

```bash
rm -rf node_modules
bun install --frozen-lockfile
```

validate（目前 v1.18.20 contract-review baseline）：

```bash
bun turbo typecheck
./sky-tools/build-local.sh
opencode --version
git status
```

新 release 必須先重新確認 target validation contract。

push：

```bash
git push
```

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
