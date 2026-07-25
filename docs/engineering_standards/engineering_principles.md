---
title: Engineering Principles
description: Engineering Principles for Inkorporated.
tags: [enterprise]
---

# Engineering Principles


**What's on this page**

- Core content for this topic in the Inkorporated enterprise OS.
- Practical guidance, roles, or standards as applicable.

**What this enables**

- Consistent enterprise operations and decision-making.
- Shared language for humans and cyborg AI agents.

These principles are the DNA of our engineering culture. They are not just words on a page; they are the heuristics we use to make difficult decisions, the standard by which we evaluate our work, and the shared language that binds our diverse teams together.

We draw inspiration from the best engineering organizations in the world, yet these principles are uniquely ours. They reflect who we are and who we aspire to be.

---

## 1. Customer Obsession

> **Start with the customer and work backwards.**

### Core Philosophy
Our existence depends on our customers. We are not here to build technology for technology's sake; we are here to solve real problems for real people. Leaders start with the customer and work backwards. They work vigorously to earn and keep customer trust. Although leaders pay attention to competitors, they obsess over customers.

### Why It Matters
*   **Relevance:** Building features that nobody uses is the ultimate waste of engineering resources.
*   **Trust:** Trust is hard to earn and easy to lose. Every interaction, every API call, and every pixel matters.
*   **Focus:** It acts as a razor to cut through distractions. If it doesn't help the customer, why are we doing it?

### Applying it in Engineering
*   **API Design:** Design APIs that are intuitive for the developer consuming them, not just convenient for the backend engineer building them.
*   **Latency:** Treat latency as a bug. A slow application disrespects the user's time.
*   **Observability:** Monitor what the customer experiences (SLIs), not just CPU usage. If the server is healthy but the customer sees a 500 error, the system is down.

### Applying it in Culture
*   **Empathy:** We listen to customer feedback, read support tickets, and jump on calls with users.
*   **Prioritization:** When faced with a choice between a cool refactor and a critical customer fix, the customer wins.

### Anti-Patterns
*   **"The customer doesn't know what they want."** (Arrogance)
*   **"That's a sales problem."** (Siloing)
*   **Building features based on what competitors are doing rather than what customers need.**

### Concrete Example
*   *Scenario:* A database migration is required.
*   *Bad:* Taking the site down for 4 hours on a Tuesday because it's easier for the engineering team.
*   *Good:* Investing two weeks in a dual-write migration strategy to ensure zero downtime for the customer, even though it's much harder to implement.

---

## 2. Ownership

> **Leaders are owners. They think long term and don't sacrifice long-term value for short-term results.**

### Core Philosophy
There is no such thing as "someone else's code" or "someone else's problem." We act on behalf of the entire company, beyond just our own team. We never say "that's not my job."

### Why It Matters
*   **Quality:** When you own something, you care for it. Rental cars are treated differently than personal cars.
*   **Speed:** Ownership eliminates the "bystander effect." When an issue arises, owners jump in to fix it.
*   **Growth:** Taking ownership is the fastest way to learn and grow your career.

### Applying it in Engineering
*   **"You Build It, You Run It":** Teams are responsible for the operation of their services in production.
*   **Root Cause Analysis:** When things break, we don't blame; we investigate. We fix the systemic issue so it doesn't happen again.
*   **Tech Debt:** Owners pay their debts. We proactively manage technical debt before it bankrupts us.

### Applying it in Culture
*   **Janitorial Work:** Senior engineers are not above fixing typos, updating documentation, or cleaning up dead code.
*   **Proactivity:** If you see a piece of trash on the floor (or a bug in the code), you pick it up.

### Anti-Patterns
*   **"It worked on my machine."**
*   **"I threw it over the wall to QA."**
*   **Optimizing for a specific team's metrics at the expense of the company's success.**

### Concrete Example
*   *Scenario:* You notice a flaky test in a repository you don't usually work in.
*   *Bad:* Re-running the build until it passes and ignoring the flakiness.
*   *Good:* Investigating the flake, fixing it, or at least filing a detailed ticket and disabling the test to keep the build green for everyone else.

---

## 3. Move Fast and Fix Things

> **Speed is a competitive advantage in business.**

### Core Philosophy
We value calculated risk-taking. Many decisions and actions are reversible and do not need extensive study. We value business delivery over architectural perfection. However, "Move Fast" does not mean "Move Recklessly." When we break things, we fix them immediately.

### Why It Matters
*   **Learning:** The faster we ship, the faster we learn what works.
*   **Market:** The market doesn't wait for perfect code.
*   **Momentum:** High velocity creates high morale.

### Applying it in Engineering
*   **CI/CD:** We invest heavily in automated testing and deployment pipelines to make shipping code safe and fast.
*   **Feature Flags:** We decouple deployment from release, allowing us to merge code constantly without breaking users.
*   **MVP:** We build the Minimum Viable Product, ship it, and iterate.

### Applying it in Culture
*   **Bias for Action:** We prefer action over analysis paralysis.
*   **Psychological Safety:** It's okay to fail as long as we learn and recover quickly.

### Anti-Patterns
*   **Analysis Paralysis:** Spending weeks debating a decision that can be reversed in an hour.
*   **Cowboy Coding:** Pushing changes to production without review or testing.
*   **Leaving broken windows:** Ignoring broken builds or failing tests.

### Concrete Example
*   *Scenario:* A new feature has high uncertainty.
*   *Bad:* Spending 3 months architecting a perfect, scalable solution.
*   *Good:* Spending 1 week building a "throwaway" prototype to test the market hypothesis, then rebuilding it properly if it succeeds.

---

## 4. Operational Excellence

> **Reliability is our number one feature.**

### Core Philosophy
We have a relentless focus on the health of our systems. We are never satisfied with the status quo. We look for defects and inefficiencies and we fix them. We operate with a "Safety 2" mindset—we don't just ask why things went wrong, we ask how things usually go right.

### Why It Matters
*   **Trust:** Customers cannot trust a system that is down.
*   **Efficiency:** Stable systems require less firefighting, freeing up time for innovation.
*   **Sleep:** We want our engineers to sleep through the night.

### Applying it in Engineering
*   **Observability:** We instrument everything. Logs, metrics, traces. If you can't measure it, you can't manage it.
*   **Chaos Engineering:** We proactively break our systems to ensure they can recover.
*   **Capacity Planning:** We anticipate growth and scale our systems before they fall over.

### Applying it in Culture
*   **Blameless Post-Mortems:** We focus on process failures, not human errors.
*   **Game Days:** We practice incident response regularly.

### Anti-Patterns
*   **Hope-driven operations:** "It should be fine."
*   **Alert Fatigue:** Ignoring alerts because "they always fire."
*   **Manual Runbooks:** Relying on human memory during a crisis.

### Concrete Example
*   *Scenario:* A service hits 90% CPU utilization.
*   *Bad:* Manually logging in to add more servers.
*   *Good:* An autoscaling group automatically detects the load and provisions new instances. An alert is sent to a Slack channel for awareness, but no human intervention is required.

---

## 5. Simplicity Over Complexity

> **Complexity is the enemy of reliability.**

### Core Philosophy
Simple systems are easier to understand, easier to maintain, and harder to break. We strive for essential complexity (the problem itself) and ruthlessly eliminate accidental complexity (the mess we create).

### Why It Matters
*   **Cognitive Load:** Engineers can only hold so much context in their heads. Simple code fits in the brain.
*   **Bugs:** Complexity hides bugs. Simplicity exposes them.
*   **Onboarding:** New engineers can contribute faster to simple codebases.

### Applying it in Engineering
*   **YAGNI (You Ain't Gonna Need It):** Don't build for hypothetical future use cases.
*   **KISS (Keep It Simple, Stupid):** The most clever solution is usually the wrong one.
*   **Refactoring:** We aggressively delete dead code and simplify complex logic.

### Applying it in Culture
*   **Communication:** We write clear, concise documents. We avoid jargon.
*   **Process:** We keep our processes lightweight. If a meeting doesn't add value, we cancel it.

### Anti-Patterns
*   **Resume Driven Development:** Choosing a technology because it looks good on a resume, not because it's the right tool for the job.
*   **Premature Optimization:** Optimizing code that isn't a bottleneck.
*   **The "Not Invented Here" Syndrome:** Building a custom solution when a standard library exists.

### Concrete Example
*   *Scenario:* Need to implement a queue.
*   *Bad:* Writing a custom distributed queue system in C++ because it's "faster."
*   *Good:* Using SQS, RabbitMQ, or Redis.

---

## 6. Disagree and Commit

> **Have a backbone; disagree and commit.**

### Core Philosophy
Leaders are obligated to respectfully challenge decisions when they disagree, even when doing so is uncomfortable or exhausting. Leaders have conviction and are tenacious. They do not compromise for the sake of social cohesion. Once a decision is determined, they commit wholly.

### Why It Matters
*   **Groupthink:** Without dissent, teams make mediocre decisions.
*   **Alignment:** Once we commit, we move as one force. Partial commitment leads to sabotage.
*   **Clarity:** Arguments clarify the problem space.

### Applying it in Engineering
*   **Code Reviews:** We critique the code, not the person. We push back on design flaws.
*   **RFCs:** We write Request for Comments documents to solicit feedback before writing code.

### Applying it in Culture
*   **Respect:** We listen to understand, not just to respond.
*   **Hierarchy:** The best idea wins, regardless of who proposed it. A junior engineer can challenge a VP (respectfully).

### Anti-Patterns
*   **Silent Disagreement:** Nodding in the meeting but complaining at the water cooler.
*   **Pocket Veto:** Agreeing to a task but then deprioritizing it into oblivion.
*   **"Design by Committee":** Trying to please everyone and ending up with a solution that pleases no one.

### Concrete Example
*   *Scenario:* The team is debating between React and Vue.
*   *Bad:* Half the team uses React, the other half uses Vue, resulting in a fractured codebase.
*   *Good:* The team debates vigorously. The lead decides on React. The Vue advocates switch gears and become React experts to ensure the project's success.

---

## 7. Automate Everything

> **If you have to do it twice, automate it.**

### Core Philosophy
Toil is the kind of work that tends to be manual, repetitive, automatable, tactical, devoid of enduring value, and that scales linearly as a service grows. We hate toil. We automate it away.

### Why It Matters
*   **Scale:** You cannot hire your way out of operational scaling problems.
*   **Consistency:** Humans make mistakes. Scripts do not.
*   **Happiness:** Engineers are happier solving novel problems, not copy-pasting CSVs.

### Applying it in Engineering
*   **Infrastructure as Code (IaC):** We treat infrastructure (Terraform, Ansible) like software.
*   **Test Automation:** Manual regression testing is forbidden.
*   **Self-Healing:** Systems should detect failures and recover automatically.

### Applying it in Culture
*   **Self-Service:** We build platforms that allow other teams to serve themselves, rather than filing tickets for us to do work for them.

### Anti-Patterns
*   **"Job Security":** Hoarding knowledge and manual processes so you are indispensable.
*   **"It's faster to do it manually just this once."** (Repeated 100 times).

### Concrete Example
*   *Scenario:* Onboarding a new engineer.
*   *Bad:* A 20-page wiki doc of manual steps to set up the dev environment.
*   *Good:* A single `make setup` script that installs dependencies, configures DBs, and seeds data.

---

## 8. Security First

> **Security is everyone's responsibility.**

### Core Philosophy
Security is not a feature you add at the end; it is a fundamental constraint. We design for security from the ground up. We protect our customer's data as if it were our own.

### Why It Matters
*   **Survival:** A major breach can destroy the company.
*   **Trust:** Customers trust us with their most sensitive data.
*   **Compliance:** We operate in a regulated world.

### Applying it in Engineering
*   **Least Privilege:** Services and users only have the permissions they strictly need.
*   **Defense in Depth:** We don't rely on a single firewall. We layer defenses.
*   **Shift Left:** We scan for vulnerabilities in the PR, not just in production.

### Applying it in Culture
*   **Transparency:** If we make a mistake, we disclose it responsibly.
*   **Education:** We constantly train on the latest threats (phishing, social engineering).

### Anti-Patterns
*   **Hardcoded Credentials:** Committing secrets to git.
*   **"Security Team's Problem":** Ignoring security warnings until the security audit.
*   **Security via Obscurity:** Hoping attackers won't find the vulnerability.

### Concrete Example
*   *Scenario:* Implementing a new API endpoint.
*   *Bad:* Relying on the frontend to hide the button for unauthorized users.
*   *Good:* Enforcing strict Role-Based Access Control (RBAC) at the API gateway and service level.

---

## 9. Data-Driven Decisions

> **In God we trust; all others must bring data.**

### Core Philosophy
We rely on evidence, not opinions. When we make a claim, we back it up with metrics. We define success criteria before we start.

### Why It Matters
*   **Objectivity:** Data cuts through politics and hierarchy.
*   **Improvement:** You cannot improve what you do not measure.
*   **Reality:** Intuition is often wrong. Data reveals the truth.

### Applying it in Engineering
*   **A/B Testing:** We test changes on a subset of users to measure impact.
*   **Performance Profiling:** We don't guess where the bottleneck is; we use a profiler.
*   **Capacity Modeling:** We use historical data to predict future resource needs.

### Applying it in Culture
*   **Metrics Reviews:** We regularly review our KPIs (Key Performance Indicators).
*   **Intellectual Honesty:** If the data contradicts our hypothesis, we change our hypothesis.

### Anti-Patterns
*   **Vanity Metrics:** Measuring "Total Registered Users" (which always goes up) instead of "Daily Active Users" (which shows health).
*   **Cherry-picking:** Selecting only the data that supports your argument.
*   **HiPPO (Highest Paid Person's Opinion):** Letting the boss's gut feeling override the data.

### Concrete Example
*   *Scenario:* A debate about whether a new UI design is better.
*   *Bad:* The designer and PM arguing for hours about aesthetics.
*   *Good:* Running an A/B test and seeing that the new design increases conversion by 5%.

---

## 10. Learn and Be Curious

> **Leaders are never done learning and always seek to improve themselves.**

### Core Philosophy
Technology changes fast. What was best practice yesterday is legacy today. We are lifelong learners. We are curious about how things work. We explore new possibilities.

### Why It Matters
*   **Innovation:** Curiosity drives innovation.
*   **Adaptability:** The ability to learn is the only sustainable competitive advantage.
*   **Engagement:** Learning is fun.

### Applying it in Engineering
*   **Tech Talks:** We share knowledge through internal presentations.
*   **Post-Mortems:** We treat outages as learning opportunities.
*   **Experimentation:** We set aside time to play with new technologies.

### Applying it in Culture
*   **Questions:** We encourage asking "why?"
*   **Hiring:** We hire for potential and aptitude, not just specific skill sets.

### Anti-Patterns
*   **Complacency:** "We've always done it this way."
*   **Gatekeeping:** Hoarding knowledge to feel superior.

### Concrete Example
*   *Scenario:* A new language (e.g., Rust) is gaining popularity.
*   *Bad:* Ignoring it because "Java is fine."
*   *Good:* Forming a study group to evaluate its potential benefits for our high-performance services.

---

## 11. Bias for Action

> **Speed matters in business.**

### Core Philosophy
Many decisions and actions are reversible and do not need extensive study. We value calculated risk taking.

### Why It Matters
*   **Opportunity Cost:** The cost of delay is often higher than the cost of a mistake.
*   **Feedback:** You learn nothing until you ship.

### Applying it in Engineering
*   **One-way vs Two-way Doors:** Distinguish between reversible decisions (two-way doors) and irreversible ones (one-way doors). Walk through two-way doors quickly.
*   **Incremental Delivery:** Ship small chunks of value frequently.

### Anti-Patterns
*   **Bureaucracy:** Requiring 5 approvals to change a CSS color.
*   **Fear:** Being afraid to make a mistake.

### Concrete Example
*   *Scenario:* A customer reports a minor bug.
*   *Bad:* Scheduling a meeting to discuss the prioritization of the bug for next quarter.
*   *Good:* A developer fixes it, tests it, and deploys it within the hour.

---

## 12. Frugality

> **Accomplish more with less.**

### Core Philosophy
Constraints breed resourcefulness, self-sufficiency, and invention. There are no extra points for growing headcount, budget size, or fixed expense.

### Why It Matters
*   **Sustainability:** Efficient companies survive.
*   **Focus:** Having too many resources leads to waste and lack of focus.
*   **Creativity:** Limitations force us to think outside the box.

### Applying it in Engineering
*   **Resource Efficiency:** Writing efficient code that saves compute costs.
*   **Tooling:** Using open-source solutions where appropriate instead of expensive enterprise software.

### Anti-Patterns
*   **Over-provisioning:** Running large instances when small ones would do.
*   **"Use it or lose it":** Spending budget just because it's there.

### Concrete Example
*   *Scenario:* Logs are costing too much to store.
*   *Bad:* Asking for more budget.
*   *Good:* optimizing log formats, setting retention policies, and filtering out noise to reduce volume by 50%.
