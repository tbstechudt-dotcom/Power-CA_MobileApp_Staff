# Priority Sheet Flat Search & Client Selection FAB

Two related UX changes to make priority-job selection faster from the
Work Log entry flow.

---

## 1. Priority sheet: flat search results with status badges

### Before

The priority selection sheet rendered jobs as accordion-style cards
grouped by status (`Waiting`, `Planning`, `Progress`, `Work Done`,
`Delivery`). Searching kept the same grouped layout — to find a job
you had to first guess which status it was in, expand that group, and
then scan the list.

```
[Header: Select Priority Jobs]
[Search bar]
[v Waiting    (0 jobs)             ]
[v Planning   (2 jobs)             ]
[v Progress   (4 jobs)             ]
[v Work Done  (0 jobs)             ]
[v Delivery   (0 jobs)             ]
```

### After

When the search field is **empty**, the grouped accordion stays — it is
still the easier shape for browsing the full catalog.

When the user types a search query, the sheet switches to a **flat
single list of every matching job across all statuses**, with each
row carrying a small **status pill in its right-hand corner**:

```
[Header: Select Priority Jobs]
[Search bar: "aral"]
[ [ ] Audit FY24      Planning  ]
[ [ ] Tax review      Progress  ]
[ [ ] GST filing      Progress  ]
[ ...                           ]
```

Each row contains:

- Checkbox (left) — toggles whether the job is selected
- Job description (title, single line, ellipsised)
- Client name with `business_rounded` icon (in primary color)
- Job UID (`job_uid`)
- Status pill in the right corner, color-matched to the status
  (yellow Waiting, blue Planning, green Progress, teal Work Done,
  purple Delivery)

If no jobs match, the list shows a centered `No jobs match "<query>"`
placeholder instead.

### Implementation

- New helper `_buildFlatSearchResults({...})` on
  `_WorkLogEntryFormPageState`. It iterates `_statusConfigs`, runs the
  existing `_getFilteredJobsByStatus` against each one, and produces a
  single `List<Widget>` of job rows.
- The `Expanded(ListView(...))` inside `_showPrioritySelectionDialog`
  now picks between `_buildFlatSearchResults(...)` (when
  `searchQuery.isNotEmpty`) and the original grouped category builder
  (when empty).
- The status pill uses the existing
  `config['color'] as Color` from `_statusConfigs`, so any future
  status added there picks up correct colors automatically.

### Files

- [`lib/features/home/presentation/pages/work_log_entry_form_page.dart`](../lib/features/home/presentation/pages/work_log_entry_form_page.dart)
  - `_buildFlatSearchResults(...)` — new method
  - `_showPrioritySelectionDialog` — `ListView.children` switched to
    a `searchQuery.isNotEmpty ? ... : ...` ternary

---

## 2. Select Client sheet: priority floating button

### Before

The Select Client bottom sheet showed the full alphabetical client list
with a search field. The only way for a user who *actually* wanted to
work on a priority job was to back out, find the priority option in the
form, and open the priority sheet from there.

### After

A wide, pill-shaped **Priority** button now floats at the bottom-center
of the Select Client sheet:

```
+--------------------------------+
| Select Client      178 clients |
| [Search client name...]        |
| BALASUBRAMANIAM R              |
| RENUKADEVI SRINIVASAN          |
| SHREE TEXTILES                 |
| ...                            |
|                                |
|   +------------------------+   |
|   |  *  Priority           |   |
|   +------------------------+   |
+--------------------------------+
```

Behavior on tap:

1. Pops the Select Client sheet
2. Opens `_showPrioritySelectionDialog()` immediately

So the user goes Select Client -> Priority sheet in one tap, without
having to manually back out to the form first.

### Implementation

- The Select Client sheet's `DraggableScrollableSheet` `builder` now
  returns a `Stack` containing the existing `Column` plus a
  `Positioned(left: 24.w, right: 24.w, bottom: 16.h, child: ...)` that
  centers the button horizontally with 24w margins.
- The button itself is an `ElevatedButton.icon` (52h tall, 28r pill
  radius) using `AppTheme.primaryColor`. Icon is `Icons.star_rounded`,
  label "Priority".
- `onPressed` is `Navigator.pop(context); _showPrioritySelectionDialog();`
  — the original sheet closes before the priority sheet opens so the
  back stack stays sane.

### Files

- [`lib/features/home/presentation/pages/work_log_entry_form_page.dart`](../lib/features/home/presentation/pages/work_log_entry_form_page.dart)
  - The Select Client `showModalBottomSheet` `builder` wraps its
    `Column` in a `Stack` and adds a `Positioned` Priority button

---

## Why these two together

Both changes shorten the path from "I want to log work on a priority
job" to "the priority sheet is open in front of me with the job I want
already visible." Before, that flow needed at least three taps and
required the user to know which status bucket the job lived in. Now
it's two taps (open Select Client -> tap Priority) plus a quick
search to land on a single flat list with the status of each match
already visible at a glance.
