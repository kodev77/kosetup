---
name: no-commit-without-request
description: Never run git commit or push unless the user explicitly asks in that turn; leave changes in the working tree for review
metadata: 
  node_type: memory
  type: feedback
  originSessionId: dba53a4e-5423-414e-b9ad-52e4c9b30c52
  modified: 2026-08-18T21:12:19.200Z
---

Do not `git commit` or `git push` unless the user asks for it in that specific
turn. Make the edit, verify it, report what changed, and stop — leave the change
sitting in the working tree.

**Why:** Ko reviews diffs in lazygit as work progresses. Committing on his behalf
skips that review step and buries the change in history before he has seen it. An
explicit "commit and push it" on one change is permission for that change only —
it is not a standing pattern to carry into later turns.

**How to apply:** After editing, run `git status`/`git diff --stat` so he can see
what is pending, say the change is uncommitted, and offer to commit if he wants.
Wait for him to ask. This holds even when several consecutive changes were
committed at his request earlier in the same session.
