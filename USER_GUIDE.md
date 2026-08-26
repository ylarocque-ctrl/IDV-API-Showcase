# IDV API Showcase — User Guide

This guide is for Quadient teams who will run the **File Manager API Demo** in front of a
prospect or customer. It covers starting the app, reading the screen, and personalizing it
— environment, API key, folders, templates, and presets — for a specific demo.

For deeper technical detail (payload shapes, adding new endpoint tabs, CORS internals), see
`README.md` in the same folder. This guide only covers what you need to run and tailor a demo.

## 1. What you're running

A single web page (`index.html`) that builds real API requests to Quadient's File Manager
REST API from on-screen forms — no typed JSON, no Postman. One tab per endpoint (upload,
metadata, listing, fields, download, search). Every tab shows the exact request live and can
either send it directly or copy it as a ready-to-run curl command.

Everything demo-specific — branding, environment URLs, the API key, folders, metadata
templates, and one-click presets — lives in a companion file, `config.json`, in the same
folder. You don't need to touch `index.html` to tailor a demo.

## 2. Starting the app

Do **not** double-click `index.html`. Opening it directly from disk (a `file://` address)
blocks the browser from reading `config.json`, so the app silently falls back to generic
built-in defaults — none of your customization will show up.

1. Open a terminal in the app's folder.
   - Windows: click the address bar in File Explorer, type `cmd`, press Enter.
2. Start a local web server:
   ```
   python -m http.server 8000
   ```
   No Python? Try `py -m http.server 8000`, VS Code's "Live Server" extension, or `npx serve`
   with Node.js installed.
3. Open `http://localhost:8000` in a browser.
4. Check the badge in the top-right of the header:
   - **"config.json loaded"** — your customization is active. You're good to demo.
   - **"built-in defaults (config.json not found)"** — the app didn't pick up your file. See
     Troubleshooting (Section 6).

For anything beyond a one-off local run, host the folder on any internal static site (Azure
Static Web Apps, an Azure Storage static website, IIS, nginx). The API key in `config.json`
is plain text, so keep this behind internal access only — never publish it to the open web.

## 3. Reading the screen

**Header (always visible):**

| Element | What it does |
|---|---|
| Title / subtitle | From `config.json` → `appTitle` / `appSubtitle` |
| Environment dropdown | Switches the base URL the app sends requests to |
| **Tabs** picker | Show or hide endpoint tabs on the fly, without editing any file |
| Config badge | Confirms `config.json` loaded — check this before every demo |

**Tab row:** one button per endpoint. The visible set and their order come from
`config.json` → `tabs`; anything hidden there can still be turned back on from the header's
Tabs picker during the demo.

**Each tab is a two-column layout:**

- **Left — request builder:** cards for Authorization (API key), the endpoint's own inputs
  (file, folder, TMPLID, FID, search filters, etc.), and — on File Upload — a Preset picker
  and the Metadata builder.
- **Right — request console:** tabs to view the request as `jreq JSON`, `curl (bash)`, or
  `curl (Windows)`, a **copy** button, the exact method + URL that will be called, and
  **Send request**. Below it, the **Response** panel shows what came back, with its own copy
  button.

Because the console updates live as you fill in the builder, you can narrate the request
taking shape in real time during a demo — that's the whole point of the app.

## 4. Walking through File Upload (the main tab)

1. **Authorization** — the API key is pre-filled from `config.json`. Click "show" to reveal
   it, or paste a different key for this session only (this never touches the file).
2. **File** — drag a file onto the box, or click "browse". This becomes the multipart `file`
   part. Send stays disabled until a file is chosen.
3. **Destination** — the API accepts either a folder **ID** or a folder **path**, so this card
   starts with a small picker for which one to send.
   - **Folder ID** (the default) — pick a folder from the dropdown (from `config.json` →
     `folders`), or choose "Custom folder ID…" to type any numeric ID. This sets
     `currentFldrID`. It starts on **EvolveStandardDemo (3)**; change the starting folder in
     `config.json` → `uploadEndpoint.defaults.currentFldrID`.
   - **Folder path** — type something like `/PresalesDemoRepository/NORAM/` and the request
     carries `folderPath` instead. The two are mutually exclusive: the spec says `folderPath` is
     only used when `currentFldrID` is absent, so the app sends one or the other, never both.
     Watch the `jreq JSON` panel swap keys as you toggle — it's a tidy way to show a customer
     that they can integrate by path without knowing internal folder IDs.

     The path is checked before you can Send. It has to start and end with a forward slash, and
     it has to sit under one of the repositories this environment actually has — currently
     **`/PresalesDemoRepository/`** or **`/TestAC/`**, both listed in a hint under the field so
     you don't have to remember. Anything else is blocked with a message naming the paths that
     do work, which is far better than watching the server reject it mid-demo. If you forget a
     slash at either end it's added for you when you click away; the repository name is never
     guessed at, so a wrong root stays flagged until you fix it. Adding a repository is a
     `config.json` edit (`uploadEndpoint.folderPathRoots`), not a code change.
4. **Preset** *(optional, but the fastest way to demo)* — pick a saved preset to fill the
   entire Metadata section in one click. Its description appears underneath. Presets **leave
   your folder alone**: whatever destination you picked in step 3 stays put, so you can set the
   folder once and then flip through presets without it jumping around mid-demo.
5. **Metadata** *(optional)* — pick a template (`TMPLID`) and fill in its Fields and Groups
   by hand instead of using a preset. Field types render appropriately (text, number, date
   picker, single/multi-select dropdown), and fields marked mandatory in `config.json` are
   enforced before Send is enabled.
6. Confirm the live `jreq JSON` in the console matches what you expect, then click **Send
   request** (needs the API to allow the app's origin via CORS — see Section 6) or switch to
   a **curl** tab and copy the command as a fallback that always works.

The other tabs (Add/Modify Metadata, File Listing, Get Fields, File Download, Search Basic,
Search Advanced, Has Content) follow the same pattern — fill the left-hand cards, watch the
right-hand console, Send or copy curl.

One thing to know on **Search (Advanced) → Metadata**: the API requires both a template and at
least one field value, so Send stays disabled and reads "Enter at least one field value to
send" until you fill one in. That's the app holding you back from a request the API would
reject, not a fault — pick your template, type a value into any of its fields, and Send unlocks.

**Has Content** is the quickest thing you can show, and a good opener. It takes no parameters
at all: press **Send request** and the panel answers with a green "This user has content" or an
amber "This user has no content", with the raw `{ "hasContent": true }` underneath. The whole
request is the API key, so a nice beat is to paste a different customer's key into the
Authorization box and send again — same URL, different answer. That makes the point that the
API scopes everything to the authenticated user without needing a single parameter. If it ever
says "Couldn't read an answer", the call succeeded but the body wasn't the expected boolean —
show the raw payload underneath and move on.

**File Download is worth a moment of rehearsal**, because it's the one tab with two different
response modes and the one whose response isn't an API envelope.

Enter a File ID, then choose a **Response mode**:

**Stream the file** (the default) asks the API for the file itself. The response body *is* the
document, so the Response panel previews it — PDFs in the browser's own viewer, images inline,
JSON, CSV, XML and plain text as formatted text — with **Save** and **Open in new tab** beside it.
Save works for every file type, including ones with no preview, and the file keeps its real name
and extension. Above the preview a readout shows what you asked for, what came back, the content
type, the server-suggested filename and the size — a clean way to show a customer that the API is
handing back the document itself.

**URL to blob storage** sends `url=true` and asks for a link instead. You get back a small JSON
envelope with a `sasUrl` — a short-lived, pre-signed address that points straight at storage,
bypassing the API — plus the file's name, size and creation date. Use **Download** to follow it or
**Copy sasUrl** to paste it elsewhere. This is the mode to show when a customer asks about
resumable or parallel downloads, or about handing a link to another system. The link expires, so
if a demo runs long, just send again for a fresh one.

**SocketID** is optional. Fill it in and the value is added to the request and to both curl
commands, so you can show exactly how a client subscribes to live download progress on the
`single_file_download` channel. The app doesn't open the socket itself — that would mean bundling
a WebSocket library, and this app deliberately has no dependencies — so there's no progress bar
here; the parameter is there to demonstrate the API, not to drive the UI.

The **Download** buttons on each row in File Listing and Search always use stream mode and save
the file straight to disk, no preview.

Two things that can surprise you live: if a PDF preview area is blank but Save still works, this
browser profile has its built-in PDF viewer switched off — use **Open in new tab**. And if a saved
file is called `file-1574` rather than its real name, the API isn't exposing the
`Content-Disposition` header to the browser; the readout will say so, and it's a server setting,
not something to fix in the app.

One quirk worth knowing if a customer reads the API docs alongside you: the docs say *any*
non-empty `url` value switches to link mode, but the live server treats `url=false` as stream
mode. The app sidesteps the disagreement by sending no `url` parameter at all for stream mode, so
its URL will be slightly shorter than the one Swagger shows. Both are correct.

### If a Send shows "Network error"

This means the browser refused to hand the page a response. It does **not** by itself tell you
whether anything happened on the server, and the browser gives the app no way to find out —
a request that was rejected before it left and a request the server carried out but whose
response got dropped look exactly the same from inside the page.

On the read-only tabs that's a nuisance and nothing more. On the two tabs that write — File
Upload and Add/Modify Metadata — it matters, because pressing Send again could apply the same
change twice. Those tabs say so explicitly rather than telling you the request never arrived.

Add/Modify Metadata goes one step further. Under a blocked response you'll find a **Was it
applied?** box: press **Check now** and it re-reads the file through the File Listing endpoint —
an ordinary GET, so it still works — and tells you whether the record's timestamps moved. Green
means the change almost certainly landed and you should *not* retry; red means it probably
didn't and retrying is safe; amber means it couldn't tell, usually because the file isn't in the
folder shown in the dropdown, or because reads from this origin are blocked too. In that last
case use **Copy read-back curl** and run it from a terminal — curl ignores CORS entirely.

The folder dropdown is pre-filled with whatever folder the File Upload tab is currently set to,
so in the usual demo flow it's genuinely one click. One honest caveat printed under every
result: if the API returns timestamps without a timezone, they're read as your machine's local
time, so a result that's only a few minutes either side of your Send should be treated as
inconclusive.

If you see this during a live call, the calm move is to press **Check now**, read the verdict
aloud, and note that the API needs its CORS headers on the response — it's a server
configuration point, not a fault in the demo app, and the curl fallback proves the call itself
works.

## 5. Personalizing for a specific prospect or customer

Everything below is a `config.json` edit. Open it in any text editor, save, then **refresh
the browser tab** — no restart needed. The file must stay strictly valid JSON (no comments,
no trailing commas); a syntax error is the most common reason the badge falls back to
built-in defaults.

| Goal | Edit in `config.json` |
|---|---|
| Rebrand the header for this customer | `appTitle`, `appSubtitle` |
| Point at the right instance (sandbox, this customer's tenant, etc.) | `environments` — add an entry with `name` and `baseUrl`; it appears in the header dropdown |
| Use this customer's demo API key | `apiKey` — or just paste it into the API key field in the UI for a one-off session |
| Show only the endpoints relevant to this pitch | `tabs` — set `visible: false` on ones you don't want on-screen by default (still reachable via the header's Tabs picker if needed) |
| Offer this customer's real folders | `folders` — list of `{ "id": ..., "label": "..." }` |
| Demo their actual metadata schema | `templates` — one entry per `TMPLID`, with `availableFields` / `availableGroups` naming each field, its `Type` (1 Text, 2 Numerical, 3 Date, 4 Dropdown), and optional `Mandatory` / `Options` / `Multiple` |
| Build a one-click "wow" moment | `presets` — a saved `name`, `description` and full `metadata` block that fills the Upload form's metadata instantly. The `currentFldrID` on a preset is no longer used: the folder stays where you put it |
| Change which folder the app opens on | `uploadEndpoint` → `defaults.currentFldrID` — must match an `id` in `folders` |
| Allow a new repository in Folder path mode | `uploadEndpoint` → `folderPathRoots` — add the root, e.g. `"/NewRepo/"`. Set it to `[]` to drop the check entirely |

**A good pre-demo routine:**

1. Duplicate `config.json` (e.g. `config.json.bak`) before editing, so you can revert fast.
2. Update `environments` / `apiKey` for the customer's instance.
3. Trim `folders` and `templates` down to what's relevant to their use case — a shorter list
   demos cleaner than the full internal test set.
4. Build one or two `presets` that tell the customer's story (their document type, their
   field names) so you can go from "watch this" to a completed upload in one click.
5. Reload the page and confirm the config badge still reads "config.json loaded", then
   click through every tab you plan to show.

### Adding a new template from a live system

If the customer's fields already exist in the backend, call **Get Fields** for that
`TMPLID` in the app itself — the response lists each field's real name and `FLDID` — then
copy those into a new `templates` entry in `config.json` instead of guessing at names.

## 6. Troubleshooting

**Badge says "built-in defaults (config.json not found)"**
`config.json` has invalid JSON, is missing, or you opened `index.html` directly from disk
instead of through a local server. Re-check Section 2.

**"Send request" fails with a network error, but the same request works in curl**
Almost always CORS — the API isn't allowing the app's origin. Host the app on the same
domain as the API, ask the API team to allow your demo origin, or just use the curl tab as
your live fallback (this always works regardless of CORS).

**A field/preset I added doesn't show up**
Refresh the page after saving `config.json`. If it still doesn't appear, validate the JSON
(a missing comma or bracket anywhere in the file breaks the whole config, not just your
addition).

## 7. Security reminder

`config.json` contains the API key in plain text to anyone who can load the page. Only host
this app internally or behind authentication. Never publish it to the open web, and never
paste a real production key into a shared example or screenshot.
