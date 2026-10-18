Feature: Managing clients
  As a dog walker
  I want to keep a roster of the clients I walk for
  So that every walk I schedule is for a dog I know and a person I can reach

  These scenarios are acceptance criteria, not suggestions. An
  implementation that fails any of them is wrong. If a scenario is
  itself wrong, that is a versioned change to this file.

  Every operation needs the walker's session token in the bearer_auth
  header, and a walker only ever sees their own records.

  Background:
    Given the walker "walker-anna" is signed in

  Scenario: A client is added to the roster
    When the walker adds a client named "Alice Ahmed" via createClient
    Then the response status is 201
    And the client carries a client_id, the name, and created_at
    And the client's email, phone, address and notes are the ones given

  Scenario: A client can be fetched by its id
    Given the walker has a client "Alice Ahmed"
    When the client is fetched by client_id via getClient
    Then the response status is 200
    And the client carries the client_id, name, email, phone, address, notes and created_at

  Scenario: The roster lists every client of the walker, newest first
    Given the walker has a client "Alice Ahmed"
    And the walker has a client "Ben Brooks"
    When the roster is listed via listClients
    Then the response status is 200
    And the clients list carries "Ben Brooks" before "Alice Ahmed"

  Scenario: A client's details are updated in place
    Given the walker has a client "Alice Ahmed"
    When the client's phone is changed via updateClient
    Then the response status is 200
    And the client's phone is the new value
    And the client's name, email, address and notes are unchanged

  Scenario: Removing a client removes their dogs too
    Given the walker has a client "Alice Ahmed" with a dog "Biscuit"
    When the client is removed via deleteClient
    Then the response status is 204
    And fetching the client via getClient returns 404
    And fetching the dog via getDog returns 404

  Scenario: Fetching an unknown client returns 404
    When an unknown client_id is fetched via getClient
    Then the response status is 404
    And the problem body carries an error_code and message

  Scenario: Another walker's client is not visible
    Given the walker "walker-omar" has a client "Priya Patel"
    When the walker "walker-anna" fetches that client_id via getClient
    Then the response status is 404
    And the walker "walker-anna" does not see "Priya Patel" via listClients

  Scenario: A request without a session token is rejected
    When the roster is listed via listClients without a bearer_auth token
    Then the response status is 401
    And the problem body carries an error_code and message

  Scenario Outline: A client must have a usable name and email
    When the walker adds a client with <problem> via createClient
    Then the response status is 400
    And the problem body carries an error_code and message

    Examples:
      | problem                             |
      | a blank name                        |
      | an email that is not an email address |
