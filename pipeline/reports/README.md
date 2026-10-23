# pipeline/reports

One file per cluster of error reports, written by `node pipeline/tools/reports.mjs`. An agent reads these files to decide what to fix; a person's words are never in them.

## Run it

```
RETRO_API_BASE=<api address> ADMIN_SECRET=<secret> node pipeline/tools/reports.mjs --since 2026-10-22T00:00:00Z
node pipeline/tools/reports.mjs --fixture pipeline/tools/fixtures/diagnostics.request.json   # offline, no secrets
```

**Where the files go.** Cluster files describe a person's activity, so by default they are written OUTSIDE this repo, to `$RETRO_REPORTS_DIR` or else `~/Projects/retrospect-handover/pipeline/reports` (override with `--out <dir>`). `.gitignore` also ignores everything in `pipeline/reports/` except this README, as a second guard. Never commit or paste a cluster file.

**Retention.** On each live run, a report the viewer no longer lists (purged at expiry, or deleted with the account) is removed from the cluster files, and a file left empty is deleted. If a run sees the full 500-report page, the script says so and removes nothing. A report that disappears between the list and its download is skipped and counted, not fatal.

The address and secret come from the environment only; they are never printed or written. The script is read only: it makes `GET /admin/diagnostics` and `GET /admin/diagnostics/<reference>/download`, nothing else, and never deletes or changes a report. The list is one page (up to 500 reports); use `--since` to keep a run small.

## The cluster key

`<last failure code | crash | none>/<that failure's screen | the screen the report came from | none>/<appVersion>(<build>)`

Example: `server/journal/1.0(42)`. A crash counts when it is newer than the last failure. Reports with the same key land in the same file (`/` becomes `--` in the file name). Re-running merges by reference, so counts update and a reference is never listed twice.

## What a file holds

Count, first and last seen, builds, references, summed outbox counts, a reproduction hint (for example `journal -> offline -> POST /v2/entries 0 -> report.send`), and the last 50 breadcrumbs of the newest report as ids (kind, screen, control, route, status, code). A hidden block at the end holds the same ids so a re-run can merge; do not edit it.

## Privacy rule

The note is never written: files say only `has note: yes/no`. Every other value copied out of a report must match a strict id pattern, or it is written as `?`. Do not copy personal content into scope files, logs or PRs.
