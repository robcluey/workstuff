# /update-clueyplus

Refresh `clueyplus-dashboard.html` with the latest Meta Ads and CRM data, then commit and push to GitHub.

**Days:** `$ARGUMENTS` overrides the window (default: 60). End date = today. If Meta returns fewer days than requested, use whatever is available.

---

## Step 1 — Compute date range

- `end_date` = today (`YYYY-MM-DD`)
- `start_date` = today minus `$ARGUMENTS` days (60 if no argument given)

---

## Step 2 — Resolve the Cluey Learning AU ad account ID

Call `get_ad_accounts`. Identify the Cluey Learning AU account. Note its `account_id` (format: `act_XXXXXXXXXX`).

---

## Step 3 — Pull Meta Ads data (4 calls)

Use `get_insights` for each call below. Set `time_range: {since: start_date, until: end_date}` and `time_increment: 1` (daily). Include fields: `spend`, `reach`, `inline_link_clicks`, `actions`.

| Label | level | Campaign filter | Result action |
|-------|-------|-----------------|---------------|
| A | campaign | clueyplus-bof-leads | start_trial_website |
| B | campaign | clueyplus-tof-videoviews | thruplay |
| C | adset | clueyplus-bof-leads | start_trial_website |
| D | adset | clueyplus-tof-videoviews | thruplay |

Filter by campaign name using: `[{"field": "campaign.name", "operator": "CONTAIN", "value": "<name>"}]`

Large responses auto-save to disk. Note the file path for each call — you will need it in the next step.

---

## Step 4 — Parse Meta responses with PowerShell

```powershell
$repo = "C:\Users\RobNewman\Documents\workstuff"
New-Item -ItemType Directory -Force "$repo\reporting\data" | Out-Null

# Replace <path-A> … <path-D> with the actual saved file paths from Step 3
& "$repo\reporting\parse-meta.ps1" -FilePath "<path-A>" -ResultAction "start_trial_website" |
    Out-File "$repo\reporting\data\bof-campaign.json"  -Encoding UTF8

& "$repo\reporting\parse-meta.ps1" -FilePath "<path-B>" -ResultAction "thruplay" |
    Out-File "$repo\reporting\data\tof-campaign.json"  -Encoding UTF8

& "$repo\reporting\parse-meta.ps1" -FilePath "<path-C>" -ResultAction "start_trial_website" |
    Out-File "$repo\reporting\data\bof-adsets.json"    -Encoding UTF8

& "$repo\reporting\parse-meta.ps1" -FilePath "<path-D>" -ResultAction "thruplay" |
    Out-File "$repo\reporting\data\tof-adsets.json"    -Encoding UTF8
```

---

## Step 5 — Extract CRM signups

```powershell
& "$repo\reporting\extract-crm.ps1" -StartDate "<start_date>" -EndDate "<end_date>" |
    Out-File "$repo\reporting\data\signups.json" -Encoding UTF8
```

---

## Step 6 — Read all parsed data

Read these four JSON files:
- `reporting\data\bof-campaign.json` → `.byDate` gives daily BOF spend/reach/clicks/trials
- `reporting\data\tof-campaign.json` → `.byDate` gives daily TOF spend/reach/clicks/views
- `reporting\data\bof-adsets.json`   → `.byAdset` gives per-adset daily spend + totals
- `reporting\data\tof-adsets.json`   → `.byAdset` gives per-adset daily spend
- `reporting\data\signups.json`       → date-keyed signup counts

---

## Step 7 — Build the JS data block

Construct the full JS replacement for the DATA section. Follow this exact format:

```js
const DATES=['YYYY-MM-DD',...];  // every calendar day from start_date to end_date inclusive
const N=DATES.length;
const DL=DATES.map(d=>{const[,m,day]=d.split('-');return`${day}/${m}`;});

const BOF={
  spend:[...],    // from bof-campaign byDate, zero-fill missing dates
  trials:[...],   // results field
  reach:[...],
  clicks:[...]
};
const TOF={
  spend:[...],    // from tof-campaign byDate, zero-fill missing
  views:[...],    // results field (thruplay)
  reach:[...],
  clicks:[...]
};
const TOTAL_SPEND=DATES.map((_,i)=>+(BOF.spend[i]+TOF.spend[i]).toFixed(2));
const SIGNUPS=[...];  // from signups.json, zero-fill missing dates

function z(n){return Array(n).fill(0);}
function sp(obj,map){const a=z(N);Object.entries(map).forEach(([k,v])=>a[+k]=v);return a;}

// BOF_AS: one entry per adset. Use sp() with index-keyed objects.
// Index = position of that date in the DATES array.
// Include only adsets with spend > 0.
const BOF_AS={
  'AdSetName': sp(N,{0:12.34, 1:56.78, ...}),
  ...
};

// All-time totals per BOF adset (use full period data from bof-adsets byAdset[name].total)
const BOF_AS_TRIALS={
  'AdSetName': 23,
  ...
};
const BOF_AS_META={
  'AdSetName': {reach:12345, clicks:678},
  ...
};

// TOF adsets — same sp() pattern
const TOF_AS={
  'AdSetName': sp(N,{6:12.74, 7:31.44, ...}),
  ...
};
```

Round spend values to 2 decimal places. Keep integer counts as integers.

Write this block to `reporting\data\new-data.js`.

---

## Step 8 — Patch the dashboard

```powershell
& "$repo\reporting\patch-dashboard.ps1" -DataFile "$repo\reporting\data\new-data.js"
```

---

## Step 9 — Update header date range

In `clueyplus-dashboard.html`, find the `<p>` tag inside `<header>` and update the date range text to the new period in `DD Mon YYYY` format (e.g. `08 Mar 2026 – 07 May 2026`). Keep the rest of the header text unchanged.

---

## Step 10 — Commit and push

```powershell
git -C "C:\Users\RobNewman\Documents\workstuff" add clueyplus-dashboard.html
git -C "C:\Users\RobNewman\Documents\workstuff" commit -m "Update: Cluey+ dashboard — DD/MM/YY to DD/MM/YY"
git -C "C:\Users\RobNewman\Documents\workstuff" push
```

Use Australian date format (DD/MM/YY) in the commit message.
