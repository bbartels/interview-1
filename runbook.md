# 60-Minute GPSTracker Interview Runbook

Candidate repository:

```text
https://git.c3.zone/benjabar421/interview-candidate-60
```

Candidate baseline commit:

```text
c9ece66
```

The session is exactly 60 minutes and has no separate debrief.

## Before The Candidate Arrives

Create a fresh workspace:

```bash
git clone \
  https://git.c3.zone/benjabar421/interview-candidate-60.git \
  candidate-workspace

cd candidate-workspace
git switch -c interview-session c9ece66
```

Verify the baseline:

```bash
./scripts/build.sh
./scripts/test.sh
```

Expected result:

```text
Total:  20
Passed: 6
Failed: 14
```

Confirm that the working tree is clean:

```bash
git status --short
```

Give every candidate the same machine, model access, package cache, tool
permissions, and maximum concurrency. Allow up to three concurrent coding
agents.

Do not give the candidate access to the authoring `interview` repository.

## Schedule

| Phase | Time |
|---|---:|
| Introduction and baseline | 5 minutes |
| Exploration and delegation | 10 minutes |
| Parallel implementation | 30 minutes |
| Integration and final qualification | 15 minutes |
| **Total** | **60 minutes** |

## Minute 0: Introduction

Say:

> You have 60 minutes to restore the reduced GPSTracker release qualification.
>
> The baseline builds successfully, but only 6 of 20 qualification scenarios
> pass.
>
> Read `CANDIDATE.md`, run the qualification, investigate the failures, repair
> the runtime, and finish with `./scripts/verify.sh`.
>
> You may run up to three coding agents concurrently. You decide whether to use
> them and how to divide the work.
>
> You remain responsible for every submitted change. Review agent-generated code
> and verify its claims before accepting it.
>
> Do not modify public contracts, project files, dependencies, lock files,
> scripts, or the qualification package. Do not weaken or suppress scenarios.
>
> There is no separate debrief, so reserve time inside the hour for integration
> and the final qualification run.
>
> I can clarify written requirements or help with confirmed environment
> failures, but I will not identify buggy files or suggest how to divide the
> work.
>
> Your time starts now.

Do not mention the four workstreams, suggest agent assignments, or identify
likely implementation files.

## Minutes 0-5: Baseline

The candidate should read `README.md` and `CANDIDATE.md`, then run:

```bash
./scripts/build.sh
./scripts/test.sh
```

Observe whether the candidate:

- Confirms the baseline before editing.
- Reads the out-of-scope section.
- Uses scenario output as evidence.
- Inspects architecture and upstream context.
- Forms hypotheses before changing code.
- Notices that several failures may be investigated independently.
- Reserves time for integration.

If the baseline is not exactly 6 passing and 14 failing, pause the clock and
investigate the environment.

## Minutes 5-15: Exploration And Delegation

Remain mostly silent.

At approximately minute 12, ask:

> Briefly tell me what you currently believe is failing and how you plan to
> investigate it.

Allow no more than two minutes. This happens inside the active clock.

Strong answers describe system outcomes, independent investigations, shared
integration points, measurable agent tasks, and time reserved for the final
gate.

Weak answers delegate the whole repository, give several agents overlapping
work, provide no acceptance criteria, or rely on agent summaries without review.

## Minutes 15-45: Implementation

Do not interrupt except for requirement questions, platform failures, protected
file changes, or time announcements.

### If Asked Where A Defect Is

Say:

> I cannot identify the implementation location. Use the requirements, scenario
> output, source, and upstream context.

### If Asked What Is In Scope

Say:

> Use the `Required Outcomes` and `Out Of Scope` sections in `CANDIDATE.md`.

### If The Candidate Works On HTTP Or Webhook Delivery

Say:

> Check the reduced interview's out-of-scope section before spending more time
> there.

### If Asked About Persistence

Say:

> Persistence, durable queues, and exactly-once delivery are outside the reduced
> exercise.

### If Asked To Modify Qualification

Say:

> The qualification package is protected. Repair the runtime behavior instead.

### If A Fixture Defect Is Reported

Ask:

> What evidence shows that the written requirement and qualification disagree?

For credible evidence, pause the clock, record and reproduce the issue, and
restore time lost to a confirmed fixture defect.

## Minute 30: Time Call

Say:

> You have 30 minutes remaining.

Do not add technical guidance.

## What To Observe

Strong agent assignments contain a specific outcome, relevant requirements,
clear ownership, constraints, a focused command, and expected evidence.

Look for:

- Useful parallel investigations.
- Non-overlapping edits.
- Candidate review of returned diffs.
- Independent verification of agent claims.
- Rejection or revision of weak output.
- Deliberate handling of shared integration points.
- Productive use of time while agents run.

Warning signs include overlapping agents, passive waiting, blind patch
acceptance, sleeps, process-wide locks, protected-file modifications, and work on
explicitly out-of-scope features.

## Private Technical Checklist

Do not give this section to the candidate.

### Device History

- Message device ID matches grain identity.
- Invalid epoch, sequence, and coordinates are rejected.
- Duplicate and stale updates have no effects.
- Time increases within an epoch.
- Greater epoch starts a velocity segment.
- Distance uses radians and shortest great-circle geometry.
- Rejected updates do not enter notifier or geofence paths.

### Notification Distribution

- FIFO ordering is preserved.
- 205 updates produce batches of 100, 100, and 5.
- Every batch reaches every active host snapshot.
- A failing host does not block a healthy host or later batches.
- Failed deliveries are not retried.
- Directory lookup happens before dequeue.
- Overlapping flushes do not duplicate delivery.

### Geofence Transitions

- First observation emits nothing.
- Outside to inside emits `enter`.
- Inside to outside emits `exit`.
- Same-side observations emit nothing.
- Boundary is inside.
- Stale input cannot rewind occupancy.
- Event IDs are deterministic.

### Host Registration

- Inactive hosts are excluded.
- New registration receives a newer lease.
- Stale refresh and unregister fail.
- Current lease can refresh and unregister.
- One observer implementation and reference are retained.
- Start and disposal are idempotent.
- Unregister precedes reference deletion.
- Deletion occurs even if unregister fails.

## Minute 50: Integration Call

Say:

> You have 10 minutes remaining. Prioritize integration, review, and the complete
> qualification. Do not start a new workstream unless it is required to unblock
> the final gate.

The candidate should now stop speculative investigation, collect agent results,
review diffs, resolve conflicts, and run the complete qualification.

## Minutes 50-60: Final Gate

The candidate should run:

```bash
./scripts/verify.sh
```

Successful result:

```text
Total:  20
Passed: 20
Failed: 0
```

They should also inspect:

```bash
git status
git diff --stat
git diff
```

If qualification still fails, they may continue until time expires.

## Minute 60: Stop

Say:

> Time is complete. Stop agents and do not make further changes. Leave the final
> qualification output and working tree visible.

Record:

```text
Final qualification result
Git status
Agents launched and their scopes
Agent changes accepted
Agent changes rejected or revised
Whether all accepted diffs were reviewed
Whether the complete qualification ran
```

There is no formal debrief.

## Post-Interview Evaluation

From the authoring repository, run:

```bash
./60-minute/evaluate-candidate.sh \
  /path/to/candidate-workspace
```

Complete result:

```text
Qualification: 20/20
Held-out:      24/24
```

Dedicated reference patch:

```text
60-minute/reference-solution.patch
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

| Score | Assessment |
|---:|---|
| 85-100 | Strong evidence |
| 70-84 | Meets expectations |
| 55-69 | Mixed evidence |
| Below 55 | Insufficient evidence |

No complete final qualification caps the score at 84. Blind delegation or an
inability to explain submitted code caps the score at 69. Protected-file or
qualification tampering is an integrity failure. Fabricated verification caps
the score at 49.

Because there is no formal debrief, assess technical ownership from behavior
during the session: agent prompts, diff review, integration decisions, and
responses to qualification failures.
