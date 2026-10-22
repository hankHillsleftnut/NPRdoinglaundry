import json, subprocess, statistics, datetime as dt
R = "hankHillsleftnut/NPRdoinglaundry"
def gh(*a): return json.loads(subprocess.check_output(["gh", *a]))
now = dt.datetime.now(dt.timezone.utc)
P = lambda s: dt.datetime.fromisoformat(s.replace("Z", "+00:00"))
merged = gh("pr", "list", "-R", R, "--state", "merged", "--limit", "40", "--json", "number,createdAt,mergedAt,commits,headRefName")
week = [p for p in merged if now - P(p["mergedAt"]) < dt.timedelta(days=7)]
local_midnight = dt.datetime.now().astimezone().replace(hour=0, minute=0, second=0, microsecond=0)
today = [p for p in week if P(p["mergedAt"]) >= local_midnight]
hours = [(P(p["mergedAt"]) - P(p["createdAt"])).total_seconds() / 3600 for p in week]
rounds = [max(0, len(p["commits"]) - 1) for p in week if not p["headRefName"].startswith("rebased/")]
open_ = gh("pr", "list", "-R", R, "--state", "open", "--limit", "100", "--json", "number")
runs = gh("run", "list", "-R", R, "--limit", "60", "--json", "databaseId,createdAt")
waits = []
for r in runs[:25]:
    for j in gh("run", "view", str(r["databaseId"]), "-R", R, "--json", "jobs")["jobs"]:
        if j.get("startedAt") and j.get("conclusion") != "skipped":
            w = (P(j["startedAt"]) - P(r["createdAt"])).total_seconds() / 60
            if w >= 0: waits.append(w)
out = {"mergedToday": len(today), "mergedWeek": len(week), "open": len(open_),
       "medianHours": round(statistics.median(hours), 1) if hours else None,
       "ciWaitMin": round(statistics.median(waits), 1) if waits else None,
       "fixRounds": round(statistics.mean(rounds), 1) if rounds else None,
       "at": now.isoformat()}
print(json.dumps(out))
