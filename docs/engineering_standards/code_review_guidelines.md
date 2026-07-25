---
title: Code Review Guidelines
description: Code Review Guidelines for Inkorporated.
tags: [enterprise]
---

Code review is a critical part of our engineering culture. It ensures code
quality, knowledge sharing, and collective ownership of the codebase.

## For Authors

### 1. Small, Atomic Changes

Keep pull requests (PRs) small and focused on a single logical change. Small PRs
are easier to review, less risky, and faster to merge. Ideally, a PR should be
reviewable in under 15 minutes.

### 2. Context is Key

Provide a clear description of *what* changed and *why*. Link to relevant
tickets, design docs, or issues. Include screenshots or GIFs for UI changes.

### 3. Self-Review

Before assigning reviewers, review your own code. Check for linting errors,
commented-out code, and ensure that your changes match your intent. Run tests
locally.

### 4. Respond to Feedback

Be open to feedback. If you disagree with a comment, explain your reasoning
clearly and respectfully. Resolve all comments before merging.

## For Reviewers

### 1. Review for Correctness and Quality

Check that the code solves the problem it claims to solve. Look for bugs, edge
cases, and potential performance issues. Ensure the code follows our style
guides and engineering principles.

### 2. Be Respectful and Constructive

Focus on the code, not the person. Use "we" instead of "you" (e.g., "Can we
make this clearer?" instead of "You made this confusing"). Offer suggestions for
improvement, not just criticism.

### 3. Respond Quickly

Code review shouldn't block progress. Aim to review PRs within 24 hours. If you
can't review it in time, communicate that to the author.

### 4. Approve with Confidence

When you approve a PR, you are vouching for its quality. Don't rubber-stamp
changes. If you don't understand something, ask questions.

## Best Practices

* **Nitpicks:** Label minor comments as "nit" (nitpick) so the author knows
  they are optional or low priority.
* **Blocking:** Only block a PR for major issues (bugs, security flaws,
  architectural violations).
* **Praise:** Don't forget to praise good code! A simple "Nice solution!" goes
  a long way.
