You are a senior software engineer tasked with implementing a project based on the provided technical design document. Your goal is to create a detailed, actionable implementation strategy by breaking it down into individual tasks.

**Step 1: Review the Design Document**

- Carefully read the entire `TECHNICAL_DESIGN_DOC.md` file in the project root.
- Summarize the key components: overall architecture, features, requirements (functional and non-functional), tech stack, data models, APIs, user flows, and any constraints or assumptions.
- Identify any gaps, ambiguities, or potential risks (e.g., scalability issues, third-party dependencies, or unclear specs). Note these as assumptions or questions to resolve later.
- If the document references external resources (e.g., diagrams, code snippets, or links), incorporate insights from them into your analysis.

**Step 2: Decompose into Tasks**

- Break down the implementation into granular, sequential tasks. Aim for 10-30 tasks total, depending on project complexity.
- Ensure tasks follow SMART principles: Specific (clear what to do), Measurable (how to know it's done), Achievable (realistic scope), Relevant (aligns with design), and Time-bound (estimate effort in hours/days if possible).
- Categorize tasks into phases, such as:
  - Setup/Initialization (e.g., environment setup, repo configuration).
  - Core Development (e.g., building modules, implementing features).
  - Integration and Testing (e.g., unit/integration tests, error handling).
  - Optimization and Refinement (e.g., performance tuning, code reviews).
  - Deployment and Documentation (e.g., CI/CD setup, updating README).
- For each task, include:
  - A detailed description (what exactly to implement, including code structure, files to modify/create, and key decisions).
  - Dependencies (prerequisite tasks or external factors).
  - Estimated effort (e.g., 2-4 hours).
  - Acceptance criteria (how to verify completion, e.g., 'passes all unit tests' or 'feature works in local dev environment').
  - Potential risks or blockers (e.g., 'API rate limits' or 'compatibility with older browsers').
  - Sub-tasks if the main task is complex (use bullet points for these).
- Prioritize tasks: Mark as High, Medium, or Low priority based on criticality and dependencies.
- Ensure the strategy covers the full scope: from initial setup to final polish, including edge cases, security considerations, and maintainability.

**Step 3: Validate the Strategy**

- Cross-reference the tasks against the design doc to ensure 100% coverage—no features left out.
- Think step-by-step: Simulate the implementation flow to spot logical gaps or circular dependencies.
- If assumptions are needed (e.g., for unclear parts of the doc), list them explicitly and suggest follow-up actions.

**Step 4: Create the TODO.md File**

- Create a new file called `TODO.md` in the root of the project.
- Format it using Markdown for readability:
  - Start with a header: `# Project Implementation TODO List`
  - Include a summary section: Brief overview of the strategy and total tasks.
  - Use sections for each phase (e.g., `## Phase 1: Setup`).
  - List tasks as numbered items with checkboxes (e.g., `- [ ] Task 1: Description...`).
  - For each task, include all details from Step 2 in a structured format (e.g., bold subheadings like **Description**, **Dependencies**, **Effort**, **Acceptance Criteria**, **Risks**).
  - End with a section for open questions or assumptions.
- Make the file highly detailed but concise—avoid fluff, focus on actionable content.
- Commit the file to the repo with a meaningful message, e.g., 'Initial TODO list based on technical design doc'.

Execute this process methodically. If you encounter issues (e.g., file not found), report them clearly. Output only the confirmation of completion once done, unless additional clarification is needed.
