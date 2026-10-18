# ADR-001: A walk and its event are written together

## Status

Accepted.

## Context

`scheduleWalk`, `completeWalk` and `cancelWalk` each promise an event:
a walk is never persisted without its `WalkScheduled`, never closed
without its `WalkCompleted` or `WalkCancelled`. The features say so in
as many words ("succeed or fail together"). Cloudflare D1 and Cloudflare
Queues are separate systems with no shared transaction, so a write to
one followed by a send to the other can lose the second half.

## Decision

The implementation writes the walk row and an outbox row in one D1
batch, and a relay publishes outbox rows to the queue afterwards,
marking each sent. The relay runs on the request's `waitUntil` for
latency and on a cron trigger for recovery, so an unavailable queue
delays the event but never loses it. Consumers dedupe on the envelope
`id`, so a relay retry that publishes twice is harmless.

## Consequences

- The 201 for `scheduleWalk` means "the walk and its event are
  committed", not "the event has been delivered".
- Delivery is at-least-once; every consumer, the history tables in the
  data contract included, dedupes on `event_id`.
- Ordering holds per `walk_id` only.
