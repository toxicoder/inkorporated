---
title: Engineering Bootcamp
description: Engineering Bootcamp for Inkorporated.
tags: [enterprise]
---

## Engineering Bootcamp

Welcome, Engineer! This guide will help you set up your development environment
and ship your first code.

### 1. Workstation Setup

We use a standard set of tools to ensure consistency.

#### Hardware

* **Laptop**: MacBook Pro (M1/M2/M3) or Dell XPS (Linux).
* **Monitor**: 27" 4K Monitor (provided).
* **Peripherals**: Keyboard, Mouse, Noise-canceling headphones.

#### Software

1. **Package Manager**:
    * macOS: Install [Homebrew](https://brew.sh/).
    * Linux: Ensure `apt` or your distro's manager is updated.
2. **IDE**:
    * We recommend **VS Code** or **IntelliJ IDEA**.
    * Install recommended extensions:
        * Prettier / ESLint (Frontend)
        * Python / Pylance (Backend)
        * Go / Rust extensions (as needed)
3. **Terminal**:
    * Use `iTerm2` (macOS) or standard terminal.
    * Setup `zsh` and `oh-my-zsh` for a better shell experience.

### 2. Repositories

* Clone the main repository: `git clone https://github.com/toxicoder/devset.git`
* Follow the README.md in the root for project-specific setup.

### 3. Style Guides

Before writing code, please review our style guides to ensure your code matches
our standards:

* [**General Coding Standards**](../style_guides/index.md)
* [**Python**](../style_guides/python/python_style_guide.md)
* [**TypeScript**](../style_guides/typescript/typescript_style_guide.md)
* [**Go**](../style_guides/golang/golang_style_guide.md)

### 4. Access & Permissions

You will need access to the following systems. Request access via the
[Tools and Access](tools_and_access.md) page if you don't have it.

* **GitHub Organization**: `@toxicoder`
* **Jira**: For ticket tracking.
* **Confluence/Notion**: For documentation.
* **AWS/GCP/Azure**: Cloud console access (read-only initially).
* **CI/CD**: CircleCI / GitHub Actions / Jenkins.

### 5. Your First Pull Request (PR)

Let's get you shipping code on Day 1 or 2!

1. **Find a Task**: Look for issues tagged `good first issue` in Jira or GitHub.
2. **Branch**: Create a new branch: `git checkout -b username/fix-something`.
3. **Code**: Make your changes.
4. **Test**: Run local tests (e.g., `npm test`, `pytest`).
5. **Commit**: Write a descriptive commit message.
6. **Push**: `git push origin username/fix-something`.
7. **Open PR**: Create a Pull Request against `main`.
    * Fill out the PR template.
    * Tag your buddy for review.
8. **Merge**: Once approved and CI passes, merge your code!

### 6. Troubleshooting

* **Internal Wiki**: Search for error messages in our knowledge base.
* **Slack**: Ask in `#eng-help` or `#dev-tools`.
* **Stack Overflow**: The classic.

Happy Coding!
