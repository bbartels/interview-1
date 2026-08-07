# GPSTracker 60-Minute Technical Guide

This document is for interviewers. It explains the reduced exercise in simple
terms, shows the intended kinds of fixes, and lists common mistakes to watch for.

The complete executable reference is:

```text
60-minute/reference-solution.patch
```

The snippets below are explanatory examples, not additional candidate
requirements.

## What GPSTracker Does

GPSTracker receives GPS positions from devices such as vehicles or equipment.

Each update contains:

```text
device identity
producer epoch
sequence number
latitude and longitude
observation time
```

The main data flow is:

```text
Device gateway
    |
    v
DeviceGrain, one actor for each device
    |
    +--> PushNotifierGrain
    |        |
    |        +--> active service host A
    |        `--> active service host B
    |
    `--> DeviceGeofenceGrain
             |
             `--> enter or exit transition
```

Microsoft Orleans grains are actors. A grain has one logical identity and owns
its own state. Calls to one ordinary grain activation are normally serialized,
but some grains in this fixture are reentrant and can process another call while
an earlier call awaits external work.

The reduced interview asks the candidate to repair four areas:

1. Device history and velocity.
2. Notification batching and failure isolation.
3. Geofence transitions and deterministic event IDs.
4. Host registration, lease fencing, and observer cleanup.

HTTP device endpoints, real process replacement, webhook delivery, and receiver
idempotency are not required in the 60-minute version.

## 1. Device History

### The Problem In Simple Terms

GPS messages can arrive late, twice, or out of order. The device grain must not
let an old message replace a newer location.

An update is identified by:

```text
(Epoch, Sequence)
```

Epoch is compared first. Sequence is compared only within the epoch.

Examples:

| Current | Incoming | Expected |
|---|---|---|
| `(2, 10)` | `(2, 11)` | Accept |
| `(2, 10)` | `(2, 10)` | Reject duplicate |
| `(2, 10)` | `(2, 9)` | Reject stale update |
| `(2, 10)` | `(1, 999)` | Reject older epoch |
| `(2, 10)` | `(3, 1)` | Accept new epoch |

Within one epoch, time must also move forward. A newer sequence with an older or
equal observation time is rejected.

### Validation

The grain must reject a message when:

- Its device ID does not match the grain key.
- Epoch is negative.
- Sequence is zero or negative.
- Latitude is not finite or outside `[-90, 90]`.
- Longitude is not finite or outside `[-180, 180]`.
- Observation time is missing.

Validation happens before state changes or downstream calls.

### Example Ordering Fix

```csharp
Validate(message);

var previous = _snapshot?.Message;
if (previous is not null)
{
    var staleId = message.UpdateId.CompareTo(previous.UpdateId) <= 0;
    var staleTime =
        message.UpdateId.Epoch == previous.UpdateId.Epoch &&
        message.ObservedAt <= previous.ObservedAt;

    if (staleId || staleTime)
    {
        return new DeviceUpdateResult(false, previous.UpdateId);
    }
}
```

The important point is that rejection returns before:

```text
snapshot replacement
notification enqueue
geofence observation
```

### Velocity

The first update in an epoch has no trustworthy previous point, so speed is
unknown.

Later updates use:

```text
speed = great-circle distance / elapsed seconds
```

Latitude and longitude are supplied in degrees. `Math.Sin`, `Math.Cos`, and
other trigonometric functions expect radians.

### Example Great-Circle Calculation

```csharp
static double ToRadians(double degrees) => degrees * Math.PI / 180;

var latitude1 = ToRadians(first.Latitude);
var latitude2 = ToRadians(second.Latitude);
var latitudeDelta = latitude2 - latitude1;
var longitudeDelta = Math.IEEERemainder(
    ToRadians(second.Longitude - first.Longitude),
    2 * Math.PI);

var sinLatitude = Math.Sin(latitudeDelta / 2);
var sinLongitude = Math.Sin(longitudeDelta / 2);
var haversine =
    (sinLatitude * sinLatitude) +
    (Math.Cos(latitude1) * Math.Cos(latitude2) *
     sinLongitude * sinLongitude);

haversine = Math.Clamp(haversine, 0, 1);

var distance = 2 * 6_371_008.8 * Math.Atan2(
    Math.Sqrt(haversine),
    Math.Sqrt(1 - haversine));
```

`Math.IEEERemainder` ensures that movement across longitude `180/-180` uses the
short path around the globe.

### State Linearization

For an accepted update, the grain should update its snapshot before awaiting
downstream admission:

```csharp
_snapshot = new DeviceSnapshot(message, speed);
await _notifier.EnqueueAsync(new LocationUpdate(message, speed));
await _geofence.ObserveAsync(...);
```

This gives later reentrant calls a clear accepted high watermark.

### What To Look Out For

- Comparing only sequence and ignoring epoch.
- Accepting equal sequence numbers.
- Checking timestamp before checking epoch.
- Updating state before validation.
- Calculating speed from the last received instead of last accepted update.
- Passing degrees directly to `Math.Cos`.
- Using Euclidean distance across the antimeridian.
- Adding a global dictionary or lock for every device.
- Moving snapshot assignment after an awaited downstream call.

## 2. Notification Distribution

### The Problem In Simple Terms

Accepted device updates are placed in a FIFO queue. A flush sends a fixed prefix
of that queue to every active service host.

For 205 messages, the batches are:

```text
100
100
5
```

The order must remain `1..205`.

### Fixed Prefix

If a flush starts with 50 messages and another message arrives while delivery is
blocked, the active flush processes only the original 50. The later message is
for a later flush.

Capture the count before the first await:

```csharp
var messageCount = _queue.Count;
_activeFlush = FlushCoreAsync(messageCount);
```

### Directory Before Dequeue

The active-host lookup happens before queue removal:

```csharp
var hubs = await directory.GetActiveHubsAsync();

var updates = ImmutableArray.CreateBuilder<LocationUpdate>(messageCount);
for (var index = 0; index < messageCount; index++)
{
    updates.Add(_queue.Dequeue());
}
```

If directory lookup fails, the queue is unchanged.

Once messages are dequeued, delivery is best effort and at most once.

### Batching And Fan-Out

```csharp
foreach (var chunk in updates.ToImmutable().Chunk(100))
{
    var batch = new VelocityBatch(chunk.ToImmutableArray());
    var results = await Task.WhenAll(
        hubs.Select(hub => DeliverAsync(hub, batch)));

    successful += results.Count(result => result);
    failed += results.Count(result => !result);
}
```

Batches are processed sequentially. Hosts within one batch can be attempted in
parallel.

### Failure Isolation

```csharp
private async Task<bool> DeliverAsync(
    HubRegistration registration,
    VelocityBatch batch)
{
    try
    {
        await registration.Hub.BroadcastUpdatesAsync(batch);
        return true;
    }
    catch (Exception error)
    {
        logger.LogWarning(error, "Delivery failed");
        return false;
    }
}
```

One failed host must not stop healthy hosts or later batches.

### Overlapping Flushes

Two flush calls must not process the same messages concurrently.

```csharp
if (!_activeFlush.IsCompleted)
{
    return new ValueTask<FlushReport>(_activeFlush);
}
```

### What To Look Out For

- One batch containing every queued message.
- Dequeueing before directory lookup.
- Retrying failed host deliveries despite the at-most-once contract.
- Allowing one exception to abort healthy-host delivery.
- Re-querying the host directory for each batch.
- Processing all batches concurrently and breaking per-host order.
- Absorbing messages which arrived after flush started.
- Using a process-wide lock or replacing the grain queue with static state.

## 3. Geofence Transitions

### The Problem In Simple Terms

A geofence is a circle on the map. The grain remembers whether one device is
inside or outside it.

```text
outside -> inside = enter
inside -> outside = exit
same side         = no event
```

The first observation only establishes initial state. It does not emit.

### Correct Transition State

```csharp
var previousInside = _snapshot?.IsInside;
var isInside = distance <= geofence.RadiusMetres;

_snapshot = new GeofenceSnapshot(geofence, location, isInside);

if (previousInside is null || previousInside == isInside)
{
    return null;
}
```

The boundary is inside because the comparison uses `<=`.

### Ordering

The geofence grain independently rejects duplicate and stale source updates:

```csharp
if (_snapshot is { } snapshot &&
    location.UpdateId.CompareTo(snapshot.LastObserved.UpdateId) <= 0)
{
    return null;
}
```

This protects direct geofence calls as well as the normal device path.

### Stable Event IDs

```csharp
var eventId = string.Create(
    CultureInfo.InvariantCulture,
    $"{geofence.Id}:{location.DeviceId}:" +
    $"{location.UpdateId.Epoch}:{location.UpdateId.Sequence}:" +
    transition.ToString().ToLowerInvariant());
```

Example:

```text
london-hq:42:3:18:enter
```

Do not use a random GUID, current time, or attempt number.

### Immutable Definition

One grain activation must not silently replace its geofence definition:

```csharp
if (_snapshot is { } snapshot && snapshot.Geofence != geofence)
{
    throw new InvalidOperationException(
        "A device geofence definition cannot be replaced.");
}
```

### What To Look Out For

- Emitting `enter` for the first inside observation.
- Treating the exact boundary as outside.
- Accepting stale locations and rewinding occupancy.
- Resetting occupancy when epoch changes.
- Emitting repeatedly while a device remains inside.
- Random event IDs.
- Silently replacing a geofence definition.
- Spending time implementing webhook HTTP delivery, which is out of scope here.

## 4. Host Registration And Lease Fencing

### The Problem In Simple Terms

Every service host registers a relay in a cluster-wide directory. A host may
restart or re-register, so every registration receives a lease epoch.

Example:

```text
old host registration: lease 7
replacement:           lease 8
```

Delayed cleanup from lease 7 must not remove lease 8.

### Lease Checks

```csharp
if (!_registrations.TryGetValue(lease.Host, out var registration) ||
    registration.Lease != lease)
{
    return false;
}
```

Use this check for both refresh and unregister.

### Active Membership Filtering

```csharp
var snapshot = membership.CurrentSnapshot;

foreach (var (host, registration) in _registrations.ToArray())
{
    var status = snapshot.GetSiloStatus(host);

    if (status == SiloStatus.Dead)
    {
        _registrations.Remove(host);
    }
    else if (status == SiloStatus.Active)
    {
        active.Add(registration);
    }
}
```

Joining, stopping, dead, and fabricated hosts are not returned for fan-out.

### Lifecycle Ownership

The lifecycle session owns:

```text
the observer implementation
the Orleans observer proxy
the current lease
```

The implementation object must remain strongly referenced. Keeping only the
proxy allows garbage collection to remove the real callback target.

```csharp
private readonly IRemoteLocationHub _observer;
private readonly IRemoteLocationHub _reference;
```

### Idempotent Start And Refresh

```csharp
public async ValueTask StartAsync()
{
    ObjectDisposedException.ThrowIf(_disposed, this);
    _lease ??= await _client.RegisterAsync(_reference);
}

public async ValueTask RefreshAsync()
{
    ObjectDisposedException.ThrowIf(_disposed, this);

    if (_lease is null)
    {
        await StartAsync();
        return;
    }

    if (!await _client.RefreshAsync(_lease, _reference))
    {
        _lease = await _client.RegisterAsync(_reference);
    }
}
```

### Cleanup

```csharp
public async ValueTask DisposeAsync()
{
    if (_disposed)
    {
        return;
    }

    _disposed = true;
    try
    {
        if (_lease is not null)
        {
            await _client.UnregisterAsync(_lease);
        }
    }
    finally
    {
        _client.DeleteReference(_reference);
    }
}
```

Deletion occurs even if unregister fails.

### What To Look Out For

- Ignoring lease epoch and matching only host address.
- Removing a replacement registration with stale cleanup.
- Returning inactive hosts.
- Registering a new lease on every refresh.
- Creating multiple observer references.
- Keeping only the proxy and allowing the observer implementation to be
  garbage-collected.
- Deleting the proxy before unregistering.
- Skipping deletion when unregister throws.
- Making disposal non-idempotent.

## Integration Points

The four repairs interact in a few important ways:

- Device rejection must happen before notifier and geofence calls.
- Device payload and speed must be preserved when queued.
- Notifier fan-out uses only active, currently leased host registrations.
- Host lifecycle fixes must not change delivery ordering.
- Geofence ordering uses the same source update identity as device ordering.

Candidates should run focused scenarios during development and the complete
20-scenario qualification before time expires.

## Qualification Map

| Area | Visible Cases | Held-Out Cases |
|---|---:|---:|
| Device history | 9 | 10 |
| Notification distribution | 4 | 6 |
| Geofence transitions | 3 | 4 |
| Host registration | 4 | 4 |
| **Total** | **20** | **24** |

## Out Of Scope For 60 Minutes

- Device HTTP endpoints.
- Real two-process host replacement.
- Webhook HTTP delivery and retry.
- Receiver idempotency.
- Durable queues or state.
- Authentication and signatures.
- Browser acknowledgment.
- Exactly-once delivery.

If a candidate spends substantial time in these areas, remind them to re-read
the out-of-scope section without identifying the required implementation files.

## Final Evidence

Candidate gate:

```bash
./scripts/verify.sh
```

Expected completion:

```text
20 passed
0 failed
```

Interviewer gate:

```bash
./60-minute/evaluate-candidate.sh \
  /path/to/candidate-workspace
```

Expected completion:

```text
qualification=20/20
hidden=24/24
```
