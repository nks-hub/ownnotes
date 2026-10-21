# OwnNotes redesign specification v2

OwnNotes is a writing-first Nextcloud notebook with live Markdown styling, explicit preview, reliable local saves, and recoverable interrupted work.

**Status:** Final design specification for implementation. This document replaces v1 completely. No repository files were modified and no device tests were performed while preparing it.

**Repository context:** Inspected HEAD `28dcddf`, with concurrent work in the working tree. Existing implementations must be checked before replacement. Historical review findings are not acceptance evidence for the current app.

## 1. Decisions on the v1 review

| Review point | Decision | Reason |
|---|---|---|
| 1. Delivery plan | Accept. Use three app waves followed by one widget wave, with ten packages in total. | Fewer ownership boundaries reduce coordination. The integration owner controls all localization and shared wiring. |
| 2. Live heading sizes | Improve. H1 uses 1.25× body size, H2 1.15×, H3–H6 weight only. | Live styling must be visible. A shared line grid limits vertical movement; preserving the editing value protects selection and composition. Some horizontal reflow remains unavoidable. |
| 3. Fonts | Accept system fonts for interface and proportional writing; bundle only a subset of upright Noto Sans Mono. | This avoids two bundled font families and preserves platform typography. Exact binary size remains a build measurement. |
| 4. Icon and store assets | Reject the unsolicited icon replacement in v1. Retain the published icon. Refresh screenshots for the redesigned interface. | The recently published identity does not need to change to support this redesign. An explicit future icon change has a complete asset checklist below. |
| 5. List status line | Accept collapse. Healthy account identity belongs inside the app bar. | A permanent “Personal · Up to date” row spends space without requiring action. |
| 6. Phone editor bar | Accept explicit sizing. At 411 dp, show icon buttons for Preview, Share, and overflow. Collapse document metadata while the body keyboard is open. | This preserves access to sharing and gives the S9 more writing space. |
| 7. Android widget technology | Replace Glance with RemoteViews XML. | The app already uses RemoteViews. The proposed widgets do not require another Android UI stack. |
| 8. Suggestions and Text preview | Accept as required scope in package E. | These features are already in `TODO.md`; they need defined appearance and behavior, not a later unspecified extension. |
| 9. Screenshot and German review | Accept. Define a screen checklist and exact overflow strings. | Abstract “German support” is insufficient for acceptance. |
| 10. Other v1 corrections | Improve preview interaction, scope boundaries, ownership, and evidence requirements. | Ordinary preview taps should not unexpectedly enter editing; native widgets need native tests; future backup and live collaboration work must not silently become redesign prerequisites. |

## 2. Scope and product rules

The redesign includes:

- Welcome, browser login, QR login, reauthentication, account switching, and account removal.
- Collections, categories, search, saved views, and bulk actions.
- Raw Markdown editing with live styling, suggestions, explicit preview, and checklist mode.
- Save and sync status, conflict comparison, pending deletions, and recovery.
- Attachments, voice capture, incoming content, and outgoing sharing.
- Settings, privacy, app lock, phone and tablet layouts.
- Configurable Android and iOS widgets.
- English, Czech, and German across Flutter, native surfaces, extensions, and store text.

Retain these invariants:

1. Opening a note normally opens raw Markdown. Content detection, previous visits, and server `noteMode` never select preview automatically.
2. Notes remain ordinary Nextcloud-compatible Markdown. Categories remain folders. Attachments follow verified server conventions.
3. “Saved on device” means local persistence completed. “Up to date” requires successful outgoing work and an incoming check.
4. Navigation waits for local persistence, not network upload.
5. Conflicts, failed deletions, captures, and pending attachments remain discoverable after restart.
6. Account identity is explicit for external content, sharing, recovery, and widgets.
7. Layout changes preserve the active controller, document identity, selection, composing range, scroll position, and undo history.
8. Untrusted images and link metadata do not cause automatic third-party requests.
9. Core flows work in cs/en/de, both themes, at 200% text, and with screen readers.

The redesign does not require completing a restorable full-backup format, server trash/version browsing, desktop builds, OCR, or live Nextcloud Text co-editing. Existing functionality remains available. Those separate milestones must not acquire misleading labels suggesting they are complete.

## 3. Design system

### 3.1 Visual direction and identity

Use warm paper surfaces, dark ink, and an ochre interaction accent.

The list is a continuous document index. The editor is a continuous writing surface. Avoid enclosing every row in a card, decorative textures, gradients, and oversized headings.

Keep the existing published OwnNotes app icon and its blue document mark. Use that artwork consistently in onboarding, About, and the launcher. Ochre is the interface accent, not a replacement launcher identity.

OwnTalk family resemblance comes from account presentation, form structure, control geometry, and navigation behavior.

### 3.2 Platform behavior

Material 3 provides the shared Flutter component foundation.

| Shared behavior | Android adaptation | iOS adaptation |
|---|---|---|
| Information architecture, color roles, save meanings, recovery actions | System/predictive back, native selection menus, pickers and authentication | Platform route transitions, edge-back navigation, native selection menus, pickers and authentication |
| Accessible controls | Minimum 48 dp targets | Shared Flutter controls use 48 logical pixels; native controls meet platform minimums |
| Account-aware browser login | Android browser handoff | Supported iOS browser authentication handoff |
| Adaptive forms and sheets | Android keyboard/inset behavior | iPad popover anchoring and keyboard behavior |

Do not build a second complete Cupertino interface.

### 3.3 Color roles

All values are opaque.

| Role | Light | Dark |
|---|---|---|
| Canvas | `#FAF8F3` | `#171714` |
| Document | `#FFFEFA` | `#20201C` |
| Raised surface / toolbar | `#F0EDE6` | `#2A2A24` |
| Primary text | `#25251F` | `#EEEDE5` |
| Secondary text / Markdown markers | `#5C5C52` | `#C1C1B4` |
| Control outline | `#78786C` | `#8F9082` |
| Accent / links / favorite | `#805400` | `#E9BE74` |
| On accent | `#FFFFFF` | `#322100` |
| Selected container | `#FFDEA6` | `#493715` |
| On selected container | `#392800` | `#FFDEA6` |
| Error foreground | `#B12C2C` | `#FFB4AB` |
| Error container | `#FCE8E6` | `#4D2323` |
| Success foreground | `#24634D` | `#91D5B3` |
| Success container | `#E0F3E8` | `#183C2D` |
| Decision foreground | `#7C4500` | `#FFBE80` |
| Decision container | `#FFE7CE` | `#462C15` |
| Information foreground | `#255E89` | `#A4C9ED` |
| Information container | `#E4EFF9` | `#19364D` |

Implementation rules:

- Normal text meets 4.5:1 contrast; meaningful control boundaries and graphics meet 3:1.
- Markdown markers use the secondary text role, without opacity reduction.
- Links are underlined.
- Selection includes a check or accent edge.
- Errors and decisions include text, not color alone.
- Focus uses a visible 2 px accent ring.
- Disabled controls expose their state semantically.
- Verify actual component pairings; a palette alone does not establish screen contrast.

### 3.4 Fonts and typography

Use platform typography for the interface, proportional editor, and preview:

- Android: Roboto through the platform font configuration.
- iOS: the system San Francisco font through the platform font configuration.
- Preserve system emoji and fallback fonts.
- Do not download fonts at runtime.

Bundle one **upright Noto Sans Mono variable font**, limited to the weights used by the app, for code and the optional monospace editor.

Subset coverage includes Basic Latin, Latin-1 Supplement, Latin Extended-A, combining marks needed by Czech/German text, and the punctuation used by the interface and Markdown. Other scripts use system fallback; notes are never restricted to the bundled character set.

**Size expectation:** approximately 80–180 KiB for the subset TTF, with a 250 KiB asset budget. This is a planning estimate, not a measured APK or IPA delta. Package F records the actual asset size and release-build size change. Do not ship full Noto Sans alongside it.

Code uses upright monospace. In monospace source mode, emphasis retains visible Markdown delimiters and may use weight; italic rendering remains available in proportional source mode and preview. Do not synthesize a separate mono italic family.

Ship the Noto Sans Mono OFL notice in app licenses.

| Role | Default size / line height | Weight |
|---|---:|---:|
| Welcome title | 30 / 38 | 600 |
| Screen title | 22 / 28 | 600 |
| Document title | 26 / 34 | 600 |
| Section heading | 18 / 26 | 600 |
| Note-row title | 17 / 24 | 600 |
| Body / form input | 16 / 24 | 400 |
| Source editor body | 17 / approximately 27 | 400 |
| Button | 15 / 22 | 600 |
| Metadata / helper | 13 / 19 | 400 |
| Preview code | 16 / 24 | 400 |

Respect platform text scaling without an app-wide clamp. Editor text-size preferences multiply the selected base size and continue to respect system scaling.

### 3.5 Live Markdown styling

All Markdown syntax remains visible and editable.

| Construct | Live source appearance |
|---|---|
| H1 | 1.25× editor body size, weight 600 |
| H2 | 1.15× editor body size, weight 600 |
| H3–H6 | Body size, weight 600 |
| Bold | Weight 700 |
| Italic | Italic in proportional mode |
| Strike | Strikethrough |
| Quote | Secondary styling; source markers remain visible |
| Link | Underlined link text; visible destination |
| Inline/fenced code | Upright monospace, subtle surface treatment |
| Task list | Visible Markdown marker; no replacement interactive control inside the text field |

Use a shared source-line grid based on approximately **1.6× the effective body size**. Heading runs fit within that grid; do not apply another 1.6 multiplier to their enlarged size. At 17 px body size, the target line advance is approximately 27 px.

Flutter struts can establish line metrics, but forced metrics can overlap larger glyphs. Validate accents, emoji, fallback scripts, selection rectangles, and caret height before forcing a fixed strut. Increase the common grid if necessary rather than clipping glyphs. [Flutter StrutStyle documentation](https://api.flutter.dev/flutter/painting/StrutStyle-class.html)

Caret stability means:

- Styling never rewrites text or changes selection offsets.
- No controller replacement, focus reset, or undo reset.
- An active composing range is not restyled until composition finishes.
- Preserve the caret’s viewport anchor when heading recognition changes wrapping.
- Do not animate source reflow.
- A heading may wrap earlier because its text is larger. This expected reflow must not move the caret to another source position.

Weight-only headings are not the default fallback. If a device exposes a rendering defect, fix the metrics or composition handling and verify the required sizes.

### 3.6 Geometry, motion, and feedback

| Token | Value |
|---|---|
| Spacing | 4, 8, 12, 16, 24, 32, 48 |
| Phone horizontal inset | 16; 20 on login |
| Tablet pane inset | 24 |
| Editor maximum measure | 720 logical pixels |
| Compact radius | 8 |
| Fields / buttons | 14 |
| Selected navigation item | 12 |
| Sheets / dialogs | 24 |
| Shared touch target | 48 logical pixels |

Use one outlined Material icon family at 24 px. Filled variants indicate selection or favorite. Back and share symbols may follow platform conventions.

Motion:

- Press feedback: 100 ms.
- Inline expansion: 160 ms.
- Pane/drawer transition: 220 ms.
- Sheet entry/exit: 280/200 ms.
- Explicit edit/preview transition: 120 ms crossfade.

Reduced motion removes translation and animated reordering. Incoming document changes never animate through the editor.

Use light haptics for completed task toggles, selection entry, and accepted drag actions. No haptics for typing, autosave, routine sync, or repeated errors.

## 4. Collections, navigation, and status

### 4.1 Note rows

Rows have content-driven height, approximately 92–104 logical pixels at default text.

```text
Meeting notes                              ☆
Decisions from Monday and the next steps…
Work / Planning                    Yesterday
```

- Title: up to two lines.
- Excerpt: up to two lines.
- Category and modification time: wrapping metadata.
- Important save/recovery state: its own labeled line.
- No fixed-height rows.

| State | Presentation |
|---|---|
| Favorite | Accent star; semantic “Favorite” |
| Checklist | Parser-derived “3 of 7 completed” |
| Attachment | Validated count when available; cached thumbnail only |
| Waiting | “Saved on device · Waiting to upload” |
| Uploading | “Uploading changes” |
| Conflict | Decision edge and “Needs your decision” |
| Shared | “Shared by Alex · Can edit” or “Shared · View only” |
| Pending deletion | “Deletion waiting” or “Deletion failed” in Needs attention |
| Unavailable | Cached content plus “Cannot refresh this note” and Retry |

State priority is decision, save/upload failure, pending work, then ordinary metadata. Do not assemble a single dense badge row.

Compute summaries outside scrolling from the shared Markdown model and attachment records. Excerpt extraction may suppress a duplicate opening title for display, without changing the note.

Default sorting is modification time descending. Title sorting and Favorites first are explicit preferences. Favoriting does not unexpectedly reorder the default list.

### 4.2 Categories and creation

Keep these destinations visible even when empty:

1. All notes
2. Favorites
3. Uncategorized
4. Shared with me
5. Needs attention

Then show saved views, category tree, and Settings.

Category behavior:

- Label selects the category and descendants.
- A separate 48 × 48 target expands children.
- Indentation is 16 px per level.
- After three visible levels, use subtree navigation and a breadcrumb.
- Names wrap; counts include descendants and expose that meaning.
- Expansion is local and account-specific.
- Empty local creation destinations do not claim a confirmed server folder.

Creation destinations:

| Current scope | New-note destination |
|---|---|
| Category | That exact category |
| Favorites | Uncategorized, favorite enabled |
| All notes | Uncategorized |
| Ambiguous saved view | Ask for category |

The create menu offers Note, Checklist, Template, and Daily note. Each creates ordinary Markdown and opens the source editor.

### 4.3 App bar and collapsing status

Normal phone app bar:

```text
[Categories] Notes                 [Search] [Account]
             Personal
```

The account subtitle is **inside the app bar**, not a separate permanent row.

| Condition | Presentation |
|---|---|
| One account, healthy and idle | Account display name only |
| Multiple accounts | Active account name; add server when needed to distinguish identities |
| Long identity | One visual line with ellipsis; full identity in semantics and account sheet |
| Routine background check | Small progress indication; no extra row |
| Explicit sync lasting over 800 ms | Temporary “Checking for updates” row |
| Pending uploads | Actionable waiting row |
| Offline with no pending work | Compact offline indicator; details in status sheet |
| Offline with pending work | “Offline · changes saved on device” row |
| Reauthentication, conflict, failed deletion, local-save failure | Persistent actionable banner |

Critical failures appear immediately. Transient healthy states do not repeatedly expand and collapse the header. Once pending work clears, remove its row after a short settled transition; do not replace it with a permanent success row.

Tapping the account subtitle opens sync details. The avatar opens the account switcher. Both have distinct accessible names.

Search replaces the title area. Filters use a wrapping row. Sorting and advanced filters live in a sheet. There is no permanent search field or bottom navigation bar.

### 4.4 Sync vocabulary

| State | Copy | Action |
|---|---|---|
| Local persistence | Saving on device… | Normally none |
| Local success, pending network work | Saved on device · 2 waiting | Queue |
| Upload | Uploading 2 changes | Details |
| Pull | Checking for updates | Details |
| Successful completed cycle | Up to date · checked 10:42 | Sync now |
| Offline | Offline · changes saved on device | Details |
| Authentication failure | Sign in again · local notes retained | Repair account |
| Conflict | 2 notes need your decision | Needs attention |
| Local write failure | Could not save on this device | Retry, Export draft, Copy text |

Keep “last checked” separate from “last modified.”

The status sheet separates uploads, downloads, decisions, and deletions. One failed note does not conceal other successful work. Account errors survive restart.

### 4.5 Search and saved views

Search title, body, and category locally within the selected account.

Support category subtree, favorites, unfinished tasks, attachments, sharing, and sync-state filters. Preserve query, filters, list position, and selected match when returning from a note.

Saved views are named local filter definitions labeled **On this device**. Unified server search is a separate explicit action when supported.

No-results screens preserve the query and offer Clear filters.

### 4.6 Empty and error states

| Situation | Required behavior |
|---|---|
| No account | Connect Nextcloud / Scan login QR code |
| Initial download | Truthful downloaded count; no invented percentage |
| Empty account | Create note |
| Empty category | Name category; Create here |
| Empty Favorites | Explain favoriting |
| Cached refresh | Keep rows visible |
| Account refresh failure | Keep cached rows and show recovery action |
| Unavailable note | Keep last copy, identify age, Retry / Save a copy |
| Database cannot open | Retry / available recovery export; never present false empty success |

Use skeletons only when no cached content exists. Disable shimmer with reduced motion.

## 5. Editor, preview, and checklist

### 5.1 Phone top bar and keyboard layout

At **411 dp**, the source editor has:

| Position | Control |
|---|---|
| Leading | Back, 48 dp |
| Middle | Compact note title, flexible width |
| Trailing 1 | Preview icon, 48 dp |
| Trailing 2 | Share icon, 48 dp |
| Trailing 3 | Overflow icon, 48 dp |

All three trailing actions remain visible in cs/de at 100% and 200% text. They are icons, not text buttons.

Accessible labels and tooltips:

| Action | English | Czech | German |
|---|---|---|---|
| Preview | Preview | Náhled | Vorschau |
| Share | Share | Sdílet | Teilen |
| Overflow | More options | Další možnosti | Weitere Optionen |

The compact title may truncate. Actions do not shrink. Read-only notes retain Preview, Share where available, and overflow; editing restrictions are explicit.

**Keyboard closed:**

- Show the document title as a typographic heading.
- Show the category breadcrumb below it.
- Both belong to the document header, not fixed outlined fields.
- Tapping title/category opens Details at the relevant control.

**Body keyboard open:**

- Collapse the entire document header: title and category.
- Collapse routine save status.
- Keep the top app bar and 48 dp formatting dock.
- Keep genuine local-save failures and decisions visible.
- Show the note title in the compact app-bar area.
- Restore the header when the keyboard closes without recreating the controller.

Editing metadata uses a dedicated Details surface with its own focused field. It becomes full screen when the keyboard or large text leaves insufficient room.

In S9 portrait, default text and the default Samsung keyboard must leave at least six source-body lines visible. Measure this on the device; do not infer it from the physical pixel resolution. Landscape keeps formatting access and a scrollable body.

### 5.2 Formatting dock

```text
[Undo] [Redo] | [Format] [Task] [Attach] [Insert]
```

Each target is 48 logical pixels. Icons fit at 411 dp; narrower windows may scroll horizontally.

- Format: headings, bold, italic, strike, quote, lists, code, indent/outdent.
- Task: insert or toggle a Markdown task marker.
- Attach: Photo, Camera, File, Voice.
- Insert: Link, Mention, Emoji, Smart picker, Template.

Commands preserve selection and focus and form one undo operation. List continuation supports nesting. Enter on an empty list item exits the list.

A hardware keyboard may keep a compact dock visible. Do not remove all formatting controls in landscape.

Overflow contains Details, Favorite, Find in note, Open checklist, Attachments, History/recovery, Export, and Delete.

Autosave is primary. A hardware Save command flushes local persistence. No permanent save button is required.

Keep title and body separate where required by the Notes model. Do not rewrite an opening heading to make them appear identical.

### 5.3 Typing suggestions

Package E implements all three triggers.

The popup uses the raised surface, a subtle boundary, and a selected row with an accent edge. Rows have at least 48 px targets. Show at most five options, scrolling the remainder.

Anchor near the caret without covering it. When less than two usable rows fit, use a compact sheet above the keyboard. Do not move the source caret to the sheet.

| Trigger | Appearance and behavior |
|---|---|
| `@` | Initial/avatar, display name, secondary username; current-server results only |
| `:` | Emoji glyph, localized name, optional aliases; available offline |
| `/` | Icon, command/provider name, short description; local commands first, supported server providers afterward |

Rules:

- Trigger only at a suitable boundary.
- Suppress inside code, URLs, email addresses, and active composition.
- Debounce server searches and discard responses for obsolete queries/accounts.
- Errors remain inside the suggestion surface; writing continues.
- Dismissal preserves the literal typed text.
- Arrow keys select, Enter accepts, Escape dismisses.
- Screen readers receive result count, selected item, and insertion action.
- Insertion is one undo operation.

Mentions use Text-compatible Markdown:

```markdown
@[Name](mention://user/id)
```

Use the current server’s autocomplete support. Inserting this text does not claim that a notification was sent.

Smart-picker results become ordinary Markdown links. Show advertised, usable providers; do not leave inert provider entries. Recheck destination access when necessary.

### 5.4 Explicit preview and Text-compatible rendering

Preview is entered only through an explicit control. Split source/preview is also explicit.

| Construct | Required appearance and interaction |
|---|---|
| Headings | Clear reading hierarchy; larger than source headings |
| Mention | Rounded inline chip with person symbol and name; wraps without clipping |
| Task | Full-size accessible checkbox and label |
| Callout such as `::: info` | Information container, icon, optional heading, readable body, visible leading boundary |
| Warning/error callout | Matching semantic container plus textual type |
| Table | Header emphasis, cell boundaries, horizontal scrolling inside the table |
| Details | Disclosure row with chevron, summary, expanded state, keyboard/screen-reader action |
| Link preview | Ordinary underlined link initially; bounded preview card only after permitted metadata retrieval |
| Attachment | Filename/type/status; cached preview where available |
| Unsupported syntax | Readable literal source; no silent deletion |

Callouts and details preserve their source representation on round-trip. Do not render arbitrary embedded HTML or scripts.

Link-preview metadata may use a supported authenticated Nextcloud resolver. Third-party fetching requires explicit permission. Rendering a note must not silently contact arbitrary link hosts.

Preview interaction:

- Ordinary taps select or interact with content; they do not unexpectedly enter editing.
- Top-bar Edit returns to the saved source selection.
- A block’s explicit **Edit this section** action enters source at its parser-backed range.
- Links, disclosure controls, and checkboxes retain their own actions.
- Repeated text maps to its own source occurrence.
- Table and details content remain accessible without depending solely on visual layout.

Preview toggles and task actions use source ranges tied to a document revision. Revalidate before mutation.

### 5.5 Checklist mode

Checklist mode opens only through **Open checklist** or an explicitly configured checklist widget. It never becomes the remembered default note mode.

Layout:

- Note title and completed count.
- Uncompleted items with full-row checkbox targets.
- Completed group below.
- Persistent quick-add action.
- Markdown action in the top bar.

Behavior:

- Preserve headings, nesting, continuation paragraphs, and unrelated prose.
- Toggle changes only the task marker.
- Relocate completed items after the current touch or accessibility action finishes.
- Drag reorders complete task blocks within a section.
- Provide Move up/down alternatives.
- Clear completed previews the count and supports undo.
- Mixed prose remains visible as context.
- Unsupported structures remain editable in source.
- Stale or ambiguous task identity opens the note rather than toggling a similar-looking item.

### 5.6 Templates and daily notes

Templates and daily-note configuration are local preferences. Creation produces ordinary Markdown.

Show the destination account/category before creation. Daily-note naming and duplicate handling are explicit. Applying a template to an existing note is an undoable edit.

## 6. Recovery and data safety

### 6.1 Comparison workspace

Use a full screen on phones and a workspace on tablets.

Required elements:

1. Reason a decision is needed.
2. Device and server versions with timestamps.
3. Labeled changed blocks.
4. Editable raw-Markdown Result.
5. Use result, Keep as separate note, and Leave unresolved.

On phones, use Device / Server / Result tabs. The currently reviewed block and navigation remain visible. On wide tablets, show three columns; collapse to sequential presentation when space or text size requires it.

“Use device” and “Use server” populate Result. They do not immediately destroy the other version.

Before applying:

- Persist both originals.
- Recheck the server version.
- Preserve edits already made in Result.
- If the server changed again, update the comparison and explain why another review is required.

Keep originals until the owner explicitly removes them from recovery.

### 6.2 Distinct recovery paths

| Condition | Required choices |
|---|---|
| Server note deleted | Save as new note, Export, Keep in recovery |
| Edit permission revoked | Retain typed text; create an owned copy or export |
| Attachment move blocked | Explain blocked operation; return to original category or perform a verified supported move |
| Uncertain create | Resolve operation identity before retrying creation |
| Local write failure | Retry, Export draft, Copy text |
| Failed deletion | Show reason, Retry when meaningful, Undo/restore as applicable |

Deletion creates a local recovery snapshot before network work.

Before server confirmation, Undo cancels pending deletion. After server deletion, recovery explicitly creates/restores a note. It must not imply that the original server operation never occurred.

Needs attention remains reachable after snackbars disappear.

### 6.3 Modal and feedback rules

- Banner: persistent actionable failure or decision.
- Snackbar: completed reversible action.
- Dialog: one short consequential decision.
- Sheet: account, filters, format, destination, or attachment source.
- Full screen: typing-heavy forms, comparison, and sheets that no longer fit.

Buttons wrap or stack. Persistent problems never depend on a timed snackbar.

## 7. Accounts, transfers, and settings

### 7.1 Login and QR

Flow:

1. Normalize and validate server address.
2. Check server.
3. Browser sign-in or QR validation.
4. Verify identity and Notes support.
5. Persist account.
6. Start download.

Show distinct failures for invalid address, unreachable server, certificate trust, maintenance, expired login, and missing Notes support. Preserve entered text.

Cancel invalidates the attempt, including late responses and a browser handoff that has not yet started.

QR behavior:

- Request camera access on entry.
- Provide manual server entry after denial.
- Keep scanning after an unsupported QR with an explanation.
- Confirm server and identity after a valid scan.
- Never display or log the secret.

Reauthentication identifies the affected account and fixes its server. A different identity cannot replace the account holding existing drafts.

### 7.2 Account switcher and removal

Phone: sheet. Tablet: anchored popover.

Each account shows display name, username, server, selected state, and actionable problems. Identical usernames on different servers remain distinguishable.

Switching account first persists the draft. Failed local persistence prevents switching.

Removal:

- Name the account.
- Explain local removal separately from server deletion.
- Export unsent content or retain it in protected local recovery.
- Attempt app-password revocation and report failure accurately.
- Remove account widget snapshots, queued routes, temporary media, and applicable local indexes.

### 7.3 Share with people and send a copy

The editor Share icon opens one surface containing:

- Share with people.
- People with access.
- Send a copy: text or Markdown file.

Use standard Nextcloud shares. Default permission is **Can view**; editing access is explicit.

Show pending, failed, and confirmed operations separately. A new local note must finish initial upload before creating a server share. Sending a text copy works offline.

Attachments require verified recipient access. Sharing the Markdown note alone does not imply access to adjacent files. Offer an explained text-only copy or an explicitly reviewed compatible folder share; never silently expose an entire category.

Standard shared editing uses conditional writes and explicit reconciliation. Show “Shared editing · checked 10:42.”

Do not display Live, online avatars, or cursors without a confirmed compatible Text session. A future live session must own network document mutations so REST/DAV writes cannot race it.

### 7.4 Incoming content

Persist a durable capture before acknowledging native receipt.

Then show:

- Content summary.
- Destination account and category.
- New note or Append.
- Target-note search for Append.
- Save on device.

With one account, prefill it visibly. With multiple accounts, require an explicit account choice. An external account identifier must be validated; it never silently falls back to the displayed account.

Closing the screen keeps a pending capture and creates no background note. After successful local conversion, acknowledge completion and retain pending uploads through the ordinary queue.

Capture identifiers make repeated delivery idempotent. Process termination between receipt and conversion must not lose or duplicate content.

### 7.5 Attachments and voice

Copy selected content into durable staging before reporting acceptance.

Show distinct states:

- Stored on device.
- Waiting to upload.
- Uploading.
- Available offline.
- Failed, with a meaningful retry.
- Unavailable.

Pending attachments remain associated with their originating draft across restart and initial note creation.

Insert the final compatible relative Markdown reference only after the server path is known. Attachment insertion is one undo operation. A pending attachment is shown in the attachment surface, not as a fake final link.

Voice capture provides elapsed time, Pause/Resume, Stop, Listen, Attach, and Discard. Request microphone access only when recording starts. Interrupted recordings remain recoverable.

Removing a Markdown reference and deleting a server file are separate actions.

Read server capabilities, Notes settings, and supported attachment routes. Do not assume every supported server exposes identical API paths.

### 7.6 Settings

Sections:

- Appearance: System / Light / Dark; language.
- Writing: text size, monospace source, templates, daily note.
- Privacy: app lock, widget policy, screenshot preference where supported.
- Sync and storage.
- Import and export.
- Accounts.
- About, licenses, diagnostics/privacy controls.

Device preferences and server settings are visibly distinct.

- Android intervals are best-effort.
- iOS background refresh timing is controlled by the system.
- Unsupported system languages fall back to English.
- Keep import reports skipped and failed items.
- Label the current ZIP **Export Markdown**, not Full backup.
- Explain attachment/recovery omissions where applicable.
- Failed preference persistence produces feedback; security switches revert if saving fails.

### 7.7 App lock

Use an opaque cover with no note titles or underlying semantics. Remove editor focus and cover app-switcher snapshots.

Authentication errors remain locked. Device-passcode fallback uses platform authentication. If authentication configuration changed, require a deliberate recovery path; uncertainty never unlocks.

Android screenshot blocking is configurable. Do not promise iOS screenshot prevention.

The widget-content policy is defined in section 9.

## 8. Adaptive layouts and interaction

### 8.1 Window rules

| Available width | Layout |
|---|---|
| Below 840 logical pixels | One primary pane |
| 840–1279 | List and editor when minimum pane widths fit; categories in drawer |
| 1280+ | Optional 300 px navigation (240 wrapped "All notes" in Czech), approximately 320 px list, remaining editor |

Two-pane layout needs approximately 288 px for the list and 440 px for the editor after insets. These are minimum working widths, not device classifications.

At larger text, collapse navigation first, then use one pane. Forms remain approximately 480–560 px wide.

Resizing does not recreate the active document.

### 8.2 Navigation, gestures, and undo

| Interaction | Behavior | Visible alternative |
|---|---|---|
| Row tap | Open source editor | Open |
| Trailing swipe | Reveal Favorite | Row menu |
| Leading swipe | Reveal Move/Delete; no destructive full-swipe | Row menu |
| Long press | Multi-select | Select notes |
| Pull to refresh | Request sync | Sync now |
| Checklist drag | Reorder task block | Move up/down |
| Preview section action | Open corresponding source block | Edit this section |

Multi-select offers Favorite, Move, Export, and Delete. Explain unavailable actions for mixed ownership.

Back closes the innermost suggestion, modal, search substate, keyboard, then screen according to platform behavior.

Before navigating away, selecting another note, switching account, or applying an external route, flush local persistence. External routes queue until startup, account resolution, and unlock complete.

Local editing actions share undo history. Remote changes do not blindly enter or reverse local undo operations.

### 8.3 Hardware keyboard

`Primary` means Command on iPad and Control on Android.

| Shortcut | Action |
|---|---|
| Primary+N | New note |
| Primary+Shift+N | New checklist |
| Primary+F | Find in focused note; search when list focused |
| Primary+Shift+F | Search collection |
| Primary+S | Flush local save |
| Primary+Z / Primary+Shift+Z | Undo / Redo |
| Control+Y on Android | Redo |
| Primary+B / I | Bold / italic |
| Primary+K | Insert link |
| Primary+Shift+P | Explicit preview toggle |
| Escape | Close innermost non-destructive layer |
| Arrows / Enter | Navigate suggestions or focused list |
| Tab / Shift+Tab | Focus navigation; contextual indent/outdent only where appropriate |

Preserve platform editing and accessibility shortcuts. Expose iPad shortcut descriptions.

### 8.4 Accessibility

- Rows announce title, relevant summary, state, and actions in a stable order.
- Decorative symbols do not duplicate announcements.
- Announce new conflicts and save failures once.
- Do not announce every autosave transition.
- Checklist controls expose label, checked state, and position.
- Comparison identifies Device, Server, and Result in words.
- Dismissed surfaces return focus to their invoker.
- Submitted forms focus the first error.
- No essential action is gesture-only.

## 9. Home-screen widgets

### 9.1 Shared model

Offer four widget types:

1. Notes list.
2. Single note.
3. Checklist.
4. Quick note.

Configuration belongs to the instance: account, collection/note, type, and appearance. Changing the app’s selected account does not retarget widgets.

Snapshots contain account/note identity, revision, capture time, privacy state, and safe display content.

Mutations include a unique command ID, expected source identity/revision, and requested result. Duplicate commands do not toggle twice. Stale or ambiguous commands open the app at the relevant note.

Rendering uses local data and never requires a network request.

### 9.2 Android technology decision

**Use RemoteViews XML and the existing `home_widget` bridge. Do not introduce Glance for this redesign.**

| Concern | Glance | RemoteViews XML |
|---|---|---|
| APK size | Adds Glance and Compose-related dependencies; release delta depends on shrinking and existing dependencies | No added Compose/Glance stack; new resources still add size |
| Build time | Adds Compose configuration/compiler work | Extends the existing Kotlin/XML build |
| Android 10 | Can support it with a compatible dependency baseline | Existing implementation already uses this model |
| Layout limits | Ultimately constrained by AppWidget/RemoteViews | Same underlying limits |
| Agent maintenance | Requires Glance-specific APIs alongside Flutter/Kotlin | Existing provider plus explicit XML size variants |
| Migration | Provider/state migration needs care | Existing provider identity can remain |

The dependency/build comparison is a design inference, not a measured timing or size result. Android documents that Glance uses Compose runtime and produces RemoteViews. [Jetpack Glance](https://developer.android.com/develop/ui/compose/glance)

RemoteViews supports responsive layout strategies, with newer size APIs guarded by OS version. Use size selection on Android 10 and supported responsive APIs on newer versions. [Flexible widget layouts](https://developer.android.com/develop/ui/views/appwidgets/layouts)

Implementation rules:

- Retain the installed provider component.
- Give each instance its own configuration.
- If an old widget has no reliable account identity, show Configure widget. Do not guess from the current account.
- Use native text and controls, not Flutter screenshots.
- Use a clickable task row and explicit checked-state rendering compatible with Android 10.
- Use unique, account-aware pending-intent identities.
- Callbacks enter the shared durable command path.
- Keep a checked row in place until the next settled refresh.

### 9.3 Android compositions

Grid cells vary by launcher. Measure available bounds; do not assume cell counts imply fixed dimensions.

| Type | 2×2 | 4×2 | 4×4 |
|---|---|---|---|
| Notes list | Header and 1–2 readable targets | Header and approximately 2–3 titles | Approximately 5–7 rows if space permits |
| Single note | Title and short excerpt | Wider excerpt | Longer limited-format snapshot |
| Checklist | Progress and 1–2 tasks if they fit | Approximately 2–3 tasks | Several full-size task rows |
| Quick note | One New note action | New note and Checklist | New note, Checklist, Daily note, Template |

At large text, show fewer items. Do not shrink targets or fonts to preserve counts.

Android 12+ defaults to a complete system dynamic-color palette; Android 10 uses the OwnNotes fallback palette. Test light/dark and contrasting wallpapers. Dynamic-color support does not require Glance. [Android widget enhancements](https://developer.android.com/develop/ui/views/appwidgets/enhance)

Expanded layouts show snapshot time. Refresh requests do not promise immediate network completion.

No embedded editor, keyboard, drag reorder, or rich document canvas.

### 9.4 iOS WidgetKit

Keep iOS 15 as the app baseline.

- Home-screen small, medium, and large families.
- Accessory families on iOS 16+.
- Interactive checklist actions on iOS 17+.
- Availability guards preserve older-OS behavior.
- Existing App Group exchanges snapshots; a signed widget extension is required.

| Family | Content |
|---|---|
| Small | One primary destination: recent note, short excerpt, checklist progress, or New note |
| Medium | Several note links/tasks or a small set of capture actions |
| Large | More rows/context without miniature text |
| Accessory circular | Open action or permitted checklist progress |
| Accessory rectangular | Short permitted title/count or capture action |
| Accessory inline | Short action label |

WidgetKit layouts do not scroll. Use native typography and support tinted/accented rendering.

Before iOS 17, checklist taps open the app. On supported versions, App Intents submit durable commands; displayed success follows local acceptance. [Apple interactive widget guidance](https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities)

Timeline refreshes are system-controlled. Do not promise a fixed refresh interval.

### 9.5 Privacy

**When app lock is enabled, widgets always hide note content, even while the app is temporarily unlocked.**

Show only the app identity, “Notes hidden by app lock,” and Unlock to open.

Protected snapshots contain no:

- Account/category names.
- Titles or excerpts.
- Task counts.
- Thumbnails or recording durations.

Disable background checklist mutation. Quick-note actions also pass through unlock before revealing destination details.

Enabling lock:

1. Persist the privacy policy.
2. Replace shared snapshots with redacted data.
3. Remove app-managed unredacted caches/timeline data.
4. Request widget updates.

Every publisher and command consumer checks the policy. A late background worker cannot republish content or execute an old task command.

Account removal purges its snapshots and configuration references. WidgetKit privacy annotations supplement redaction.

The OS may retain an earlier rendered image temporarily. Verify transitions on devices; do not promise instantaneous removal of OS-cached images.

## 10. Localization and overflow

English, Czech, and German ship together for each accepted wave. German is not postponed until all screen development ends.

The integration owner alone edits ARB files, generated localization files, and native localized resources.

Package handoffs provide keys, proposed cs/en/de text, plural rules, semantic labels, and context. The owner publishes updated localization files for branches to consume. Agents never merge competing generated localization output.

### 10.1 Exact German overflow strings

These are required test strings.

| English | German | Component rule |
|---|---|---|
| Saving on device… | **Speichern auf dem Gerät …** | Status text wraps; no fixed height |
| Save on device | **Auf dem Gerät speichern** | Incoming-content primary button wraps; may become full width |
| Saved on device | **Auf dem Gerät gespeichert** | Secondary status wraps |
| Needs your decision | **Benötigt deine Entscheidung** | Note-state line wraps; never ellipsized |
| Waiting to upload | **Warten auf das Hochladen** | Separate state line |
| Checking for updates | **Nach Aktualisierungen suchen** | Status row grows vertically |
| Compare versions | **Versionen vergleichen** | Screen title may wrap at large text |
| Keep as separate note | **Als separate Notiz behalten** | Full-width comparison action |
| Use server version | **Serverversion verwenden** | Stacked comparison action when necessary |
| Could not save on this device | **Speichern auf diesem Gerät nicht möglich** | Persistent banner wraps; actions below |
| Sign in again | **Erneut anmelden** | Account action wraps |
| Remove from this device | **Von diesem Gerät entfernen** | Destructive account action on its own row |
| Share with people | **Mit Personen teilen** | Sharing section/action wraps |
| Shared with me | **Mit mir geteilt** | Navigation label grows vertically |
| Available offline | **Offline verfügbar** | Attachment metadata wraps |
| Clear completed items | **Erledigte Einträge entfernen** | Checklist action wraps or fills width |
| Export Markdown | **Markdown exportieren** | Settings row wraps |
| Notes hidden by app lock | **Notizen durch App-Sperre ausgeblendet** | Widget placeholder uses fewer secondary elements |
| More options | **Weitere Optionen** | Icon tooltip/semantics; no visible phone-bar text |

“Speichern auf dem Gerät …” is the in-progress label. “Auf dem Gerät speichern” is the action. Do not interchange them.

General rules:

- Buttons have minimum height, never fixed text height.
- Dialog actions stack before labels truncate.
- Navigation and settings labels wrap.
- Only identifiers, ordinary note titles, and breadcrumbs may use ellipsis when a full-value route and semantic label exist.
- Recovery instructions and destructive action labels never abbreviate to fit.
- Plurals use localization rules, not string concatenation.

## 11. Delivery and ownership

### 11.1 Team model

The second designer is the **integration owner**.

Coding agents work in separate git worktrees. There are at most five coding agents running concurrently. The plan below needs at most three in its main waves.

There are ten packages total:

**I, F, A, R, N, E, T, C, WA, WI.**

I is the recurring integration responsibility, not another independently competing feature branch. Each agent owns its package’s files and tests. No package edits another owner’s files.

Before work begins, the owner records the actual base commit and accommodates concurrent changes. Proposed directories below become ownership boundaries; they are not instructions to replace existing working implementations unnecessarily.

### 11.2 Files only the integration owner touches

Paths are repository-relative. Globs identify the complete reserved file families.

| Shared concern | Exclusive owner files |
|---|---|
| App wiring | `apps/mobile/lib/main.dart`, `apps/mobile/lib/data/runtime.dart`, `apps/mobile/lib/data/background.dart` |
| Cross-package contracts | New `apps/mobile/lib/core/contracts/**` |
| Database/schema | `packages/notes_store/lib/src/database.dart`, `database.g.dart` |
| Shared protocol types/client | `packages/notes_protocol/lib/src/models.dart`, `client.dart` |
| Package exports | `packages/notes_store/lib/notes_store.dart`, `packages/notes_protocol/lib/notes_protocol.dart` |
| Dependencies | Every affected `pubspec.yaml` and `pubspec.lock` |
| Flutter localization | `apps/mobile/l10n.yaml`, all `apps/mobile/lib/l10n/**`, including generated files |
| Shared test harness | New `apps/mobile/test/support/app_harness.dart`; shared test/bootstrap configuration |
| Android build | `apps/mobile/android/settings.gradle.kts`, `build.gradle.kts`, `gradle.properties`, `gradle/wrapper/gradle-wrapper.properties`, `app/build.gradle.kts` |
| Android entry points | `apps/mobile/android/app/src/{main,debug,profile}/AndroidManifest.xml`, `MainActivity.kt` in the existing package |
| Android shared theme/text | Existing `res/values*/styles.xml`; `res/values*/strings.xml` and proposed `widget_strings.xml` |
| iOS entry points | `Runner/AppDelegate.swift`, `SceneDelegate.swift`, `Runner-Bridging-Header.h` |
| iOS build/targets | `Runner.xcodeproj/project.pbxproj`, shared schemes, affected workspace configuration, `Podfile`, `Podfile.lock`, affected `.xcconfig` files |
| iOS permissions/signing | All affected `Info.plist` and `.entitlements` files |
| Native localization | All affected iOS `.lproj` resources, including widget and share-extension text |
| Published identity/store | `tool/make_icons.py`, launcher icon assets, `Runner/Assets.xcassets/AppIcon.appiconset/**`, `apps/mobile/assets/brand/**`, `docs/store/**` |

Feature agents request precise changes to these files. They do not commit temporary competing edits to them.

Integration preparation happens inside wave 1. It is not an additional wave.

### 11.3 Package ownership

| Package | Owned implementation |
|---|---|
| **I — Integration and acceptance** | Reserved files above; route registration, migrations, localization, dependencies, native registration, merged-build acceptance and store assets |
| **F — Foundations and document model** | New `lib/design/**`, `lib/core/markdown/**`, font assets/notices, existing `data/notes_widget.dart`, new `data/widgets/**`; parser ranges, summaries, snapshot/command adapters |
| **A — Accounts, settings, privacy** | Existing login/accounts/QR/server-address/settings/lock feature files; `data/account_api.dart`, `data/settings.dart`; store `accounts.dart`; protocol `login.dart`; new related feature modules |
| **R — Durable work and recovery** | Store `sync.dart`, `recovery.dart`, new queue/status/recovery modules; existing feature `recovery.dart` and new comparison UI |
| **N — Notebook shell** | Existing `home.dart`, `category_panel.dart`, `note_tile.dart`, `note_rows.dart`; new collection/search/saved-view modules |
| **E — Writing** | Existing `editor.dart`; new editor/checklist modules; suggestions, Text-compatible preview, templates/daily notes, mention/reference-provider adapters |
| **T — Transfers** | New attachment/capture/voice modules; existing export/Keep-import modules where needed; Android `share/**`; iOS `ShareInbox.swift` and `ShareExtension/ShareViewController.swift`; protocol attachment modules |
| **C — Sharing** | Existing protocol `sharing.dart`; new sharing UI/adapters; shared-note permissions and conditional-edit integration |
| **WA — Android widgets** | Existing `NotesWidget.kt`, native `widget/**`, widget layouts/provider metadata/background and dedicated color resources; excludes I-owned files |
| **WI — iOS widgets** | New `ios/OwnNotesWidgets/**` Swift implementation and widget-specific tests/assets; excludes I-owned target, signing, plist, entitlement, and localization files |

Each package owns its feature-specific tests. Existing large files are extracted by responsibility rather than enlarged beyond the project limit.

### 11.4 Waves

| Wave | Packages | Required result |
|---|---|---|
| **1 — Foundations and safety** | I, F, A, R | Theme/model boundaries, accounts/settings/lock, durable status and recovery work with existing routes |
| **2 — Writing and transfers** | I, N, E, T | Complete redesigned notebook, source editor, suggestions, preview, checklist, capture and attachments |
| **3 — Sharing and app acceptance** | I, C | Sharing, shared-note recovery, finalized cs/en/de text, device acceptance, refreshed app screenshots |
| **Widget wave** | I, WA, WI | Configurable native widgets, migration, privacy and device acceptance |

Dependencies are explicit:

- I publishes only the contracts needed by consumers before dependent implementation starts.
- F provides source identities/ranges and component APIs early in wave 1.
- A and R can use existing components until F is merged.
- N, E, and T agree insertion/navigation boundaries before wave 2.
- T does not edit E’s editor; it returns durable transfer state and insertion results.
- C uses R’s recovery path rather than creating a second sync/recovery system.
- WA and WI consume the same accepted snapshot/privacy/command model.

Each merge leaves login, listing, source editing, local save, and recovery usable. Remove superseded code only with the accepted replacement.

### 11.5 Acceptance method

Every package requires:

1. Relevant widget tests.
2. Supporting unit/store/native tests where widget tests cannot prove the behavior.
3. A short physical-device script.
4. Evidence tied to the merged commit/build.

**Common device setup:** Galaxy S9 Android 10, Galaxy S21 Android 15, and an iPhone installed through TestFlight. Record iPhone model/iOS version. Run each applicable package script on all three.

For each script:

- Run the main path in light and dark.
- Use the specified German/Czech content.
- Repeat the critical layout at 200% text.
- Record recovery behavior after the specified interruption.

Flutter widget tests do not establish launcher, extension, permission, browser-return, or App Intent behavior. Native tests and physical-device checks remain required for those surfaces.

### 11.6 Concrete package acceptance

| Package | Automated acceptance | Short physical-device script |
|---|---|---|
| **I** | App harness opens login/list/editor/recovery in cs/en/de × light/dark × 100/200%; localization keys resolve; save guard remains active after wiring | Launch merged build, switch language/theme, open/edit/back, restart, confirm persisted text. Capture assigned screens and record exact build |
| **F** | Tokens render required states without overflow; source ranges distinguish repeated text/tasks and code; snapshot serialization/redaction tests pass; font asset stays within budget | Open a mixed Czech/German note with headings, emoji and code; inspect both font modes/themes at 200%; scroll a populated list and confirm no missing glyphs |
| **A** | Login errors/cancel, wrong-identity reauthentication, account switching with failed save, settings persistence failure, and opaque lock are covered | Sign in; cancel a second login; repair the same account; switch accounts with an unsent draft; enable lock, background/reopen, authenticate; inspect removal warning |
| **R** | Conflict UI edits Result; stale server revision blocks overwrite; local-save failure blocks leaving; failed deletion stays visible; store tests cover crash/retry and retained originals | Edit offline, restart, confirm text; create a conflict with a second client; edit Result; leave unresolved/reopen; resolve; review failed/queued deletion and restore path |
| **N** | Category selection/expansion are separate; empty destinations remain; search state restores; healthy status row collapses; state labels wrap; bulk-action permissions are correct | Navigate categories/Favorites/Uncategorized; search and return from a note; queue an offline change; reconnect and observe status collapse; use one bulk action and Undo |
| **E** | Heading scales preserve editing value; composition/undo survive styling and resize; @/:/ insertion and dismissal work; preview renders all specified constructs; repeated blocks map correctly; checklist actions preserve surrounding prose | With keyboard open, type `#`, `##`, Czech/German composition and emoji; use suggestions; undo insertion; preview callout/table/details/mentions; toggle a duplicate-label task; return to source and verify exact content |
| **T** | Capture cancellation retains pending input; acknowledgment follows durable receipt; repeated delivery is idempotent; staged files survive restart; upload insertion is one undo; error/retry and import summary UI are covered | Share text into app, dismiss/reopen capture, choose destination; attach photo/file offline; restart and upload; record/pause/attach voice; deny then grant permission; send a Markdown copy |
| **C** | View/edit permission states, upload-before-share, failed share changes, recipient asset-access warning and permission-loss recovery are covered | Share with a second account as viewer, then editor; inspect recipient note/assets; edit from both clients; revoke permission during a draft; confirm recoverable owned copy |
| **WA** | Flutter configuration tests cover per-instance account/type and privacy; command tests cover duplicate/stale requests; native tests inflate layouts and exercise provider/config migration | On S9/S21 add two differently configured widgets, resize, toggle a task, repeat a stale action, restart app, enable lock, remove one account. On iPhone run shared widget-configuration/privacy regression only; Android launcher acceptance is Android-only |
| **WI** | Flutter configuration/privacy tests pass; Swift tests cover timeline redaction, family content, stale/duplicate command acceptance and availability branches | On TestFlight iPhone add small/medium/large widgets, change configuration, exercise supported checklist interaction, lock app and remove account; verify accessory/tinted rendering where supported. On S9/S21 run shared configuration/privacy regression only |

Native widget-package completion cannot be claimed from the cross-platform regression alone.

### 11.7 Performance and compatibility evidence

Measure the existing TODO target: **cold process start to an editable cursor in a new note under 1 second on the S9**.

Use a release/profile build with an already configured account and local database. Do not wait for network sync. Record five cold-process runs, median, worst result, build identity, and dataset. A debug or desktop result does not satisfy the target.

Also verify:

- Long-note typing and populated-list scrolling on S9.
- Round-trip tasks, mentions, categories, callouts, details, tables, and attachments through supported Notes/Text servers.
- Revoked permissions, server deletion, reconnects, and overlapping edits.
- Tablet resizing and hardware keyboard with retained editor identity.

Unavailable physical hardware remains an explicit acceptance gap.

## 12. Screenshot review checklist

Create one checklist per target device/build. Every row requires a light and dark screenshot using the same content.

Default review locale is German; use Czech text in document content and include English localization sanity checks in widget tests. Capture the additional 200% cases listed below.

Use generic accounts and content. Store screenshots contain no private server/account data.

| Screen/surface | Light | Dark | Required state |
|---|---|---|---|
| Welcome/server entry | ☐ | ☐ | Long server address; inline error; 200% |
| Browser handoff | ☐ | ☐ | Waiting and cancelled states |
| QR login | ☐ | ☐ | Permission denied and confirmation |
| Note list | ☐ | ☐ | Healthy collapsed header; mixed rows |
| List attention state | ☐ | ☐ | Offline queue, decision, unavailable note; 200% |
| Categories/drawer | ☐ | ☐ | Three levels, long name, empty destinations; 200% |
| Search/saved view | ☐ | ☐ | Wrapping filters and no-results state |
| Account switcher | ☐ | ☐ | Same username on two servers; long identity |
| Source editor, keyboard closed | ☐ | ☐ | H1/H2/H3, title, breadcrumb |
| Source editor, keyboard open | ☐ | ☐ | Collapsed metadata; all three top actions; S9 visible-line check |
| Suggestion popup | ☐ | ☐ | Mention, emoji and smart-picker results; short-height placement |
| Preview | ☐ | ☐ | Mention chip, callout, wide table, open/closed details |
| Checklist | ☐ | ☐ | Nested items, completed group, long clear action; 200% |
| Conflict workspace | ☐ | ☐ | Device/Server/Result, long German actions; 200% |
| Needs attention/deletion recovery | ☐ | ☐ | Failure reason and reachable recovery actions |
| Sharing | ☐ | ☐ | Viewer/editor, pending change, attachment warning |
| Incoming capture | ☐ | ☐ | Account choice, Append, primary action; keyboard and 200% |
| Attachments | ☐ | ☐ | Pending, available and failed items |
| Voice capture | ☐ | ☐ | Recording, paused and recoverable interruption |
| Settings | ☐ | ☐ | Writing, privacy, export; 200% |
| Accounts/details | ☐ | ☐ | Reauthentication and unsent-data removal warning |
| App lock | ☐ | ☐ | Opaque cover and authentication failure |
| Tablet shell | ☐ | ☐ | Two/three panes and collapsed large-text layout |
| Widget configuration | ☐ | ☐ | Long account/category/note labels |
| Widgets | ☐ | ☐ | Each type/size, stale state and redacted state |

Android widgets additionally need dynamic-color examples from contrasting wallpapers. iOS widgets need supported tinted/accented appearances and accessory families.

A screenshot passes when labels, focus/selection, controls, state meanings, and reading order remain clear. Cropping an overflowing component out of the screenshot is not acceptance.

## 13. App icon and store assets

### 13.1 Required work for this redesign

Keep the published icon and feature-graphic artwork.

In wave 3, I regenerates store screenshots from the accepted interface and updates cs/en/de captions/listing text where behavior changed. Widget screenshots follow the widget wave.

Review:

- Existing `docs/store/screenshots/phone-*.png`.
- Play screenshots and localized descriptions.
- App Store screenshots for the device classes actually supported/listed.
- Onboarding/About artwork consistency.
- Store privacy and feature claims affected by the implemented release.

Do not imply a widget or collaboration feature is available before its acceptance.

### 13.2 Checklist if a later explicit decision changes the icon

An icon change is a separate coordinated identity update, not a partial asset replacement.

I must update:

1. `tool/make_icons.py` master artwork and outputs.
2. Android legacy launcher mipmaps.
3. Android adaptive foreground/background artwork and XML.
4. Android monochrome artwork and references.
5. iOS AppIcon catalog, including opaque 1024 px artwork without a pre-rendered corner mask.
6. Play 512 px icon.
7. Play 1024 × 500 feature graphic.
8. Play and App Store screenshots containing the icon.
9. In-app brand artwork and applicable store/listing previews.

The inspected generator currently creates raster launcher/iOS/store artwork and the feature graphic. It does **not** already generate adaptive or monochrome Android assets; those outputs would need implementation.

Check launcher masking, monochrome rendering, small-size legibility, iOS opacity, and consistency across all exported assets.

## Integration owner decisions (final)

These override the matching parts above.

1. **Tap in preview edits.** The owner asked to edit straight from the
   preview, and it is implemented and verified on the Galaxy S9: a short tap
   on ordinary preview text opens the source editor at the parser-backed
   range of that block; long press and drag select and scroll; links,
   checkboxes and disclosure controls keep their own actions. The explicit
   "Edit this section" action stays as the accessible alternative. Notes
   still never open in preview on their own.
2. **Strings.** Feature packages may append new keys to `app_en.arb` and
   `app_cs.arb` (CRLF line endings, appended at the end) and list them in
   their report; the integration owner resolves merges, regenerates the
   localization output and adds German in one pass.
3. **Icons in lists and menus.** Every row in settings, accounts, menus and
   sheets has a leading 24 px outlined icon from the one icon family,
   aligned in one column, switches included; section headers have none.
   A list never mixes rows with and without icons.
4. **Schema.** In wave 1 only package R may change
   `packages/notes_store/lib/src/database.dart`, additively, with a
   migration and a migration test.

## Changes from v1

- Reduced delivery to three app waves plus widgets, with ten packages and explicit integration-owner files.
- Added visible live heading sizes, stable editing requirements, and keyboard-space rules.
- Chose system proportional fonts with one subset mono asset.
- Retained the published icon; added complete screenshot and conditional icon-update work.
- Collapsed healthy status chrome and fixed the 411 dp editor actions.
- Retained RemoteViews instead of introducing Glance.
- Assigned suggestions and Text-compatible preview to package E.
- Added package acceptance scripts, screenshot checklists, and exact German overflow strings.
- Replaced ordinary preview-tap editing with an explicit section action.
- Separated redesign completion from future full backup and live co-editing milestones.