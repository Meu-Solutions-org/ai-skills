---
name: plane-ticket-summarizer
description: >
  Summarize a work item from any Plane project (plane.meu-solutions.com) into a developer-friendly brief:
  what it is, what to implement, and the deadline if any. Also checks whether the item has a parent (and
  whether that parent is planned), and for UI-related items checks whether screenshots/design links are
  available. Use whenever the user asks to summarize, explain, break down, or get the TL;DR of a Plane
  ticket — e.g. "summarize FOSCO-18", "what does CRM-9 say?", "what do I need to do for FOSCO-65?", or any
  mention of a `<PROJECT>-<number>` ID alongside intent to understand the work. The project comes from the
  ID prefix; projects and their quirks are listed in `references/projects.json`.
argument-hint: '<PROJECT-n | [PROJECT] n> [--project <PROJECT>]'
compatibility:
  connectors:
    - Plane MCP server (pinned `plane-mcp-server==0.2.9` — tool names below are from that version; server name per project in `projects.json`)
---

# Plane Ticket Summarizer

Produce a concise summary of one Plane work item for a **mid-level developer (2-5 years)**: skip basics,
surface non-obvious requirements, be specific about what to build.

## Step 0 — Resolve the project

Follow `references/resolve-project.md` (in this skill's folder) with the user's
arguments. Accepted forms: `FOSCO-18`, `FOSCO 18`, `18 --project FOSCO`, or `18` when a repo default or a
single project applies. No ticket number → ask for it.

From here on `{PROJECT}`, `{project_id}`, `{states}`, `{content_language}`, `{ui_hints}`,
`{image_notes}` and `{awaiting_verification_states}` come from the resolved profile.

## Rules

- **Read-only.** Never create, update, comment on, or delete anything in Plane from this skill.
- **Verbatim terms.** Keep the ticket's original title, column names, UI labels, and quoted formulas
  verbatim in every output language — they are what the developer will search the code/UI for.
- **Output language: English by default.** Write the summary in another language only when the developer
  asks for it ("in Vietnamese", "bằng tiếng Việt") or writes their request in that language. An explicit
  language request always wins over the language of the prompt. Translate only the headings/labels and
  your own prose; the structure, emoji, and checklist format stay identical. For Vietnamese use the labels
  below; for any other language translate the English labels faithfully.

| English | Tiếng Việt |
|---|---|
| State | Trạng thái |
| Priority | Độ ưu tiên |
| Assignee(s) / Unassigned | Người thực hiện / Chưa phân công |
| Parent | Ticket cha |
| Planned / NOT planned | Đã lên kế hoạch / CHƯA lên kế hoạch |
| What this is about | Nội dung ticket |
| Design context | Tài liệu thiết kế |
| What to implement | Cần triển khai |
| Subtasks | Ticket con |
| Deadline / No deadline set. | Hạn chót / Chưa có hạn chót. |
| Due / Soon / Overdue | Hạn / Sắp đến hạn / Quá hạn |
| Notes & watch-outs | Lưu ý |

  Vietnamese parent-not-planned warning: *⚠️ Ticket cha chưa được lên kế hoạch — nên lên kế hoạch cho
  ticket cha trước, vì yêu cầu của ticket này có thể thay đổi.*
  Vietnamese missing-design question: *Ticket này liên quan đến giao diện nhưng mình không thấy ảnh
  chụp hoặc link thiết kế đọc được — bạn có thể gửi tài liệu tham chiếu không?*

## Step 1 — Fetch the work item

Call `retrieve_work_item_by_identifier` with `work_item_identifier="{PROJECT}-<n>"` and
`expand="assignees,labels,state"`. **Do not** put `parent` in `expand` — it crashes on this server
(validation error). Do not pass `fields`; the full record includes `description_html`.

You need from the result: `id`, `name`, `description_html`, `priority`, `state` (name + group),
`assignees[].display_name`, `labels`, `start_date`, `target_date`, `parent` (a work item UUID or null),
`sequence_id`.

If the call fails with a 404/not-found, report that the item doesn't exist in {PROJECT}. If the Plane
connection errors, tell the user to check `/mcp` instead of retrying blindly.

## Step 2 — Gather supporting context

Using the item's `id` and `{project_id}`:

- `list_work_item_comments` — comments often hold clarifications or decisions that supersede the description.
- `list_work_item_attachments` — metadata only (name, content_type). Use `get_work_item_attachment_download_url` only if an image attachment needs viewing.
- `list_work_item_links` — external links (Figma, docs, PRs).
- `list_work_item_relations` — blocking / blocked_by / relates_to / duplicate. Mention these; don't fetch the related items unless asked. This endpoint returns `HTTP 404` on this Plane version: treat that as "relations unavailable", skip it silently, and don't report it as an error or retry.

Children: the PQL `childOf(...)` filter is **ignored** on this Plane version (it returns every item), so
don't use it. Instead call `list_work_items` with `{project_id}`, `per_page=100`,
`fields="id,name,sequence_id,parent,priority"`, `expand="state"`, and keep only entries whose `parent`
equals this item's `id`. If the project has more than 100 items, page through all of them. If none
match, there are no subtasks — omit that section.

## Step 3 — Parent check

If `parent` is null, skip this step and do not mention parents in the output.

If `parent` is set: fetch it with `retrieve_work_item` (`{project_id}`, `work_item_id=<parent uuid>`,
`expand="state"`). Judge whether it is **planned**:
- has a written description with scope/requirements (not just a title)
- has child items already broken out
- state group is beyond `backlog` (i.e. `started` or later)
- has acceptance criteria or a linked spec

If not planned, flag it prominently: implementing a subtask of an unplanned parent is risky because scope may shift.
Still summarize the subtask.

## Step 4 — Design context (UI-related items only)

An item is UI-related if the title/description/labels mention pages, screens, columns, tables,
popups, layout, display, or styling. Apply `{ui_hints}` if the profile has them. Skip this step otherwise.

Look for design context in, in order:
1. `<img src=...>` tags inside `description_html` — screenshots are often embedded inline rather than attached. Apply `{image_notes}` if present (e.g. expiring CDN URLs).
2. Image attachments from `list_work_item_attachments`.
3. Figma or mockup links from `list_work_item_links` or the description text.

Try to view images that are reachable. If there is no design context, or the images are present but
unreadable/expired, say so plainly and **ask the user for the reference** before finalizing; a draft of
the non-visual parts is fine meanwhile. Never guess visual details.

## Step 5 — Write the summary

Convert `description_html` to plain text first (strip tags, keep list structure; note embedded images
as "N screenshot(s)").

### Output format

Headings below are English; substitute translated labels when writing in another language.

## 📋 {PROJECT}-{n}: {title}

**State:** `{state}` · **Priority:** `{priority}` · **Assignee(s):** `{names or "Unassigned"}`
*(omit any field not present; `none` priority → omit)*

### Parent
*(only if the item has a parent)*
- **Parent:** {PROJECT}-{p} {title} — `Planned` / `NOT planned`
- If not planned: ⚠️ *This item's parent hasn't been scoped yet — recommend planning it first, as requirements may shift.*

### What this is about
One or two sentences: the problem or feature, in context.

### Design context
*(only for UI-related items)*
- `🖼️ Screenshot(s) embedded and reviewed` / `🎨 Link: {url}` / `⚠️ No readable design context — asked user`

### What to implement
Concrete, specific items from the description, comments, and subtasks. Name formulas, columns, tables,
screens, and expected-vs-actual behavior where given. Quote exact formulas/values from the ticket rather
than paraphrasing them.

- [ ] Item 1
- [ ] Item 2

### Subtasks
*(only if children exist)*
- **{PROJECT}-{n}** {title} — `{state}`

### Deadline
- `📅 Due: {target_date}` — add ⚠️ Soon (within 3 days) or 🔴 Overdue (past) where applicable
- or `No deadline set.` (if `start_date` exists you may mention it as "Started {date}")

### Notes & watch-outs
*(optional)* Ambiguities, relations (blocked by / blocking), contradictions between description and
comments, items whose state group is `completed`/`cancelled`, or a state listed in
`{awaiting_verification_states}` meaning the fix is already built and is awaiting verification rather
than new work.

End with the browse URL from the resolver.

## Edge cases

- **Empty description**: summarize from title, comments, and subtasks; say the description is empty and recommend clarifying before starting.
- **Cancelled or Done item** (state group `cancelled`/`completed`): still summarize, but state up front that it is closed and why, if a comment says so.
- **Very long description**: distill; don't reproduce verbatim.
- **Epic-like item** (has many children): list children as the implementation items and suggest drilling into individual ones.
- **Multiple assignees**: list all; don't assume who owns what.
- **No target date**: say "No deadline set." — never invent one.
