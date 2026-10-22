Feature: Managing dogs
  As a dog walker
  I want to record each client's dogs
  So that I can schedule walks for the right dogs and remember what each one needs

  These scenarios are acceptance criteria, not suggestions. An
  implementation that fails any of them is wrong. If a scenario is
  itself wrong, that is a versioned change to this file.

  Background:
    Given the walker "walker-anna" is signed in
    And the walker has a client "Alice Ahmed"

  Scenario: A dog is added to a client
    When the walker adds a dog named "Biscuit" for that client_id via createDog
    Then the response status is 201
    And the dog carries a dog_id, the client_id, the name, and created_at
    And the dog's breed, date_of_birth and notes are the ones given

  Scenario: A dog can be fetched by its id
    Given the client has a dog "Biscuit"
    When the dog is fetched by dog_id via getDog
    Then the response status is 200
    And the dog carries the dog_id, client_id, name, breed, date_of_birth, notes and created_at

  Scenario: All of the walker's dogs are listed
    Given the client has a dog "Biscuit"
    And the walker has a client "Ben Brooks" with a dog "Rex"
    When the dogs are listed via listDogs
    Then the response status is 200
    And the dogs list carries "Biscuit" and "Rex"

  Scenario: The dogs of one client are listed
    Given the client has a dog "Biscuit"
    And the walker has a client "Ben Brooks" with a dog "Rex"
    When the dogs are listed via listDogs filtered by that client_id
    Then the response status is 200
    And the dogs list carries "Biscuit" but not "Rex"

  Scenario: A dog's details are updated in place
    Given the client has a dog "Biscuit"
    When the dog's notes are changed via updateDog
    Then the response status is 200
    And the dog's notes are the new value
    And the dog's name, breed, date_of_birth and client_id are unchanged

  Scenario: A dog is removed
    Given the client has a dog "Biscuit"
    When the dog is removed via deleteDog
    Then the response status is 204
    And fetching the dog via getDog returns 404

  Scenario: A dog's optional details can be cleared
    Given the client has a dog "Biscuit"
    When the dog's date_of_birth is cleared with an empty string via updateDog
    Then the response status is 200
    And the dog carries no date_of_birth
    And the dog's name, breed, notes and client_id are unchanged

  Scenario: A dog with an open walk is not removed
    Given the client has a dog "Biscuit"
    And the walker has an open walk for "Biscuit"
    When the dog is removed via deleteDog
    Then the response status is 409
    And the problem body carries an error_code and message
    And fetching the dog via getDog returns 200

  Scenario: A dog whose walks are all closed can be removed
    Given the client has a dog "Biscuit"
    And the walker has a cancelled walk for "Biscuit"
    When the dog is removed via deleteDog
    Then the response status is 204

  Scenario: A dog born today in the walker's time zone can be added
    When the walker adds a dog for that client_id born on the date it already is in the furthest-ahead time zone via createDog
    Then the response status is 201

  Scenario: Fetching an unknown dog returns 404
    When an unknown dog_id is fetched via getDog
    Then the response status is 404
    And the problem body carries an error_code and message

  Scenario: Another walker's dog is not visible
    Given the walker "walker-omar" has a client "Priya Patel" with a dog "Mango"
    When the walker "walker-anna" fetches that dog_id via getDog
    Then the response status is 404
    And the walker "walker-anna" does not see "Mango" via listDogs

  Scenario Outline: A dog must have a usable name, birth date and owner
    When the walker adds a dog with <problem> via createDog
    Then the response status is 400
    And the problem body carries an error_code and message

    Examples:
      | problem                                        |
      | a blank name                                   |
      | a date_of_birth in the future                  |
      | a client_id that is not one of the walker's clients |
