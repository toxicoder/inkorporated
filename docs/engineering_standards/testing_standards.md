---
title: Testing Standards
description: Testing Standards for Inkorporated.
tags: [enterprise]
---

Reliable software depends on a robust testing strategy. We follow the "Testing
Pyramid" approach to ensure high quality and fast feedback loops.

## The Testing Pyramid

### 1. Unit Tests (Base)

* **Scope:** Test individual functions, classes, or components in isolation.
* **Speed:** Extremely fast (milliseconds).
* **Volume:** Largest number of tests.
* **Responsibility:** Developers must write unit tests for all new code. Target
  >80% code coverage.
* **Tools:** Jest (JS/TS), Pytest (Python), JUnit (Java), Go Test (Golang).

### 2. Integration Tests (Middle)

* **Scope:** Test interactions between different modules or services (e.g., API
  to Database, Service A to Service B).
* **Speed:** Slower than unit tests but faster than E2E.
* **Volume:** Moderate number of tests.
* **Responsibility:** Validate that components work together correctly. Use
  mocks/stubs for external dependencies where appropriate, but prefer real
  dependencies (e.g., test containers) for critical paths.

### 3. End-to-End (E2E) Tests (Top)

* **Scope:** Test the entire application flow from the user's perspective.
* **Speed:** Slowest.
* **Volume:** Smallest number of tests. focus on critical user journeys (e.g.,
  "Sign Up", "Checkout").
* **Responsibility:** Ensure the system works as a whole.
* **Tools:** Playwright, Cypress, Selenium.

## Best Practices

* **Test-Driven Development (TDD):** Encouraged. Write the test *before* the
  code to clarify requirements and design.
* **CI Integration:** All tests must pass in CI before merging. A broken build
  is a top priority to fix.
* **Flaky Tests:** Flaky tests (tests that pass/fail randomly) destroy trust.
  Quarantine or fix flaky tests immediately.
* **Mocking:** Use mocking for external systems (3rd party APIs) to ensure tests
  are deterministic. Avoid excessive mocking of internal code, as it can hide
  integration bugs.
* **Test Data:** Use factories or fixtures to generate test data. Avoid relying
  on shared static data that can be mutated by other tests.

## Language-Specific Guidelines

Refer to the [Style Guides](../style_guides/index.md) for specific testing conventions in
each language.
