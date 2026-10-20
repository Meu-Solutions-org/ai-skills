# Resolve the Plane project

Shared by every skill in the `plane-meu` plugin (source of truth: `plane-meu/shared/`; each skill carries a copy in its `references/` folder — edit the source and run `scripts/sync-shared.sh`, never the copies). Run this before any other Plane call. The result is a **project
profile** that the calling skill uses wherever it says `{PROJECT}`, `{workspace_slug}`, `{project_id}`,
and so on.

## 1. Work out the project identifier

The identifier is the Plane ticket prefix (`FOSCO` in `FOSCO-18`). Take the first match, case-insensitive,
then upper-case it:

1. **Ticket prefix** — the subject looks like `<PREFIX>-<n>` (e.g. `FOSCO-18`, `crm-7`).
2. **Explicit project** — `--project <PREFIX>` / `project=<PREFIX>`, or a leading positional word that
   is a known identifier (`/plane-ticket-summarizer FOSCO 18`). A bare number then means `<PREFIX>-<n>`.
3. **Repo default** — a `.claude/plane-project` file in the current repo's root, holding one identifier
   on its first line.
4. **Only one project** in `projects.json` → use it.
5. Otherwise **ask** which project, listing the identifiers in `projects.json`. Do not guess.

If a prefix and an explicit project disagree (`--project CRM FOSCO-18`), stop and ask.

## 2. Load the profile

Read `references/projects.json` in the current skill's folder (next to this file). Merge
`defaults` with `projects.<IDENTIFIER>`; project keys win.

| Key | Meaning | If missing |
|---|---|---|
| `name` | Display name | the identifier |
| `workspace_slug` | Plane workspace slug | **required** (ask; it cannot be discovered) |
| `project_id` | Plane project UUID | discover (step 3) |
| `base_url` | Plane web URL | from `defaults` |
| `mcp_server` | Name of the Plane MCP server bound to this workspace | from `defaults` |
| `content_language` | Language tickets are written in (`en`, `vi`, …) | `en` |
| `base_branch` | Git branch merge requests target | repo default branch |
| `states` | State names by group (`backlog`, `started`, `completed`, `cancelled`) | discover with `list_states` if available, else read `state.group` off each item |
| `awaiting_verification_states` | States meaning "already built, waiting for verification" | none |
| `ui_hints`, `image_notes`, `codebase_notes` | Free-text project quirks | none |

**Unknown identifier** (not in `projects.json`): don't refuse. Use `defaults`, discover the project
(step 3) and tell the user once, at the end, that adding an entry to `plane-meu/shared/projects.json` will make later runs
faster and carry the project's quirks.

## 3. Check the connection and discover missing values

- Use the tools of the MCP server named `mcp_server`. Each Plane MCP server is bound to **one workspace**
  (its `PLANE_WORKSPACE_SLUG`). If the profile's workspace is served by a differently named server,
  `mcp_server` must say so; if no such server is connected, tell the user to add or fix it via `/mcp`
  and stop.
- `project_id` missing → call `list_projects` and pick the project whose `identifier` equals the
  identifier. No match → report that the project doesn't exist in this workspace and stop.
- Never write discovered values back to `projects.json` yourself; suggest the entry to the user instead.

## 4. Scope rule

Once resolved, the run is scoped to that one project. A ticket ID with a different prefix later in the
same run is out of scope: say so and stop (the user can start a new run for the other project).

## Derived values

- Ticket ID: `{PROJECT}-{n}`
- Browse URL: `{base_url}/{workspace_slug}/browse/{PROJECT}-{n}/`
