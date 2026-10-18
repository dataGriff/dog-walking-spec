Feature: Scheduling walks
  As a dog walker
  I want to book walks for my clients' dogs
  So that my day is planned and every walk is guaranteed to reach my records

  These scenarios are acceptance criteria, not suggestions. An
  implementation that fails any of them is wrong. If a scenario is
  itself wrong, that is a versioned change to this file.

  Every operation needs the walker's session token in the bearer_auth
  header, and a walker only ever sees their own walks.

  Background:
    Given the walker "walker-anna" is signed in
    And the walker has a dog "Biscuit"
    And the walker has a dog "Rex"

  Scenario: A walk is scheduled and its event is guaranteed
    When the walker schedules a 45 minute walk for "Biscuit" and "Rex" via scheduleWalk
    Then the response status is 201
    And the walk status is "scheduled"
    And the walk carries a walk_id, the scheduled_at, duration_minutes 45, both dog_ids, the notes and created_at
    And a "WalkScheduled" event is guaranteed to be published for the walk

  Scenario: The walk and its event succeed or fail together
    Given event publication is unavailable
    When the walker schedules a 30 minute walk for "Biscuit" via scheduleWalk
    Then the response status is 201
    And the "WalkScheduled" event is published once publication recovers
    And no walk ever exists without its "WalkScheduled" event

  Scenario: Walk events are CloudEvents envelopes
    When the walker schedules a 45 minute walk for "Biscuit" and "Rex" via scheduleWalk
    Then a "WalkScheduled" event is published on "walks.scheduled.v1"
    And the envelope carries specversion "1.0", a unique id and a time
    And the envelope source is /walks and its type is com.hungovercoders.walks.scheduled.v1
    And the envelope subject is the walk_id, with datacontenttype "application/json"
    And the data carries the walk_id, walker_id, scheduled_at, duration_minutes and dog_ids
    And handlers dedupe on the envelope id, not the natural key

  Scenario: A walk can be fetched by its id
    Given the walker scheduled a walk for "Biscuit"
    When the walk is fetched by walk_id via getWalk
    Then the response status is 200
    And the walk carries the walk_id, scheduled_at, duration_minutes, dog_ids, status, notes and created_at

  Scenario: Fetching an unknown walk returns 404
    When an unknown walk_id is fetched via getWalk
    Then the response status is 404
    And the problem body carries an error_code and message

  Scenario: Walks are listed soonest first
    Given the walker scheduled a walk for "Biscuit" at "2026-11-02T09:00:00Z"
    And the walker scheduled a walk for "Rex" at "2026-11-01T09:00:00Z"
    When the walks are listed via listWalks
    Then the response status is 200
    And the walks list carries the "Rex" walk before the "Biscuit" walk

  Scenario: Walks are listed for a window of scheduled times
    Given the walker scheduled a walk for "Biscuit" at "2026-11-02T09:00:00Z"
    And the walker scheduled a walk for "Rex" at "2026-11-09T09:00:00Z"
    When the walks are listed via listWalks with scheduled_from "2026-11-02T00:00:00Z" and scheduled_to "2026-11-03T00:00:00Z"
    Then the response status is 200
    And the walks list carries the "Biscuit" walk but not the "Rex" walk

  Scenario: Walks are listed by status
    Given the walker scheduled a walk for "Biscuit"
    And the walker scheduled a walk for "Rex" and cancelled it because "client_request"
    When the walks are listed via listWalks with status "cancelled"
    Then the response status is 200
    And the walks list carries the "Rex" walk but not the "Biscuit" walk

  Scenario: A scheduled walk is rescheduled in place
    Given the walker scheduled a walk for "Biscuit"
    When the walk's scheduled_at and duration_minutes are changed via updateWalk
    Then the response status is 200
    And the walk's scheduled_at and duration_minutes are the new values
    And the walk's dog_ids and notes are unchanged
    And the walk status is still "scheduled"

  Scenario: A walk that has started cannot be amended
    Given the walker scheduled a walk for "Biscuit" and started it
    When the walk's duration_minutes is changed via updateWalk
    Then the response status is 409
    And the problem body carries an error_code and message

  Scenario: Another walker's walk is not visible
    Given the walker "walker-omar" scheduled a walk for their dog "Mango"
    When the walker "walker-anna" fetches that walk_id via getWalk
    Then the response status is 404
    And the walker "walker-anna" does not see the "Mango" walk via listWalks

  Scenario: A request without a session token is rejected
    When the walks are listed via listWalks without a bearer_auth token
    Then the response status is 401
    And the problem body carries an error_code and message

  Scenario Outline: A walk needs at least one of the walker's dogs and a positive duration
    When the walker schedules a walk with <problem> via scheduleWalk
    Then the response status is 400
    And the problem body carries an error_code and message

    Examples:
      | problem                                     |
      | no dog_ids                                  |
      | a dog_id that is not one of the walker's dogs |
      | a duration_minutes of 0                     |
