# Sky OpenCode Maintenance Fork

> **Unofficial fork / 非官方 fork**
>
> This repository is a personal, independently maintained fork of OpenCode.
> It is not built or maintained by the OpenCode team and is not affiliated with them.
>
> 本 repository 為個人獨立維護的 OpenCode fork，並非由 OpenCode team 建置或維護，亦與其無隸屬或合作關係。
>
> 本 repository 是 Sky 維護的 OpenCode maintenance fork。
>
> 主要讀者是 AI agent，也必須讓人類可以直接閱讀與操作。
>
> **本 fork 不 mirror upstream development branches。**
> 正式 source maintenance 使用 `sky/vX.Y.Z` branches；repository-level bootstrap policy 由 `main` 維護。

---

## 1. Repository 角色

本 fork 將 repository bootstrap 與 release maintenance 分離。

```text
main
├── README.md
├── LICENSE
├── .gitignore
│   └── single-worktree generated-state hygiene
└── sky-tools/
    ├── setup-local-repo.sh
    │   └── repository bootstrap / Git remote policy
    └── check-release.sh
        └── release availability observation

sky/vX.Y.Z
├── OpenCode source
├── SKY_README.md
├── sky-tools/
│   ├── build-local.sh
│   └── check-release.sh
└── Sky local patches
    └── release-specific maintenance
```

責任邊界：

```text
main
└── repository lifecycle
    ├── fresh clone
    ├── origin / upstream roles
    ├── fetch policy
    ├── tag policy
    ├── single-worktree branch-switch hygiene
    └── local Git bootstrap

sky/vX.Y.Z
└── release lifecycle
    ├── stable release base
    ├── build
    ├── local version
    ├── local patch rules
    ├── validation
    └── release migration
```

不要在 `main` 維護 OpenCode product source。

不要在 `sky/vX.Y.Z` 重複維護 repository-level Git bootstrap policy。

---

## 2. Branch 模型

### `main`

`main` 是 GitHub default branch，也是 repository landing / bootstrap branch。

它與 OpenCode upstream source history 分離，使用獨立 root commit。

預期只保存 repository-level metadata 與 bootstrap tooling，例如：

```text
README.md
LICENSE
.gitignore
sky-tools/
├── setup-local-repo.sh
└── check-release.sh
```

`sky-tools/` 是 Sky-owned maintenance tooling namespace，不限定 shell。
後續若 repository maintenance 需要 Python 或其他 helper，也集中放在此目錄，不散落在 repository root。

### `sky/vX.Y.Z`

正式 maintenance source branch。

例如：

```text
v1.18.18
   \
    Sky local maintenance commit
       \
        local patch A
           \
            local patch B
                ↑
          sky/v1.18.18
```

每個 `sky/vX.Y.Z` 都必須以對應的官方 stable release tag 作為 base。

例如：

```text
sky/v1.18.18 -> base v1.18.18
sky/v1.18.19 -> base v1.18.19
```

舊 release branch 不覆寫，保留供 rebuild、rollback 與 patch migration reference。

### 不建立 local `dev`

本 fork 不需要 local `dev` branch，也不需要 `origin/dev` mirror。

官方 development state 直接透過：

```text
upstream/dev
```

查看。

需要檢查官方最新 development history 時使用：

```bash
git fetch upstream
git log upstream/dev
```

不要把 `upstream/dev` merge / rebase / pull 進 `sky/vX.Y.Z` stable maintenance branch。

---

## 3. Remote 角色

預期：

```text
origin
└── git@github.com:skybeLTC/opencode.git
    ├── main
    └── sky/vX.Y.Z

upstream
└── git@github.com:anomalyco/opencode.git
    ├── dev
    └── v* tags
```

角色：

```text
origin
└── Sky fork
    ├── repository bootstrap branch
    └── Sky-maintained release branches

upstream
└── official OpenCode repository
    ├── development reference
    └── authoritative release tags
```

不要把 Sky local maintenance branch push 到 `upstream`。

---

## 4. Fetch policy

remote fetch 範圍刻意收斂，不使用預設的「取得所有 remote branches」。

正式 local policy：

```text
origin
├── branches : main
├── branches : sky/*
├── implicit tag auto-follow : disabled
└── purpose  : Sky-maintained refs

upstream
├── branch   : dev only
├── tags     : v*
├── implicit tag auto-follow : disabled
└── purpose  : official development/reference refs
```

對應 repository-local Git config：

```text
remote.origin.fetch
+refs/heads/main:refs/remotes/origin/main
+refs/heads/sky/*:refs/remotes/origin/sky/*

remote.origin.tagOpt
--no-tags

remote.upstream.fetch
+refs/heads/dev:refs/remotes/upstream/dev
refs/tags/v*:refs/tags/v*

remote.upstream.tagOpt
--no-tags
```

`refs/tags/v*:refs/tags/v*` 刻意不加前導 `+`。

符合 `v*` 的 tags 預設視為 immutable；若 upstream 改寫同名 tag，fetch 應明確失敗，而不是靜默強制覆寫 local tag。

Git refspec 的 `v*` 不是 SemVer regex，因此 local upstream fetch 可能同時取得少量例如：

```text
vscode-v0.0.x
```

的額外 tags。這是刻意接受的 trade-off，避免為嚴格 tag filtering 引入額外 bootstrap complexity。

### 4.1 Upstream release observation

`git fetch upstream` 的角色是更新官方 observation / release-base refs，不代表 Sky 自動採用新版。

必須區分：

```text
observed Git tag
!=
published stable release
!=
currently adopted Sky release
```

strict `vX.Y.Z` Git tag 本身不構成 stable release authority。upstream 可以先建立 tag，再於稍後建立 GitHub Release；也可能存在 strict version tag，但沒有對應的 published stable release。

本 fork 將 **GitHub published stable release** 視為 release availability authority：

```text
draft      = false
prerelease = false
tag_name   = strict vX.Y.Z
```

`sky-tools/check-release.sh` 會：

1. fetch `origin` 與 `upstream`，更新 adopted branches 與 local tag/base refs。
2. 透過 GitHub Releases API 取得 upstream latest published stable release。
3. 驗證該 release 的 strict `vX.Y.Z` tag 已由 upstream fetch 到 local repository。
4. 將 published stable release 與 `origin/sky/vX.Y.Z` 中最高 adopted release 比較。
5. 另外顯示 local strict tags 中最高的 observed tag；較新的 observed tag 不會自行被視為 stable release。

日常檢查：

```bash
./sky-tools/check-release.sh
```

範例輸出（版本號僅代表當時的 repository state）：

```text
Adopted release          : v1.18.32
Published stable release : v1.18.32
Highest observed tag     : v2.0.14
Upgrade available        : NO
Newer tag observed       : YES
```

定義：

```text
Latest adopted
└── origin/sky/vX.Y.Z 中版本最高的 adopted release

Latest published stable release
└── GitHub /releases/latest 回傳的 published stable release
    且 tag_name 必須符合 strict vX.Y.Z

Highest observed tag
└── git fetch upstream 後 local strict vX.Y.Z tags 中版本最高者
    只代表 tag observation，不代表 release availability
```

`Latest adopted` 不代表目前 checkout 的 branch。

若 GitHub Release API 無法查詢、response 無法解析、latest published stable release tag 不符合 strict `vX.Y.Z`，或該 published stable release tag 沒有由 upstream fetch 到 local repository，`check-release.sh` 必須 fail closed；不得 fallback 成「把最高 strict Git tag 當 stable release」。

看到較新的 observed `vX.Y.Z` tag，預設不因此：

- 建立新的 `sky/vX.Y.Z` branch。
- 修改目前 adopted release branch。
- migration local patches。
- rebuild / publish 新版本。

`check-release.sh` 只觀察 release state；即使 `Upgrade available: YES`，也不會建立 branch、migration patches、build 或 publish。

`Upgrade available: YES` 只表示存在版本更高的 published stable release，不代表：

```text
compatibility reviewed
migration-safe
build-ready
validation-ready
ready-to-adopt
```

target release 的 runtime、package manager、dependency model、build interface、build tooling、validation tooling、CI / release workflow 與其他 upstream contract，必須在真正採用該 release 時重新從 target official tag 檢查。

Sky 可以繼續維護目前 adopted release，也可以明確決定跳過一個或多個中間 stable releases。

真正採用新版時，才依目前 release branch 的 `SKY_README.md` 執行 release adoption / migration。

### 4.2 Adopted release base tag archive

`git fetch upstream` 只會把 upstream tag refs 更新到 local repository，不會把 local tags 自動 publish 到 `origin`。

因此要區分三個角色：

```text
upstream GitHub published stable releases
    ↓ release authority

upstream/local strict vX.Y.Z tags
    ↓ observation / release-base candidates

origin adopted-release base tags
    ↓ base refs for retained sky/vX.Y.Z branches
```

`origin` **不作為 upstream stable-release tag mirror**。只有 retained `origin/sky/vX.Y.Z` branch 實際使用的 matching `vX.Y.Z` base tag，才需要保留在 `origin`。

這不改變：

- `Latest published stable release`：由 upstream GitHub published stable release 判定。
- `Highest observed tag`：由 `git fetch upstream` 後的 local strict tags 判定。
- `Latest adopted`：仍以 published `origin/sky/vX.Y.Z` branches 判定。

`sky-tools/check-release.sh` 與 `sky-tools/setup-local-repo.sh` 都不負責把 tags publish 到 `origin`。tag publication / deletion 是明確、獨立的 repository mutation，不應偷偷附帶在 observation / bootstrap workflow 中。

origin base-tag retention candidate 必須同時符合：

```text
matching branch = origin/sky/vX.Y.Z exists and is retained
tag name        = matching vX.Y.Z
GitHub Release exists
release.draft      = false
release.prerelease = false
```

strict SemVer-shaped Git tag **不是**充分條件。對每個待 publish base tag，先確認 matching retained release branch，再確認 upstream 的 `releases/tags/<tag>` 存在 published stable release，最後驗證 local tag commit identity 與 upstream 完全相同。

不要因為 upstream fetch refspec 是 `v*`，或某個 published stable release 存在，就把未採用的 intermediate release tags publish 到 `origin`。例如 Sky 從 `v1.18.20` 直接採用 `v1.18.32` 時，`v1.18.21` 到 `v1.18.31` 不因為存在 published stable releases 就需要成為 origin archive tags。

也不要因為 upstream fetch refspec 是 `v*`，就把例如：

```text
vscode-v0.0.x
```

這類 non-strict tags publish 到 `origin`。

既有 `origin` strict release tag 若沒有 matching retained `sky/vX.Y.Z` branch，屬於 cleanup candidate。刪除前仍須獨立 audit；tag deletion 不代表刪除 upstream/local observation tag，也不改變 upstream release history。

publish 缺少的 adopted-release base tag 或清理既有 tag 前，至少確認：

1. retained `origin/sky/vX.Y.Z` branch set。
2. matching base tag 的 upstream published stable-release status。
3. 每個 retained base tag 的 local commit identity 與 upstream 完全相同。
4. 待新增 tag 在 `origin` 尚不存在；待刪除 tag 沒有 matching retained `sky/vX.Y.Z` branch。
5. 不覆寫、改寫或 force-update 既有 retained origin base tag。
6. exact remote tag create/delete set 已在 mutation 前 review。

需要比較 set 時，`comm` 的輸入必須使用相同的 lexical sort，例如：

```bash
LC_ALL=C sort -u
```

不要先用 `sort -V` 再直接交給 `comm`；version sort 與 `comm` 要求的 lexical ordering 不相同。需要顯示人類易讀的版本順序時，可以在 `comm` 完成後再 `sort -V`。

remote tag mutation 時只明確指定已驗證的 create/delete refs。多個 refs 一起更新時優先使用 atomic push；不要使用 `git push --tags`、`git push --force --tags`，也不要 force-update retained base tags。

mutation 後重新比對 retained branch/base-tag set 與 tag identities。只有 remote refs 與預期完全一致，才算 synchronization 完成。

若 upstream 改寫已存在的同名 `v*` tag，因 `remote.upstream.fetch` 的 tag refspec 沒有前導 `+`，正常 fetch 應停止而不是強制覆寫 local tag。此時不要繞過保護，先 review upstream tag rewrite。

### 4.3 Single-worktree branch-switch hygiene

本 repository 預設使用單一 worktree：

```text
~/local-ai/opencode
```

平常 checkout `sky/vX.Y.Z`；需要操作 repository bootstrap policy 時可暫時切到 `main`。

release branch 的 dependency / build state 可能包含：

```text
node_modules/
.turbo/
.opencode/node_modules/
.opencode/package.json
.opencode/package-lock.json
.opencode/bun.lock
packages/**/node_modules/
packages/**/.turbo/
packages/**/dist/
packages/**/*.tsbuildinfo
```

這些 path 在 release branch 屬於 ignored generated / local state。切到與 upstream source history 分離的 `main` 時，Git 不會因 branch switch 自動刪除這些 untracked / ignored files。

因此 `main:.gitignore` 只忽略已知 generated state，避免單純切換 branch 就必須刪除並重建 dependency / build cache。

不要使用：

```text
/.opencode/
/packages/
```

之類的 blanket ignore。若 OpenCode product source 或其他非預期檔案出現在 `main`，應讓 `git status` 顯示，而不是由 ignore rule 隱藏。

`main:.gitignore` 只負責 single-worktree working-tree hygiene；release branch 自己的 source / build ignore policy 仍由該 release 的 `.gitignore` 管理。

---

## 5. GitHub fork 的預期 refs

整理完成後，Sky fork 預期只主動保存：

```text
Branches:
  main
  sky/vX.Y.Z

Tags:
  vX.Y.Z
```

例如：

```text
Branches:
  main
  sky/v1.18.18
  sky/v1.18.19

Tags:
  v1.18.18
  v1.18.19
```

官方 stable `vX.Y.Z` tags 保留在 Sky fork，作為 `sky/vX.Y.Z` base reference。

但 release tag 的 authoritative source 仍然是 `upstream`。

不需要在 Sky fork mirror：

```text
dev
feature/*
fix/*
other upstream development branches
unrelated upstream tags
```

---

## 6. Fresh clone

新電腦或新 WSL：

```bash
mkdir -p ~/local-ai
cd ~/local-ai

git clone \
    --single-branch \
    --no-tags \
    git@github.com:skybeLTC/opencode.git
cd opencode
```

clone 完預設會進入 `main`。

`--single-branch` 讓 initial clone 只取得 GitHub default branch；後續需要的 `sky/*` refs 由 bootstrap script 明確 fetch。

`--no-tags` 避免 initial clone 從 `origin` auto-follow tags，並建立：

```text
remote.origin.tagOpt=--no-tags
```

正式 release tags 之後由 `upstream` 的 explicit `v*` refspec 取得。

接著執行 repository bootstrap：

```bash
./sky-tools/setup-local-repo.sh
```

無參數時，script 會在 fetch `origin` / `upstream` 後，自動選擇 `origin/sky/vX.Y.Z` 中版本最高的 **adopted release**。

例如 `origin` 目前最高 adopted branch 是：

```text
origin/sky/v1.18.18
```

則自動選擇：

```text
sky/v1.18.18
```

這不會採用 upstream 最新 available release。即使 upstream 已有較新的 `vX.Y.Z` tag，只要對應的 `origin/sky/vX.Y.Z` 尚未存在，就不會自動建立它。

若要明確指定某個已 adopted release：

```bash
./sky-tools/setup-local-repo.sh sky/v1.18.18
```

這會：

1. 保留目前 `origin` URL，不自動改寫 clone transport。
2. 將 `origin` fetch policy 設成只取得：
   - `main`
   - `sky/*`
3. 設定：
   ```text
   remote.origin.tagOpt=--no-tags
   ```
4. 建立或修正：
   ```text
   upstream = git@github.com:anomalyco/opencode.git
   ```
5. 將 `upstream` fetch policy 設成：
   - `dev`
   - `v*` tags
6. 設定：
   ```text
   remote.upstream.tagOpt=--no-tags
   ```
7. fetch `origin` 與 `upstream`。
8. 若未指定 target，從 `origin/sky/vX.Y.Z` 自動選擇版本最高的 adopted release。
9. 建立或切換到選定的 `sky/vX.Y.Z` local branch。
10. 明確設定該 local release branch tracking：
    ```text
    origin/sky/vX.Y.Z
    ```

無參數不再代表「只初始化 remote policy」。它會初始化 / normalize repository policy、fetch refs，然後切換到最新 adopted `sky/vX.Y.Z`。

script 必須可以安全重複執行；重跑不應建立重複 refspec，也不應因 local release branch 已存在而遺失或保留錯誤的 upstream tracking。

### 6.1 重跑 bootstrap

`sky-tools/setup-local-repo.sh` **只存在於 `main`**。

第一次執行通常直接：

```bash
./sky-tools/setup-local-repo.sh
```

script 會自動選擇 `origin/sky/vX.Y.Z` 中版本最高的 adopted release 並切換過去。

若需要明確指定：

```bash
./sky-tools/setup-local-repo.sh sky/v1.18.18
```

完成後 worktree 會位於選定的 release branch。因此 release branch 內不會再看到 `sky-tools/setup-local-repo.sh`。這是 branch responsibility separation 的預期結果，不是檔案遺失。

release branch 可以有自己的：

```text
sky-tools/build-local.sh
sky-tools/check-release.sh
```

但 repository bootstrap tool 只由 `main` 維護。

需要重跑 bootstrap 時：

```bash
git switch main
./sky-tools/setup-local-repo.sh
```

若要指定 release：

```bash
git switch main
./sky-tools/setup-local-repo.sh sky/v1.18.18
```

不要為了方便重跑而把 `sky-tools/setup-local-repo.sh` 複製進 `sky/vX.Y.Z`。

若只想從 release branch 查看 script：

```bash
git show main:sky-tools/setup-local-repo.sh
```

### 6.2 已驗證的 bootstrap contract

此流程已用真正的 fresh clone 驗證：

```text
initial clone
├── --single-branch
├── --no-tags
└── main only

first bootstrap
├── fetch origin/main + origin/sky/*
├── fetch upstream/dev + upstream v*
├── select latest adopted origin/sky/vX.Y.Z when no target is given
├── create/reuse the selected local release branch
├── set tracking to the matching origin/sky/vX.Y.Z
└── verify the matching vX.Y.Z base ancestry

second bootstrap from main
├── preserves the same fetch policy
├── does not duplicate refspecs
├── reselects/reuses the latest adopted release when no target is given
├── restores/keeps correct tracking
└── returns to the selected sky/vX.Y.Z branch

explicit-target bootstrap
├── accepts an explicit sky/vX.Y.Z target
├── preserves the same fetch policy without duplicate refspecs
├── reuses the selected local release branch
├── restores/keeps tracking to the matching origin/sky/vX.Y.Z
└── verifies the matching vX.Y.Z base ancestry
```

驗證重跑時必須先回到 `main`，因為 `sky-tools/setup-local-repo.sh` 本身不屬於 release branch。

此 bootstrap script 不主動刪除既有 stale remote-tracking refs；remote cleanup 屬於 migration / maintenance 操作，不應隱含在一般 bootstrap 中。

---

## 7. Bootstrap 後確認

確認 remote：

```bash
git remote -v
```

確認 config scope 與來源：

```bash
git config --show-origin --show-scope --get-regexp \
  '^(remote\.(origin|upstream)\.|branch\.)'
```

確認 fetch policy：

```bash
git config --get-all remote.origin.fetch
git config --get remote.origin.tagOpt

git config --get-all remote.upstream.fetch
git config --get remote.upstream.tagOpt
```

預期：

```text
+refs/heads/main:refs/remotes/origin/main
+refs/heads/sky/*:refs/remotes/origin/sky/*
--no-tags

+refs/heads/dev:refs/remotes/upstream/dev
refs/tags/v*:refs/tags/v*
--no-tags
```

確認 remote-tracking branches：

```bash
git for-each-ref \
  --format='%(refname:short)' \
  refs/remotes/origin \
  refs/remotes/upstream
```

正常情況應主要只有：

```text
origin/HEAD
origin/main
origin/sky/vX.Y.Z

upstream/HEAD
upstream/dev
```

其中 `origin/HEAD` / `upstream/HEAD` 是 remote default branch symbolic ref，不是額外的 source branch。

---

## 8. 進入 release maintenance

切到：

```bash
git switch sky/v1.18.18
```

之後 release-specific 操作以該 branch 的：

```text
SKY_README.md
```

為準。

查看：

```bash
less SKY_README.md
```

`SKY_README.md` 應負責：

```text
stable base
build
versioning
local patch policy
validation
release migration
AI source-editing rules
```

repository-level Git remote / fetch bootstrap 則以本 `main:README.md` 與：

```text
main:sky-tools/setup-local-repo.sh
```

為準。

在 release branch 中需要重新查看 repository bootstrap policy時：

```bash
git show main:README.md
git show main:sky-tools/setup-local-repo.sh
```

---

## 9. AI Agent Rules

AI 在此 repository 工作時，預設遵守以下規則。

### Rule 1 — 先確認目前 branch

任何修改前先執行：

```bash
git status
git branch --show-current
```

不要把 `main` 當 OpenCode source branch。

### Rule 2 — `main` 只管理 repository bootstrap

不要把 OpenCode source、product patch、build output 或 release-specific maintenance change 放進 `main`。

### Rule 3 — `sky/vX.Y.Z` 只管理對應 stable release

不要把：

```text
upstream/dev
```

直接 merge / rebase / pull 到：

```text
sky/vX.Y.Z
```

### Rule 4 — 不建立不必要的 `dev` mirror

官方 development reference 使用：

```text
upstream/dev
```

不要預設建立：

```text
local dev
origin/dev
```

### Rule 5 — upstream release tags 是 authoritative source

local release base tags 由 `upstream` fetch。

Sky fork 保存 strict official `vX.Y.Z` tags 作為 archival/base reference，但 `origin` 只是 archive，不是 release tag authority。

新的 official stable tag 被 fetch 到 local 後，不會自動 publish 到 `origin`。需要同步 archive 時，依 Section 4.2 先驗證 exact tag set / identity，再只 push 明確缺少的 strict stable tags；不要使用 `git push --tags`，也不要 force-update 既有 tag。

### Rule 6 — 不把 local maintenance push 到 upstream

Sky-specific branches只 push 到：

```text
origin
```

### Rule 7 — 不修改 machine/global Git config

repository bootstrap 預設只修改：

```text
.git/config
```

不要在沒有明確需求時修改：

```text
~/.gitconfig
/etc/gitconfig
```

---

## 10. Maintenance philosophy

此 fork 的優先順序：

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

Repository bootstrap 與 release maintenance 分開，是為了讓：

```text
fresh clone
local Git policy
stable release source
local patches
build artifacts
```

各自有明確責任與可追蹤來源。
