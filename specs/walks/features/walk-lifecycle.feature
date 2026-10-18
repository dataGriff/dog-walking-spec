Feature: Walking, completing and cancelling walks
  As a dog walker
  I want to mark each walk started, completed or cancelled
  So that clients and my records reflect what actually happened

  These scenarios are acceptance criteria, not suggestions. An
  implementation that fails any of them is wrong. If a scenario is
  itself wrong, that is a versioned change to this file.

  Background:
    Given the walker "walker-anna" is signed in
    And the walker has a dog "Biscuit"
    And the walker scheduled a walk for "Biscuit"

  Scenario: A scheduled walk is started
    When the walk is started via startWalk
    Then the response status is 200
    And the walk status is "in_progress"
    And the walk carries a started_at

  Scenario: Only a scheduled walk can be started
    Given the walk was started via startWalk
    When the walk is started via startWalk
    Then the response status is 409
    And the problem body carries an error_code and message

  Scenario: A walk in progress is completed and its event is guaranteed
    Given the walk was started via startWalk
    When the walk is completed with notes "Biscuit found a stick" via completeWalk
    Then the response status is 200
    And the walk status is "completed"
    And the walk carries a completed_at and the notes
    And a "WalkCompleted" event is guaranteed to be published for the walk

  Scenario: Completion notes must be text
    When the walk is completed with notes that are not text via completeWalk
    Then the response status is 400
    And the problem body carries an error_code and message
    And the walk status is still "scheduled" when fetched via getWalk

  Scenario: A scheduled walk can be completed without being started
    When the walk is completed via completeWalk
    Then the response status is 200
    And the walk status is "completed"
    And the walk carries a completed_at but no started_at

  Scenario: Completion is a CloudEvents envelope
    Given the walk was started via startWalk
    When the walk is completed via completeWalk
    Then a "WalkCompleted" event is published on "walks.completed.v1"
    And the envelope carries specversion "1.0", a unique id and a time
    And the envelope source is /walks and its type is com.hungovercoders.walks.completed.v1
    And the envelope subject is the walk_id, with datacontenttype "application/json"
    And the data carries the walk_id, walker_id, scheduled_at, started_at, completed_at, duration_minutes and dog_ids
    And handlers dedupe on the envelope id, not the natural key

  Scenario: The completion and its event succeed or fail together
    Given event publication is unavailable
    When the walk is completed via completeWalk
    Then the response status is 200
    And the "WalkCompleted" event is published once publication recovers
    And no completed walk ever exists without its "WalkCompleted" event

  Scenario: A walk is cancelled for a reason and its event is guaranteed
    When the walk is cancelled because "client_request" via cancelWalk
    Then the response status is 200
    And the walk status is "cancelled"
    And the walk carries a cancelled_at and the cancellation_reason "client_request"
    And a "WalkCancelled" event is guaranteed to be published for the walk

  Scenario: Cancellation is a CloudEvents envelope too
    When the walk is cancelled because "bad_weather" via cancelWalk
    Then a "WalkCancelled" event is published on "walks.cancelled.v1"
    And the envelope carries specversion "1.0", a unique id and a time
    And the envelope source is /walks and its type is com.hungovercoders.walks.cancelled.v1
    And the envelope subject is the walk_id, with datacontenttype "application/json"
    And the data carries the walk_id, walker_id, scheduled_at, cancelled_at and reason
    And handlers dedupe on the envelope id, not the natural key

  Scenario Outline: A walk is only cancelled for a declared reason
    When the walk is cancelled because "<reason>" via cancelWalk
    Then the cancellation is accepted and records that reason
    And a reason outside this list is rejected with a 400

    Examples:
      | reason             | meaning                                             |
      | client_request     | the client asked for the walk to be cancelled       |
      | walker_unavailable | the walker could not make the walk                  |
      | bad_weather        | the weather made the walk unsafe or unpleasant      |
      | dog_unwell         | one of the dogs was not well enough to walk         |

  Scenario Outline: A closed walk stays closed
    Given the walk was <closed>
    When the walk is <attempted>
    Then the response status is 409
    And the problem body carries an error_code and message

    Examples:
      | closed                               | attempted                                      |
      | completed via completeWalk           | completed via completeWalk                     |
      | completed via completeWalk           | cancelled because "client_request" via cancelWalk |
      | cancelled because "dog_unwell" via cancelWalk | completed via completeWalk            |
      | cancelled because "dog_unwell" via cancelWalk | started via startWalk                 |

  Scenario: Every lifecycle event lands in the walk history
    Given the walk was started via startWalk
    When the walk is completed via completeWalk
    Then the history table walk_scheduled_events carries one row for the walk with its event_id, event_type, event_source, event_time, walk_id, walker_id, scheduled_at, duration_minutes and dog_ids
    And the history table walk_completed_events carries one row for the walk with its started_at and completed_at
    And replaying the same envelope id adds no second row

  Scenario: A cancellation lands in the walk history with its reason
    When the walk is cancelled because "walker_unavailable" via cancelWalk
    Then the history table walk_cancelled_events carries one row for the walk with its cancelled_at and reason
    And the history table walk_completed_events carries no row for the walk
