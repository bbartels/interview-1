# 60-Minute Interview Guide

Candidate repository:

```text
https://git.c3.zone/benjabar421/interview-candidate-60
```

Pinned baseline commit:

```text
c37c3ed
```

## Scope

The reduced interview covers only:

- Device identity, ordering, validation, and great-circle velocity.
- Notification FIFO batching and partial-host failure isolation.
- Geofence occupancy, transitions, stale suppression, and deterministic IDs.
- Active-host filtering, lease fencing, and observer lifecycle cleanup.

HTTP device endpoints, real process-host replacement, webhook delivery, and
receiver idempotency are explicitly out of scope.

## Timing

| Phase | Time |
|---|---:|
| Introduction and baseline | 5 minutes |
| Investigation and implementation | 40 minutes |
| Integration and final qualification | 15 minutes |

There is no separate debrief.

## Opening Script

Say:

> You have 60 minutes to restore the reduced GPSTracker qualification. The
> baseline builds and starts with 6 of 20 scenarios passing. Read `CANDIDATE.md`,
> run the qualification, and decide how to investigate it. You may run up to
> three coding agents concurrently, but you are responsible for reviewing every
> submitted change. Do not modify contracts, project files, scripts, or the
> qualification package. Finish with `./scripts/verify.sh`. There is no separate
> debrief, so reserve time for integration and your final run.

Do not name the three workstreams or suggest a decomposition.

## Time Calls

At 30 minutes remaining:

> You have 30 minutes remaining.

At 10 minutes remaining:

> You have 10 minutes remaining. Prioritize integration and the complete gate.

At 60 minutes:

> Time is complete. Stop agents and do not make further changes.

Record the final qualification result, Git status, agent assignments, and whether
the candidate reviewed delegated diffs.

## Evaluation

Run from the authoring repository:

```bash
./60-minute/evaluate-candidate.sh \
  /path/to/candidate-worktree
```

Complete result:

```text
Qualification: 20/20
Held-out:      24/24
```

## Scoring

| Area | Points |
|---|---:|
| Device history | 30 |
| Notification distribution | 30 |
| Host registration | 20 |
| Geofence transitions | 15 |
| Agent orchestration and verification | 5 |
| **Total** | **100** |

No complete final qualification caps the score at 84. Blind delegation or an
inability to explain submitted changes caps the score at 69. Protected-file or
qualification tampering is an integrity failure.

Reference implementation:

```text
60-minute/reference-solution.patch
```
