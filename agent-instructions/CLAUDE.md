# Claude instructions: GitHub account routing

Use these instructions when Claude or Claude Code is asked to operate a local GitHub repository on a machine with multiple `gh` accounts.

## What to do

Use normal GitHub CLI commands:

```bash
gh pr list
gh issue list
gh pr view 123
gh pr checks 123
```

The local `gh` command may be wrapped by `ai-gh-account-router`. If the repository has `.ai-gh-account`, routed repo-scoped commands automatically use the tagged GitHub account.

## What not to do

Do not run:

```bash
gh auth switch
```

Do not infer account from the repo owner.

Do not write tokens to disk.

Do not commit `.ai-gh-account`.

When the runtime restricts network or credential access, run `gh auth status` and authenticated `gh` commands directly through its approved host/external execution mechanism. Never treat execution approval as authorization for a GitHub write.

If the wrapper exits `77` with `GH_EXTERNAL_EXECUTION_REQUIRED`, retry the same `gh` operation through approved external execution. Do not bypass the guard. It does not cover `git` commands or Git metadata writes.

## Setup check

Before repo operations, this is safe:

```bash
gh ai-account
```

If the tag is missing and account identity matters, ask the user which logged-in account to use, then run:

```bash
ai-gh-init
```

or, when the user has already specified the account:

```bash
ai-gh-init <github-account-name>
```

## Verification

To confirm routed identity:

```bash
gh api user --jq .login
```

Before an explicitly requested mutation, compare that login with `.ai-gh-account` and verify the routed target with `gh api repos/OWNER/REPO --jq .full_name`. Stop if host authentication or either check fails.

To inspect normal GitHub CLI auth without routing:

```bash
GH_AI_BYPASS=1 gh auth status
```
