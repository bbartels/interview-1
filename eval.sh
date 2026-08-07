#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: %s <candidate-worktree>\n' "$0" >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
candidate_root="$(cd "$1" && pwd)"
evaluation_root="$(mktemp -d)"
trap 'rm -rf "$evaluation_root"' EXIT

if find "$candidate_root" -type l -print -quit | grep -q .; then
  printf 'Candidate worktree contains a symbolic link.\n' >&2
  exit 1
fi

git -C "$repo_root" archive HEAD | tar -x -C "$evaluation_root"

editable_files=(
  src/GPSTracker.Edge/HubRegistrationSession.cs
  src/GPSTracker.Grains/DeviceGeofenceGrain.cs
  src/GPSTracker.Grains/DeviceGrain.cs
  src/GPSTracker.Grains/GeoMath.cs
  src/GPSTracker.Grains/HubListGrain.cs
  src/GPSTracker.Grains/PushNotifierGrain.cs
)

for relative_path in "${editable_files[@]}"; do
  if [[ ! -f "$candidate_root/$relative_path" ]]; then
    printf 'Missing editable source file: %s\n' "$relative_path" >&2
    exit 1
  fi
  cp "$candidate_root/$relative_path" "$evaluation_root/$relative_path"
done

while IFS= read -r candidate_file; do
  relative_path="${candidate_file#"$candidate_root/"}"
  if [[ ! -e "$evaluation_root/$relative_path" ]]; then
    cp "$candidate_file" "$evaluation_root/$relative_path"
  fi
done < <(find "$candidate_root/src/GPSTracker.Grains" -maxdepth 1 -type f -name '*.cs')

public_filter='FullyQualifiedName~GPSTracker.AcceptanceTests.DeviceTests|FullyQualifiedName~GPSTracker.AcceptanceTests.NotifierTests|FullyQualifiedName~GPSTracker.AcceptanceTests.EdgeTests|FullyQualifiedName~GPSTracker.AcceptanceTests.HubDirectoryTests|FullyQualifiedName=GPSTracker.AcceptanceTests.GeofenceTests.FirstObservationSeedsStateWithoutEmitting|FullyQualifiedName=GPSTracker.AcceptanceTests.GeofenceTests.OutsideInsideOutsideProducesStableEvents|FullyQualifiedName=GPSTracker.AcceptanceTests.GeofenceTests.StaleCrossingCannotRewindOccupancy'
hidden_filter='FullyQualifiedName~GPSTracker.HiddenTests.DeviceSemanticsTests|FullyQualifiedName~GPSTracker.HiddenTests.NotifierSemanticsTests|FullyQualifiedName~GPSTracker.HiddenTests.DirectoryAndLifecycleTests|FullyQualifiedName=GPSTracker.HiddenTests.GeofenceSemanticsTests.FirstInsideObservationDoesNotEmit|FullyQualifiedName=GPSTracker.HiddenTests.GeofenceSemanticsTests.SameSideObservationsDoNotRepeatTransitions|FullyQualifiedName=GPSTracker.HiddenTests.GeofenceSemanticsTests.GreaterEpochPreservesOccupancyAndEmitsRealTransition|FullyQualifiedName=GPSTracker.HiddenTests.GeofenceSemanticsTests.DefinitionCannotChangeForOneActivation'

mkdir -p "$evaluation_root/.artifacts/public"
mkdir -p "$evaluation_root/.artifacts/hidden"

(
  cd "$evaluation_root"
  dotnet restore GPSTracker.slnx --locked-mode
  dotnet build GPSTracker.slnx --no-restore --no-incremental
  dotnet restore tests/GPSTracker.AcceptanceTests/GPSTracker.AcceptanceTests.csproj --locked-mode
  dotnet build tests/GPSTracker.AcceptanceTests/GPSTracker.AcceptanceTests.csproj --no-restore --no-incremental

  set +e
  dotnet test tests/GPSTracker.AcceptanceTests/GPSTracker.AcceptanceTests.csproj \
    --no-build \
    --filter "$public_filter" \
    --logger "console;verbosity=minimal" \
    --logger "trx;LogFileName=public.trx" \
    --results-directory .artifacts/public
  public_status=$?

  dotnet restore interviewer/tests/GPSTracker.HiddenTests/GPSTracker.HiddenTests.csproj --locked-mode
  dotnet test interviewer/tests/GPSTracker.HiddenTests/GPSTracker.HiddenTests.csproj \
    --no-restore \
    --filter "$hidden_filter" \
    --logger "console;verbosity=minimal" \
    --logger "trx;LogFileName=hidden.trx" \
    --results-directory .artifacts/hidden
  hidden_status=$?
  set -e

  printf '%s %s\n' "$public_status" "$hidden_status" > .artifacts/statuses
)

require_count() {
  local result_file="$1"
  local expected="$2"
  grep -q "total=\"$expected\"" "$result_file"
  grep -q "executed=\"$expected\"" "$result_file"
}

public_result="$evaluation_root/.artifacts/public/public.trx"
hidden_result="$evaluation_root/.artifacts/hidden/hidden.trx"
require_count "$public_result" 20
require_count "$hidden_result" 24
read -r public_status hidden_status < "$evaluation_root/.artifacts/statuses"

if [[ "$public_status" -ne 0 ]] || [[ "$hidden_status" -ne 0 ]]; then
  printf '60-minute evaluation failed: public=%s hidden=%s\n' "$public_status" "$hidden_status" >&2
  exit 1
fi

printf '60-minute evaluation passed: qualification=20/20 hidden=24/24\n'
