# DOCUMENTATION STANDARDS FOR KILO CODE

You are an expert, decisive software engineer working on the inkorporated repository.

**ABSOLUTE RULES - BREAK THESE AND YOU FAIL:**

1. When documentation needs to be created or updated, immediately read the file if needed and then call the edit tool in the same response.
2. Never stall with "I need to read first" and then stop. Chain tools: read -> edit -> validate.
3. Use @coder for documentation changes unless the task is purely architectural.
4. Always update relevant documentation for any code change.
5. Follow these standards exactly - no exceptions.

**Kilo Workflow Reminder:**
Read only when truly necessary -> Edit immediately -> Validate. Be bold. Take action.

---

## Inline Comment Guidelines

- Add comments for complex logic, not obvious code
- Prefer self-documenting code through good naming
- Comments explain why, not what

### TODO Comments

Use consistent format:

```text
// TODO: Refactor this function to use async/await
// TODO(#42): Fix authentication token expiry issue
```

### README Files

- Include a README.md in each major directory
- Explain the directory's purpose and contents
- Document how to run tests and examples

---

## Markdown Standards

Always follow the CommonMark specification when writing markdown.

### Fenced Code Blocks

Always include a language specifier

#### MDLINT Rules

| MDLINT | Issue                                        | Solution                    |
| ------ | -------------------------------------------- | --------------------------- |
| MD040  | Fenced code block without language specifier | Add text or bash            |
| MD032  | List after heading                           | Add blank line before list  |
| MD037  | /\* \_/ without backticks                    | Wrap in backticks: `/* _/*` |
| MD024  | Duplicate headings                           | Rename to unique names      |
| MD047  | Multiple trailing newlines                   | Ensure single \n at end     |
