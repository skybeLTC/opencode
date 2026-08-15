# SKY OpenCode Local Maintenance Guide

> 本文件只描述 `sky/vX.Y.Z` release maintenance：stable base、build、versioning、local patches、validation、release migration 與 AI source-editing rules。
>
> Repository-level fresh clone、remote、fetch、tag、GitHub default branch 與 bootstrap policy 以 `main:README.md` / `main:setup-local-repo.sh` 為準，不在此重複維護。
>
> 主要讀者是 AI agent，也必須讓人類可以直接閱讀與操作。

---

## 1. Maintenance Model

目標：

1. 每個 local release 固定在 OpenCode 官方 stable tag。
2. 在 stable release 上只維護必要、可移除的 Sky local patches。
3. 每個 release 使用獨立 branch：

   ```text
   sky/v1.18.18
   sky/v1.18.19
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
├── build-local.sh
├── Sky local patches
├── validation
└── release migration
```

Repository bootstrap 由 `main` 負責：

```text
main
├── README.md
├── LICENSE
└── setup-local-repo.sh
```

需要查看 repository policy：

```bash
git show main:README.md
git show main:setup-local-repo.sh
```

不要把 `setup-local-repo.sh` 或完整 fresh-clone / refspec 流程複製進 release branch。

---

## 3. Current Base

目前：

```text
OpenCode release : v1.18.18
Local branch     : sky/v1.18.18
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
branch   : sky/v1.18.18
base tag : v1.18.18
tracking : origin/sky/v1.18.18
Bun      : 1.3.14
```

確認 base ancestry：

```bash
git merge-base --is-ancestor v1.18.18 HEAD
```

exit code 必須為 `0`。

---

## 4. Branch / Upstream Rules

`sky/vX.Y.Z` 必須以同名官方 stable tag 為 base。

結構：

```text
v1.18.18
   \
    local maintenance commit
       \
        local patch A
           \
            local patch B
                ↑
           sky/v1.18.18
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
./build-local.sh
```

不要每次人工重打一長串 `OPENCODE_VERSION=...`。

### Version format

```text
<base-release>-sky.<git-commit>[.dirty]
```

格式範例：

```text
1.18.18-sky.abcdef1234
```

含意：

```text
1.18.18       upstream stable base
sky           Sky-maintained build
abcdef1234    example 10-character abbreviated source commit
.dirty        tracked staged/unstaged changes exist
```

`.dirty` 代表 binary 無法只靠該 commit 完整重現。

---

## 6. `build-local.sh`

`build-local.sh` 只負責 local build orchestration。

預期流程：

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

不要讓 `build-local.sh` 自動：

```text
修改 product source
commit
push
切 branch
merge upstream/dev
```

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
currently adopted : v1.18.18
available upstream: v1.18.19, v1.18.20, v1.18.21, v1.18.22
chosen release     : v1.18.22
```

可以直接：

```text
sky/v1.18.18
    ->
sky/v1.18.22
```

不需要先建立 `sky/v1.18.19`、`sky/v1.18.20`、`sky/v1.18.21`。

### 10.2 建立新的 adopted release branch

假設：

```text
current : sky/v1.18.18
new tag : v1.18.22
```

先：

```bash
git fetch upstream
git show-ref --verify refs/tags/v1.18.22
```

tag 不存在就停止，不要自行建立官方同名 tag。

明確決定採用後，才建立新 branch：

```bash
git switch -c sky/v1.18.22 v1.18.22
```

此時 branch 只有新 upstream release source；`SKY_README.md` 與 `build-local.sh` 尚未存在，因為它們屬於 Sky release-maintenance layer。

從舊 release 取目前最新的 maintenance files，而不是 cherry-pick 某一顆固定 maintenance commit：

```bash
git restore \
    --source=sky/v1.18.18 \
    -- SKY_README.md build-local.sh
```

這樣取得的是舊 release branch 上這兩個檔案的最新狀態，也不會把 maintenance history 中可能已過時的中間版本或其他檔案一起帶入。

接著至少：

1. 更新 `SKY_README.md` 的 current release / branch。
2. 從新 release 的 `package.json` 重新確認 required Bun version。
3. review `build-local.sh` 是否仍符合新 upstream build interface。
4. 用 `git diff -- SKY_README.md build-local.sh` 確認只帶入 release-maintenance files。
5. 將適配後的 maintenance layer 建立成新 release 的獨立 commit。

不要把舊 release 的 maintenance commit hash 寫死成 migration dependency。maintenance 文件或 build helper 之後可能有額外更新；升版時應以舊 release branch 的最新檔案狀態為來源。

建議 subject：

```text
local(maintenance): migrate release maintenance workflow to v1.18.22
```

不要覆寫：

```text
sky/v1.18.18
```

舊 branch 保留供 rebuild、rollback、comparison、patch migration reference。

maintenance layer 完成後，再依下一節逐顆評估其餘 local product patches。

完成 migration / validation 後 publish：

```bash
git push -u origin sky/v1.18.22
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
    v1.18.18..sky/v1.18.18
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

跨 release 後先確認：

```bash
grep '"packageManager"' package.json
bun --version
```

再重建 dependency state：

```bash
rm -rf node_modules
bun install
```

不要假設不同 release 一定使用相同 Bun version。

---

## 13. Validation

local patch、maintenance change 或 release migration 完成後至少：

```bash
bun turbo typecheck
./build-local.sh
opencode --version
git status
```

基本成功條件：

```text
typecheck passes
build passes
upstream smoke test passes
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

git merge-base --is-ancestor v1.18.18 HEAD
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
build-local.sh
```

角色：

```text
SKY_README.md
└── release maintenance / AI operating context

build-local.sh
└── reproducible local build entry point
```

`sky/v1.18.18` 的 baseline maintenance infrastructure commit subject：

```text
local(maintenance): establish release-based local maintenance workflow
```

需要取得實際 commit identity 時，從 Git history 查，不在文件中寫死 SHA：

```bash
git log \
    --reverse \
    --format='%H %s' \
    v1.18.18..sky/v1.18.18
```

它不是 product behavior patch。

升到新 release 時，maintenance layer 也要先 review / adapt，再形成該 release 自己的 maintenance commit；不要把某一顆歷史 maintenance SHA 當成永遠固定的 migration dependency。

後續功能修改使用獨立 commits。

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

建立：

```text
sky/vNEW_VERSION
```

不要覆寫舊 release branch。

### Rule 5 — local patch 逐顆評估

新 release 已包含等價修正時：

```text
DROP
```

優先移除 local patch。

### Rule 6 — 證據不足就停止

```text
NEEDS_REVIEW
```

不要猜。

### Rule 7 — Repository policy 回 `main` 查

```bash
git show main:README.md
git show main:setup-local-repo.sh
```

不要在 release branch 建立第二份 bootstrap policy。

### Rule 8 — 不建立 local / origin `dev`

官方 development reference：

```text
upstream/dev
```

### Rule 9 — Sky maintenance 只 push 到 `origin`

不要 push 到 `upstream`。

### Rule 10 — 保持可重現

結果應盡量能由：

```text
base tag
+
commit history
+
documented commands
```

重現。

---

## 18. Quick Reference

更新目前 branch：

```bash
git switch sky/v1.18.18
git pull --ff-only
```

取得 upstream：

```bash
git fetch upstream
```

看 available stable releases：

```bash
git tag -l 'v*' |
    grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' |
    sort -V |
    tail -20
```

看到新版不代表自動採用。

看官方 dev：

```bash
git log --oneline --decorate -20 upstream/dev
```

看 bootstrap policy：

```bash
git show main:README.md
git show main:setup-local-repo.sh
```

明確決定採用新版後建立 branch：

```bash
git fetch upstream
git show-ref --verify refs/tags/v1.18.22
git switch -c sky/v1.18.22 v1.18.22
```

列舊 patch：

```bash
git log \
    --reverse \
    --oneline \
    v1.18.18..sky/v1.18.18
```

搬 patch：

```bash
git cherry-pick <commit>
```

dependencies：

```bash
rm -rf node_modules
bun install
```

validate：

```bash
bun turbo typecheck
./build-local.sh
opencode --version
git status
```

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
