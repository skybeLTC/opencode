# Sky OpenCode Maintenance Fork

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
└── setup-local-repo.sh
    └── repository bootstrap / Git remote policy

sky/vX.Y.Z
├── OpenCode source
├── SKY_README.md
├── build-local.sh
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
setup-local-repo.sh
```

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

`git fetch upstream` 的角色是更新官方 observation refs，不代表 Sky 自動採用新版。

必須區分：

```text
latest upstream stable
!=
currently adopted Sky release
```

看到新的官方 `vX.Y.Z` tag，只代表該 release **available**。預設不因此：

- 建立新的 `sky/vX.Y.Z` branch。
- 修改目前 adopted release branch。
- migration local patches。
- rebuild / publish 新版本。

Sky 可以繼續維護目前 adopted release，也可以明確決定跳過一個或多個中間 stable releases。

真正採用新版時，才依目前 release branch 的 `SKY_README.md` 執行 release adoption / migration。

### 4.2 Single-worktree branch-switch hygiene

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
./setup-local-repo.sh sky/v1.18.18
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
8. 建立或切換到指定的 `sky/vX.Y.Z` local branch。
9. 明確設定該 local release branch tracking：
   ```text
   origin/sky/vX.Y.Z
   ```

若只要初始化 Git remote policy、不切換 release branch：

```bash
./setup-local-repo.sh
```

script 必須可以安全重複執行；重跑不應建立重複 refspec，也不應因 local release branch 已存在而遺失或保留錯誤的 upstream tracking。

### 6.1 重跑 bootstrap

`setup-local-repo.sh` **只存在於 `main`**。

第一次執行：

```bash
./setup-local-repo.sh sky/v1.18.18
```

完成後 script 會切到：

```text
sky/v1.18.18
```

因此目前 worktree 內不會再看到 `setup-local-repo.sh`。這是 branch responsibility separation 的預期結果，不是檔案遺失。

需要重跑 bootstrap 時：

```bash
git switch main
./setup-local-repo.sh sky/v1.18.18
```

不要為了方便重跑而把 `setup-local-repo.sh` 複製進 `sky/vX.Y.Z`。

若只想從 release branch 查看 script：

```bash
git show main:setup-local-repo.sh
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
├── create/switch sky/v1.18.18
├── set tracking to origin/sky/v1.18.18
└── verify v1.18.18 ancestry

second bootstrap from main
├── preserves the same fetch policy
├── does not duplicate refspecs
├── reuses the existing local release branch
├── restores/keeps correct tracking
└── returns to a clean sky/v1.18.18 worktree
```

驗證重跑時必須先回到 `main`，因為 bootstrap script 本身不屬於 release branch。

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
main:setup-local-repo.sh
```

為準。

在 release branch 中需要重新查看 repository bootstrap policy時：

```bash
git show main:README.md
git show main:setup-local-repo.sh
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

Sky fork 可保存正式 `vX.Y.Z` tags作為 archival/base reference，但不要把 `origin` 當 release tag authority。

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
