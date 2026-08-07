# 60-Minute GPSTracker Interview

This folder contains the complete interviewer package for the reduced
60-minute variant.

Candidate repository:

```text
https://git.c3.zone/benjabar421/interview-candidate-60
```

Current candidate baseline:

```text
Commit: c9ece66
Visible qualification: 6 passed, 14 failed, 20 total
Reference qualification: 20/20
Held-out evaluation: 24/24
```

## Files

| File | Purpose |
|---|---|
| `INTERVIEWER-RUNBOOK.md` | Minute-by-minute script for running the session |
| `TECHNICAL-GUIDE.md` | Plain-language system explanation, issues, snippets, and review cues |
| `QUICK-GUIDE.md` | Short administration, scope, timing, and scoring reference |
| `reference-solution.patch` | Six-file reference implementation for the reduced scope |
| `evaluate-candidate.sh` | Trusted 20-visible/24-hidden candidate evaluator |

Shared hidden-test source remains under `interviewer/tests/` because both the
full and reduced interview variants use it.

## Preparation

```bash
git clone \
  https://git.c3.zone/benjabar421/interview-candidate-60.git \
  candidate-workspace

cd candidate-workspace
git switch -c interview-session c9ece66
./scripts/build.sh
./scripts/test.sh
```

Expected baseline:

```text
20 total
6 passed
14 failed
```

## Reference Verification

```bash
git -C /path/to/candidate-workspace apply \
  /path/to/interview/60-minute/reference-solution.patch

/path/to/candidate-workspace/scripts/verify.sh
```

Expected result: `20/20`.

## Held-Out Evaluation

```bash
./60-minute/evaluate-candidate.sh \
  /path/to/candidate-workspace
```

Expected complete result:

```text
qualification=20/20
hidden=24/24
```
