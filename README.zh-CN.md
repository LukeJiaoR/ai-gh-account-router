# ai-gh-account-router

[English](README.md) | [简体中文](README.zh-CN.md)

一个轻量的本地包装器，让多 GitHub 账号环境中的 GitHub CLI 使用更安全。

每个仓库都可以单独指定仓库级 `gh` 命令使用的账号，无需更改 GitHub CLI 的全局活动账号。账号选择仅保存在本地，不会被提交到仓库。

## 为什么需要它？

GitHub CLI 可以为同一主机保存多个账号，但命令通常使用一个活动账号。在自动化或 Agent 工作流中，这一点很容易被忽略，导致命令以错误的身份执行。

本工具通过一个仓库本地的账号标签解决这个问题：

```text
.ai-gh-account
```

文件中只保存一个 GitHub 登录名，例如：

```text
work-account
```

`ai-gh-init` 会将该文件加入 `.git/info/exclude`，因此账号选择只对当前克隆有效。

## 工作原理

安装后，Shell 会优先解析到 `~/.local/bin` 中的 `gh` 包装器。对于支持路由的仓库级命令，包装器会：

1. 查找当前仓库中的 `.ai-gh-account`。
2. 通过原始 GitHub CLI 获取该账号的令牌。
3. 仅为当前命令设置 `GH_TOKEN`。
4. 执行原始的 `gh` 程序。

如果标签不存在，或者命令不在路由范围内，则保持 GitHub CLI 的默认行为。空标签或无效标签会直接报错，不会回退到其他账号。

## 命令路由范围

存在仓库标签时，以下命令会使用指定账号：

```text
gh pr          gh issue       gh run          gh workflow
gh release     gh project     gh api          gh secret
gh variable    gh label       gh repo sync
```

全局命令和初始化命令不会被路由，包括：

```text
gh auth        gh config      gh repo clone   gh repo create
gh repo fork   gh repo view   gh extension    gh alias
gh gist        gh org         gh codespace    gh search
```

在 `gh repo` 命令组中，只有 `gh repo sync` 会被路由。

## 环境要求

- Git
- GitHub CLI（`gh`）
- Bash
- 至少一个已经通过 GitHub CLI 登录的 GitHub 账号

## 安装

```bash
git clone <repository-url>
cd ai-gh-account-router
./install.sh
```

安装器会将包装器和初始化命令放到：

```text
~/.local/bin/gh
~/.local/bin/ai-gh-init
```

重启 Shell，或重新加载配置和命令缓存：

```bash
source ~/.zshrc
hash -r
```

确认包装器在 `PATH` 中排在第一位：

```bash
which gh
type -a gh
```

原始 GitHub CLI 的路径会记录在 `~/.config/ai-gh/real-gh-path`。

### Agent 指令

交互式安装器可以将内置的 `SKILL.md` 安装到已有的受支持 Agent 目录、手动选择的目录、全部已知目录，或跳过安装。

非交互式安装可设置 `AI_GH_INSTALL_SKILLS`：

```bash
AI_GH_INSTALL_SKILLS=none ./install.sh
AI_GH_INSTALL_SKILLS=existing ./install.sh
AI_GH_INSTALL_SKILLS=all ./install.sh
AI_GH_INSTALL_SKILLS=codex,claude,agy ./install.sh
```

当标准输入不是交互终端且变量未设置时，安装器使用 `existing` 模式。只有明确选择后，安装器才会创建缺失的 Agent 目录。

对于无法自动发现技能的工具，`agent-instructions/` 中提供了可移植的指令模板。

## 配置仓库

在 Git 仓库中运行：

```bash
ai-gh-init
```

从 GitHub CLI 已登录的账号中选择一个。脚本也可以直接传入账号：

```bash
ai-gh-init work-account
```

查看本地标签并确认实际路由身份：

```bash
gh ai-account
gh api user --jq .login
```

之后，Agent 和脚本可以直接使用普通命令：

```bash
gh pr list
gh issue list
gh pr view 123
gh pr checks 123
```

在路由工作流中不要使用 `gh auth switch`，也不要根据仓库所有者推断应该使用哪个账号。

## 受限的 Agent 运行环境

在受限的 Codex seatbelt 中，需要认证的命令会在执行原始 `gh` 前停止，并输出：

```text
GH_EXTERNAL_EXECUTION_REQUIRED
```

包装器会以状态码 `77` 退出。请通过运行环境批准的外部执行机制重试同一命令。本地帮助、版本信息和路由诊断命令仍可使用。

外部执行批准只代表允许访问凭据存储或网络，并不代表允许修改 GitHub 资源。Agent 在创建或修改远程资源前仍需获得明确授权。

## 仓库同步

路由器不会影响 `git pull`、`git fetch` 或 `git push`，因为 Git 使用独立的认证路径。

如需使用 GitHub CLI 原生的同步操作，可以运行：

```bash
gh repo sync
gh repo sync --branch main
gh repo sync --source upstream-owner/upstream-repo --branch main
```

`gh repo sync` 不能完全替代 `git pull`；涉及本地合并或变基的工作流仍应直接使用 Git。

## 安全模型

- 令牌不会写入仓库。
- 本地标签只包含账号登录名。
- 标签通过 `.git/info/exclude` 排除。
- 只有白名单中的少量命令会被路由。
- `GH_TOKEN` 仅对单次命令调用生效。
- 空标签和无效标签会直接报错。
- 全局 GitHub CLI 命令保持默认行为。
- 未经明确选择，不会创建 Agent 技能目录。

本工具只负责 GitHub CLI 的认证路由。多账号 Git 操作仍需单独配置 SSH 别名或 Git 凭据助手。

## 临时绕过

如需让某条命令直接使用原始 GitHub CLI：

```bash
GH_AI_BYPASS=1 gh auth status
```

## 卸载

```bash
./uninstall.sh
hash -r
```

卸载器会移除包装器、`ai-gh-init` 和已安装的内置 Agent 技能副本。它不会删除原始 GitHub CLI，也不会退出任何账号。

## 许可证

[MIT](LICENSE)
