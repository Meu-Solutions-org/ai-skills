# MeU AI skills

Team-only skills for working with Plane (`plane.meu-solutions.com`). They work in **Claude Code**,
**Codex**, and **ChatGPT**, for any Plane project listed in
[`plane-meu/shared/projects.json`](plane-meu/shared/projects.json).

| Skill | What it does | Example |
|---|---|---|
| `plane-ticket-summarizer` | Developer brief of one ticket (read-only) | `FOSCO-18` |
| `write-ticket` | Drafts a full ticket, writes to Plane only after you accept | `FOSCO "Export payslip"` or `FOSCO-42` |
| `feature-workflow` | Plan → implement → review → QA → PR | `FOSCO-18` or a feature description |

The project comes from the ticket prefix (`FOSCO-18` → FOSCO). For a new ticket, name the project first
(`FOSCO "title"`) or pass `--project FOSCO`.

## Layout

```
ai-skills/
├── .claude-plugin/marketplace.json   Claude Code marketplace (this repo)
└── plane-meu/                        the plugin
    ├── .claude-plugin/plugin.json
    ├── shared/                       SOURCE OF TRUTH — edit here
    │   ├── projects.json             one entry per Plane project
    │   └── resolve-project.md        how a skill picks the project
    ├── skills/<skill>/
    │   ├── SKILL.md
    │   └── references/               generated copies of shared/ — do not edit
    └── scripts/
        ├── sync-shared.sh            copy shared/ into every skill (--check for CI)
        └── install.sh                codex | claude | zip
```

Each skill folder is self-contained because Codex and ChatGPT load a skill folder on its own.

## Install

### Claude Code (recommended: plugin)

```
/plugin marketplace add <git URL of this repo>
/plugin install plane-meu@meu-ai-skills
```

Skills are then called with the plugin prefix: `/plane-meu:plane-ticket-summarizer FOSCO-18`. Update with
`/plugin marketplace update meu-ai-skills`. For a local checkout, `/plugin marketplace add ./path/to/ai-skills` also works.

### Codex

```bash
plane-meu/scripts/install.sh codex
```

Symlinks each skill into `~/.codex/skills/` (or `$CODEX_HOME/skills/`); `git pull` keeps them current.

### ChatGPT (web/desktop app)

```bash
plane-meu/scripts/install.sh zip
```

Upload each `plane-meu/dist/<skill>.zip` via **Skills → Create → Upload from your computer** (your
workspace admin must allow skill uploads). Re-upload after changes. Zips are not committed.

## Plane connection (required in every tool)

The skills call the Plane MCP server (`plane-mcp-server==0.2.9`). Each server connection is bound to one
workspace and authenticates with your own Plane API key — never commit the key.

- **Claude Code:** add the `plane` server to the project repo's `.mcp.json` (copy the block from the FOSCO
  repo) with the API key taken from an environment variable.
- **Codex:** add the same server under `[mcp_servers.plane]` in `~/.codex/config.toml`.
- **ChatGPT:** ChatGPT cannot start a local server; it needs Plane exposed as a remote MCP connector added by
  a workspace admin. Without it, the skills can only work from text you paste in.

If a project lives in another workspace, add a second server (e.g. `plane-acme`) and set `mcp_server` for
that project in `projects.json`.

## Add a project

1. Add an entry under `projects` in `plane-meu/shared/projects.json`, keyed by the ticket prefix. Only
   `workspace_slug` is required; `project_id` is looked up if missing. Copy the FOSCO entry for the other
   keys (`content_language`, `base_branch`, `states`, notes).
2. Run `plane-meu/scripts/sync-shared.sh`.
3. Commit. Bump `version` in `plane-meu/.claude-plugin/plugin.json` so Claude Code picks up the update;
   ChatGPT users re-upload the zips.

Optional: put the prefix in `.claude/plane-project` in a project repo so a bare `18` means `<PREFIX>-18` there.
