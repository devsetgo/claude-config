# In-progress work

When work will outlast this session (paused mid-task, a multi-step
plan, a decision still pending), keep its plan, decisions made, and next
step under an `## In progress` heading at the top of the project's
gitignored `TODO_TASKS.md`. Add the `.gitignore` entry if it's missing.
A SessionStart hook loads that section into each new session, so update
it when the state changes and delete it when the work is done. Format:
`skills/_shared/task-list.md` under `${CLAUDE_CONFIG_DIR:-~/.claude}`.
