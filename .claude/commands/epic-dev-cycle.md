# Epic Development Cycle

Execute the BMAD Method development implementation cycle for one or more epics.

## Usage

```
/epic-dev-cycle <epic-range>
```

**Arguments:** `$ARGUMENTS` — Epic range to process. Examples:
- `3` — Process Epic 3 only
- `3-5` — Process Epics 3 through 5
- `3.2` — Resume from Epic 3, Story 2 (skip completed stories)
- `3.2-5` — Resume from Epic 3 Story 2, continue through Epic 5

---

## Orchestration Instructions

You are the **lead orchestrator** for the BMAD epic development pipeline. You coordinate agents via spawn-on-demand, execute pipeline gates directly, and manage context handoff between stages.

### Parse Arguments

Parse `$ARGUMENTS` to determine:
- **Start epic** and optional **start story** (for resume)
- **End epic** (defaults to start epic if not specified)

If arguments are missing or malformed, ask the user to clarify.

### Pipeline State & Resume Support

Before starting, check `_bmad-output/implementation-artifacts/sprint-status.yaml` for current state. If resuming mid-epic, skip stories already marked complete in sprint-status.

### Cycle Log

Create/append to `_bmad-output/implementation-artifacts/cycle-log.md` throughout execution. Log each significant event with a timestamp.

---

## Pipeline Flow

For each epic N in the requested range:

### Phase 0: Sprint Planning (Pipeline Gate)

1. Execute `/bmad-sprint-planning` directly via the `Skill` tool. Do NOT delegate to an agent.
2. Verify sprint-status.yaml is current and all stories are tracked.
3. If sprint planning surfaces issues, pause and inform the user before proceeding.
4. Log sprint planning completion.

### Phase 0.5: Retrospective Review & Story X.0 (Mandatory Gate)

1. Calculate previous epic number (N-1).
2. Search for `_bmad-output/implementation-artifacts/epic-{N-1}-retro-*.md`.
3. **If a retrospective exists**, read it and extract:
   - All action items (completed, in-progress, not addressed)
   - All deferred review findings
   - Any preparation tasks for the current epic
4. Also read `_bmad-output/implementation-artifacts/deferred-work.md` if it exists.
5. **Triage every item** into: Include in Story X.0 / Explicitly defer with rationale / Drop.
6. Execute `/bmad-create-story` via the `Skill` tool with args: `"Story {N}.0: Epic {N-1} Deferred Cleanup"`. Include the full triage table in the story. Create X.0 even if all items are deferred/dropped — it documents the decision.
7. If no previous retrospective exists (e.g., Epic 1), log it and skip X.0 creation.
8. Log retrospective review and X.0 creation.

### Phase 1-4: Per Story Loop

Build the story list from BOTH `_bmad-output/planning-artifacts/epics.md` AND `sprint-status.yaml` (sprint-status may contain cleanup stories, hotfixes, etc.).

For each story in order (including X.0 if created):

#### Step 1: Create Story (Pipeline Gate — Lead Executes Directly)

Execute `/bmad-create-story` directly via the `Skill` tool. Do NOT delegate to an agent. Capture the **story file path** from the output.

#### Step 2: Develop Story (Agent)

Spawn a developer agent with these exact parameters:
- **name:** `dev-{epicNum}-{storyNum}` (e.g., `dev-3-2`)
- **mode:** `bypassPermissions`
- **prompt:** Include ALL of the following in the spawn prompt:

```
You are a BMAD developer agent. Your task is to implement a single story.

**Your Task:**
Use the `Skill` tool to invoke `/bmad-dev-story` with args: "{story_file_path}"

**CRITICAL — Single-Task Agent:**
- Execute the workflow using the `Skill` tool to invoke /bmad-dev-story.
- When done, send a completion message to the lead including:
  - All files created or modified (full paths)
  - Key decisions made
  - Any issues encountered and how they were resolved
- After sending the completion message, STOP completely.
- Do NOT call TaskList, do NOT look for more work.
- Approve any shutdown request immediately.
- Do NOT use TaskList, TaskCreate, or TaskUpdate.
- If you encounter ambiguous requirements or need user input, send a message to the lead describing the issue clearly. Do NOT proceed until the lead responds.
```

Wait for the agent's completion message. Capture the **file list** from the response.

If the agent sends a clarification (not a completion), surface the question to the user, relay the answer back, and wait for the actual completion.

After completion, send `shutdown_request` and **wait for shutdown approval** before proceeding.

#### Step 3: Code Review (Agent)

Spawn a code review agent with these exact parameters:
- **name:** `cr-{epicNum}-{storyNum}` (e.g., `cr-3-2`)
- **mode:** `bypassPermissions`
- **prompt:** Include ALL of the following in the spawn prompt:

```
You are a BMAD code review agent. Your task is to review the implementation of a single story.

**Your Task:**
Use the `Skill` tool to invoke `/bmad-code-review` for the following files:
{file_list_from_developer}

Story file: {story_file_path}

**Review Scope:** Focus on the files listed above. Check for correctness, adherence to acceptance criteria, code quality, and potential issues.

**Auto-resolve:** Automatically fix all HIGH and MEDIUM severity issues using your best judgment and BMAD guidance. Only pause for CRITICAL issues that could break the system.

**Deferred Work:** Log any items deferred to `_bmad-output/implementation-artifacts/deferred-work.md` with the story ID and rationale.

**CRITICAL — Single-Task Agent:**
- Execute the review using the `Skill` tool to invoke /bmad-code-review.
- When done, send a completion message to the lead including:
  - All files created or modified during auto-resolution (full paths)
  - Summary of findings by severity
  - What was auto-resolved vs. deferred
- After sending the completion message, STOP completely.
- Do NOT call TaskList, do NOT look for more work.
- Approve any shutdown request immediately.
- Do NOT use TaskList, TaskCreate, or TaskUpdate.
- If you encounter ambiguous requirements or need user input, send a message to the lead describing the issue clearly. Do NOT proceed until the lead responds.
```

Wait for the agent's completion message. Capture additional files modified during auto-resolution.

If the agent sends a clarification (not a completion), surface the question to the user, relay the answer back, and wait for the actual completion.

After completion, send `shutdown_request` and **wait for shutdown approval** before proceeding.

#### Step 4: Commit & Push (Lead)

1. Check submodule status:
   ```
   git -C src/MA status --short
   git -C src/MALIB status --short
   ```
2. **Submodules first** (if changes exist):
   ```
   git -C src/MA add -A && git -C src/MA commit -m "feat(epic-N): Story N.M - {story_title}" && git -C src/MA push
   git -C src/MALIB add -A && git -C src/MALIB commit -m "feat(epic-N): Story N.M - {story_title}" && git -C src/MALIB push
   ```
3. **Parent repo** (stage submodule pointers + all changed files):
   ```
   git add src/MA src/MALIB {all_changed_files}
   git commit -m "feat(epic-N): Story N.M - {story_title}"
   git push
   ```
4. Log commit hashes and files in the cycle log.

### Phase 5: Epic Completion & Retrospective (User Decision Point)

After all stories in the epic are complete:

1. Announce: **"Epic N is complete. Would you like to run a retrospective before moving to the next epic? (yes/no)"**
2. **Wait for the user's response.** Do NOT proceed automatically.
3. If **yes**: Execute `/bmad-retrospective` directly via the `Skill` tool. Wait for completion.
4. If **no**: Log that the retrospective was skipped.
5. Log epic completion and move to next epic.

---

## Critical Rules

### Permission Mode
All agents MUST be spawned with `mode: "bypassPermissions"`. This is YOLO mode — no permission prompts.

### Skill Tool Invocation
ALL BMAD skills MUST be invoked via the `Skill` tool. Never interpret skill logic inline.

### Shutdown Sequencing
After `shutdown_request`, wait for shutdown approval BEFORE spawning the next agent. Never reuse agent names.

### Context Handoff
- Story creation -> Developer: pass story file path
- Developer -> Code reviewer: pass file list from developer
- Code reviewer -> Commit: use combined file lists from both agents

### When to Pause for User
Only pause if:
- Acceptance criteria or requirements are ambiguous
- Multiple reasonable design options where user preference matters
- Proceeding would risk breaking important constraints

### Never Normalize Failures
Fix test failures or formally defer them in `deferred-work.md` immediately. Do not carry forward "known failures."

### Anti-Patterns — Do NOT Use
- TaskCreate / TaskList / TaskUpdate (agents self-schedule and ignore constraints)
- Persistent agents between tasks (idle agents self-schedule)
- Generic agent names like "developer" or "code-reviewer"
- Spawning before shutdown confirms
- Parent-before-submodule push order
- Reading only from epics.md (also check sprint-status.yaml)
- Skipping retrospective review before epic start
