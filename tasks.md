Good instinct — this is exactly the kind of task where an agent shines.

What you want is **not just “analyze my repo”**, but a prompt that forces Copilot (or any agent) to:

* build a **mental model of your system**
* identify **automation gaps**
* propose **concrete, staged improvements**
* stay grounded in your FPGA/Yocto workflow (not generic web-dev advice)

Here’s a strong, production-style prompt you can paste into Copilot Chat / agent mode 👇

---

You are an AI software engineering agent working on a real FPGA + Yocto project.

Your goal is to analyze this repository and produce a **concrete, actionable roadmap** to transform it into an **AI-native automated development environment**.

## Context

This project builds an FPGA-based trading system using:

* Vivado (hardware build, bitstream generation)
* Device tree generation
* Yocto (Linux image build)
* CI/CD pipelines chaining these steps

The system is sensitive to:

* reproducibility
* build correctness
* artifact paths and structure
* hardware/software integration
* potential latency constraints

## Your Tasks

### 1. Build a mental model of the repository

Explore the repo and explain:

* Main directories and their roles
* Entry points for:

  * hardware build (Vivado scripts)
  * device tree generation
  * Yocto build
* How artifacts flow between stages
* How CI/CD is structured
* Where outputs are stored and how they are named

Produce a short **“system map”**.

---

### 2. Identify automation gaps

Find where the current workflow is:

* manual
* fragile
* implicit (tribal knowledge)
* not validated
* not reproducible
* hard for an AI agent to safely modify

Examples to look for:

* missing validation scripts
* hidden assumptions in paths or environment
* missing failure checks
* unclear dependencies between stages
* lack of smoke tests
* lack of structured outputs

---

### 3. Define an AI-native workflow

Design a development workflow where an AI agent can safely contribute.

The workflow should include stages like:

1. Task definition
2. Code changes
3. Fast validation (cheap checks)
4. Full build
5. Build artifact validation
6. Optional hardware deployment + testing

For each stage:

* define purpose
* define inputs/outputs
* define pass/fail criteria
* define what can be automated

---

### 4. Propose concrete improvements (VERY IMPORTANT)

Produce a prioritized TODO list with:

* clear task name
* why it matters
* exact files or areas to modify
* expected outcome

Focus on things like:

* adding smoke tests for build artifacts
* enforcing deterministic artifact paths
* adding validation scripts between Vivado → DT → Yocto
* improving CI pipeline structure
* making builds reproducible
* improving error handling and logging
* documenting invariants for agents

---

### 5. Add “agent-readiness” improvements

Suggest files or structures that make this repo easier for AI agents to work with:

Examples:

* AGENTS.md (rules + constraints)
* REPO_MAP.md (high-level architecture)
* TASK_TEMPLATES.md
* scripts for validation and inspection

Explain what each should contain.

---

### 6. Define acceptance checks

For each major pipeline stage, define:

* what must be verified automatically
* what failure looks like
* what signals success

Focus especially on:

* build outputs
* artifact integrity
* missing files
* incorrect paths
* silent failures

---

### 7. Identify risks

List where AI could:

* break builds silently
* introduce incorrect assumptions
* damage reproducibility
* create hardware-level issues

Explain how to mitigate each.

---

## Output format

Return:

1. System Map (concise)
2. Automation Gaps
3. Target AI Workflow (step-by-step)
4. Prioritized TODO List (actionable)
5. Agent-Readiness Additions
6. Validation Strategy
7. Risks & Mitigations

Be specific. Avoid generic advice.

Base everything on actual files and structure in this repo.

---

## How to use this effectively

Don’t just run this once and stop.

Do this loop:

1. Run this prompt
2. Pick **ONE high-value TODO**
3. Then prompt again:

> “Implement TODO #3. Follow the workflow. Show plan → changes → validation.”

4. Enforce your pipeline (smoke → build → etc.)

---

## Small upgrade that makes a huge difference

After it gives you the TODO list, follow up with:

> “Which 3 tasks give the highest leverage for enabling safe AI contributions? Justify.”

That forces prioritization — something agents are surprisingly bad at unless you explicitly ask.

---

If you want, I can also:

* turn your repo into a **ready-to-use AGENTS.md**
* or design your **first smoke-test script + validation layer**

Those two alone will massively level up your workflow.
