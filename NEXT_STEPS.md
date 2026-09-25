# Next steps: Weekly Trial

Do these on the main laptop before shipping the Weekly Trial
(branch `claude/dreamy-johnson-rwr44y`).

## 1. Deploy the Firestore rules and indexes

From the repo root:

```
firebase deploy --only firestore:rules,firestore:indexes
```

Without this, the Trial still plays, but posting scores and the Weekly and
Monthly boards fail: the old rules refuse the new `trial_weeks` and
`trial_months` collections. The new indexes can take a few minutes to build
after the deploy. Until they finish, the Country and City tabs on the Trial
boards return an error.

## 2. Test on a real device against real Firebase

Everything so far was tested with a fake backend.

- [ ] Signed in: open Ranks → WEEKLY → ENTER THE TRIAL. Play a minute, EXIT,
      and pull to refresh: your row appears, highlighted, with a "YOU #n" line.
- [ ] MONTHLY tab shows your points for this week.
- [ ] Country / City chips work on the Weekly and Monthly tabs (needs the
      indexes from step 1).
- [ ] As a guest: the Trial plays, and signing in afterwards keeps that
      week's run and posts it.
- [ ] Leave the Trial for 10+ minutes, come back: "While you were away…"
      shows about half-rate earnings.
- [ ] The leaderboard and Trial walkthroughs show once, and the ? button
      replays them.
- [ ] Trophy on the main screen shows an amber dot when the week's Trial
      hasn't been entered (only after the main tutorial is done).
- [ ] Main game keeps earning while you're in the Trial.

Delete this file once everything checks out.
