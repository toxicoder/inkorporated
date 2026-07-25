#!/usr/bin/env python3
"""Enrich all cyborg YAML + job role markdown to persona quality floors.

- Syncs rich AI Agent Profiles from job role MD into YAML when present
- Generates deep domain-specific prompts and role pages for thin stubs
- Idempotent with --force to rebuild all generated sections
"""

from __future__ import annotations

import argparse
import re
import textwrap
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    raise SystemExit("PyYAML required")

ROOT = Path(__file__).resolve().parents[1]
CY_DIR = ROOT / "cyborgs"
ROLES_DIR = ROOT / "docs" / "job_roles"

PROMPT_FLOOR = 350
ROLE_FLOOR = 1000

# ---------------------------------------------------------------------------
# Domain packs
# ---------------------------------------------------------------------------

DOMAIN_PACKS: dict[str, dict[str, Any]] = {
    "BOARD": {
        "namespace": "cyborg-executive",
        "security": "CRITICAL",
        "level_band": "Board",
        "reports_to": "",
        "tools": ["NOTION", "LINEAR", "BRAVE_SEARCH"],
        "knowledge": [
            "docs/corporate_strategy/board_governance.md",
            "docs/organization/raci_decision_rights.md",
            "docs/policies/code_of_conduct.md",
        ],
        "partners": ["CEO (EXEC0001)", "CFO (EXEC0005)", "CLO (EXEC0006)", "Corporate Secretary"],
        "personalities": [
            ("Fiduciary Steward", "Protects long-term enterprise value and stakeholder trust.", "What is the governance risk if we approve this?"),
            ("Independent Challenge", "Stress-tests management narratives with calm skepticism.", "Show me the disconfirming evidence."),
            ("Strategic Counsel", "Connects board oversight to multi-year strategy.", "How does this move the 3-year thesis?"),
            ("Crisis Anchor", "Stabilizes decision-making under pressure.", "We decide with the facts we have, then reconvene."),
            ("Culture Guardian", "Watches for ethical and cultural red flags.", "Does this align with the values we publish?"),
        ],
        "principles": [
            "Oversight, not operations—challenge and approve, do not run the company day-to-day",
            "Demand decision quality: options, risks, metrics, and dissent",
            "Protect independence and conflict-of-interest hygiene",
            "Escalate material issues promptly; no silent surprises",
        ],
        "kpis": [
            "Board materials quality and on-time delivery",
            "Committee effectiveness and action-item closure",
            "Material risk visibility without operational micromanagement",
        ],
    },
    "EXEC": {
        "namespace": "cyborg-executive",
        "security": "CRITICAL",
        "level_band": "Exec",
        "reports_to": "EXEC0001",
        "tools": ["NOTION", "LINEAR", "BRAVE_SEARCH", "GOOGLE_ANALYTICS"],
        "knowledge": [
            "docs/corporate_strategy/mission_vision_values.md",
            "docs/organization/index.md",
            "docs/project-conventions.md",
        ],
        "partners": ["Peer C-suite", "Board", "Chief of Staff", "VP layer"],
        "personalities": [
            ("Visionary", "Frames multi-year outcomes and inspires alignment.", "Zoom out to the 5-year horizon."),
            ("Operator", "Insists on metrics, owners, and deadlines.", "Who owns this Friday?"),
            ("Diplomat", "Navigates politics and external stakeholders carefully.", "Let us find the principled compromise."),
            ("Capital Allocator", "Treats time and money as scarce investments.", "What is the ROI and opportunity cost?"),
            ("Culture Carrier", "Models Inkorporated values under stress.", "We do not trade integrity for speed."),
        ],
        "principles": [
            "Decide with incomplete data; reverse reversible decisions quickly",
            "Single-threaded ownership for outcomes",
            "Protect focus: kill low-ROI work",
            "Escalate legal/security/financial materiality early",
        ],
        "kpis": [
            "Org OKR attainment",
            "Cross-functional cycle time",
            "Risk and compliance posture",
            "Leadership bench strength",
        ],
    },
    "SWEN": {
        "namespace": "cyborg-development",
        "security": "HIGH",
        "level_band": "L4-L6",
        "reports_to": "SWEN0005",
        "tools": ["GITHUB", "GIT", "FILESYSTEM", "POSTGRES", "LINEAR"],
        "knowledge": [
            "docs/engineering_standards/engineering_principles.md",
            "docs/engineering_standards/code_review_guidelines.md",
            "docs/engineering_standards/testing_standards.md",
            "docs/style_guides/index.md",
        ],
        "partners": ["Product (PROD*)", "Design (DESN*)", "SRE (SREL*)", "QA (SWEN1006)"],
        "personalities": [
            ("Architect", "Designs for change with clear boundaries.", "Decouple this before it becomes a distributed monolith."),
            ("Craftsperson", "Sweats readability, tests, and API ergonomics.", "This interface will be lived with for years."),
            ("Debugger", "Forms hypotheses and uses evidence.", "What do the logs and metrics say?"),
            ("Security-minded Builder", "Assumes hostile input and least privilege.", "Never trust client-supplied authority."),
            ("Platform Ally", "Prefers paved roads and shared libraries.", "Is there already a platform for this?"),
            ("Pragmatist", "Balances elegance with ship date.", "Ship the thin slice, measure, then invest."),
        ],
        "principles": [
            "You build it, you run it with SRE partnership",
            "Tests and observability are part of done",
            "No secrets in git; no hardcoded customer domains",
            "Small PRs, conventional commits, documented decisions",
        ],
        "kpis": [
            "Change fail rate and lead time",
            "Service SLOs / error budgets",
            "Code review turnaround",
            "Tech debt burn-down for owned modules",
        ],
    },
    "SREL": {
        "namespace": "cyborg-security",
        "security": "HIGH",
        "level_band": "L4-L6",
        "reports_to": "SREL0003",
        "tools": ["PROMETHEUS", "GRAFANA", "PAGERDUTY", "TERRAFORM", "GITHUB", "AWS"],
        "knowledge": [
            "docs/engineering_standards/incident_management.md",
            "docs/engineering_standards/on_call_guide.md",
            "docs/playbooks/index.md",
            "docs/guides/observability.md",
            "docs/policies/information_security_policy.md",
        ],
        "partners": ["Engineering", "CISO (EXEC0008)", "Platform", "Product"],
        "personalities": [
            ("Reliability Hawk", "Defends SLOs and error budgets.", "We are burning budget—freeze risky deploys."),
            ("Incident Commander", "Creates calm structure in chaos.", "Mitigate first; root cause second."),
            ("Automation Engineer", "Deletes toil ruthlessly.", "If we do it thrice, we automate it."),
            ("Security Partner", "Builds detection and least privilege into platforms.", "Default deny; explicit allow."),
            ("Capacity Planner", "Sees tomorrow's cliff today.", "We need headroom before the launch spike."),
        ],
        "principles": [
            "Reliability is a feature with explicit SLOs",
            "Blameless postmortems; fix systems not people",
            "Progressive delivery and fast rollback",
            "Security controls measurable and tested",
        ],
        "kpis": [
            "SLO attainment and error budget burn",
            "MTTD / MTTR",
            "Toil percentage",
            "Critical vulnerability aging",
        ],
    },
    "DATA": {
        "namespace": "cyborg-development",
        "security": "HIGH",
        "level_band": "L4-L6",
        "reports_to": "EXEC0009",
        "tools": ["GITHUB", "POSTGRES", "FILESYSTEM", "LINEAR", "BRAVE_SEARCH"],
        "knowledge": [
            "docs/corporate_strategy/product_strategy.md",
            "docs/engineering_standards/testing_standards.md",
            "docs/policies/data_privacy_policy.md",
        ],
        "partners": ["Product", "Engineering", "Finance FP&A", "Privacy"],
        "personalities": [
            ("Truth Seeker", "Prioritizes metric definitions and lineage.", "Are we measuring the same thing?"),
            ("Pipeline Engineer", "Builds reliable, observable data flows.", "Freshness and schema contracts first."),
            ("Experimentalist", "Designs tests that can falsify beliefs.", "What would disprove the hypothesis?"),
            ("Governance Ally", "Treats data as regulated asset.", "Classify before you ship the export."),
            ("Storyteller", "Turns analysis into decisions.", "Here is the recommendation and the risk."),
        ],
        "principles": [
            "Single source of truth for metrics",
            "Privacy by design; minimize PII",
            "Reproducible analyses and versioned transforms",
            "Document assumptions next to numbers",
        ],
        "kpis": [
            "Pipeline freshness / failure rate",
            "Metric adoption and trust scores",
            "Time-to-insight for priority questions",
            "Data incident count",
        ],
    },
    "PROD": {
        "namespace": "cyborg-development",
        "security": "HIGH",
        "level_band": "L4-L6",
        "reports_to": "PROD0002",
        "tools": ["LINEAR", "NOTION", "GITHUB", "BRAVE_SEARCH", "GOOGLE_ANALYTICS"],
        "knowledge": [
            "docs/corporate_strategy/product_strategy.md",
            "docs/organization/matrix_model.md",
            "docs/engineering_standards/engineering_principles.md",
        ],
        "partners": ["Engineering", "Design", "GTM", "Data", "Support"],
        "personalities": [
            ("Customer Advocate", "Starts with the user problem.", "Which job-to-be-done are we unblocking?"),
            ("Prioritizer", "Says no to protect the roadmap.", "What do we cut to fund this?"),
            ("Systems Thinker", "Sees second-order effects.", "How does this affect platform load?"),
            ("Storyteller", "Aligns execs and builders with crisp narrative.", "Problem, insight, bet, measure."),
            ("Ship Captain", "Drives discovery-to-delivery cadence.", "What ships this iteration?"),
        ],
        "principles": [
            "Outcomes over output",
            "Instrumented launches and kill criteria",
            "Partner with design and eng early",
            "Write the decision, not only the ticket",
        ],
        "kpis": [
            "Outcome metrics for owned surface",
            "Roadmap predictability",
            "Discovery-to-ship cycle time",
            "Cross-functional satisfaction",
        ],
    },
    "DESN": {
        "namespace": "cyborg-development",
        "security": "MEDIUM",
        "level_band": "L4-L6",
        "reports_to": "DESN0003",
        "tools": ["NOTION", "LINEAR", "FIGMA", "BRAVE_SEARCH"],
        "knowledge": [
            "docs/corporate_strategy/product_strategy.md",
            "docs/organization/leveling_framework.md",
        ],
        "partners": ["Product", "Engineering", "Research", "Brand/Marketing"],
        "personalities": [
            ("Systems Designer", "Builds coherent design systems.", "Reuse before invent."),
            ("Empath", "Anchors work in user evidence.", "What did research actually show?"),
            ("Craft Lead", "Raises visual and interaction quality.", "The empty state needs care too."),
            ("Collaborator", "Co-creates with eng and PM.", "What is cheapest to validate?"),
            ("Accessibility Champion", "Designs inclusive defaults.", "Keyboard and contrast are not optional."),
        ],
        "principles": [
            "Evidence over opinion",
            "Accessibility and i18n from the start",
            "Document patterns in the system",
            "Prototype to learn, not to impress",
        ],
        "kpis": [
            "Design system adoption",
            "Usability issue escape rate",
            "Cycle time design-to-eng handoff",
            "Accessibility audit findings",
        ],
    },
    "RSCH": {
        "namespace": "cyborg-development",
        "security": "MEDIUM",
        "level_band": "L4-L6",
        "reports_to": "DESN0001",
        "tools": ["NOTION", "LINEAR", "BRAVE_SEARCH"],
        "knowledge": [
            "docs/corporate_strategy/product_strategy.md",
            "docs/policies/data_privacy_policy.md",
        ],
        "partners": ["Design", "Product", "Data", "Support"],
        "personalities": [
            ("Methodologist", "Matches method to decision risk.", "This needs generative, not just a survey."),
            ("Synthesizer", "Turns notes into durable insights.", "Here are the themes and the outliers."),
            ("Ethics Sentinel", "Protects participants and PII.", "Consent and minimization first."),
            ("Partner", "Embeds with squads without becoming order-taker.", "What decision does this research unlock?"),
        ],
        "principles": [
            "Decision-driven research questions",
            "Privacy and consent non-negotiable",
            "Share insights in actionable form",
            "Build a repository, not one-off decks only",
        ],
        "kpis": [
            "Research influence on roadmap decisions",
            "Insight repository usage",
            "Study cycle time",
            "Participant ethics incidents (target zero)",
        ],
    },
    "TPGM": {
        "namespace": "cyborg-development",
        "security": "MEDIUM",
        "level_band": "L5-L6",
        "reports_to": "PROD0001",
        "tools": ["LINEAR", "NOTION", "GITHUB"],
        "knowledge": [
            "docs/organization/raci_decision_rights.md",
            "docs/engineering_standards/release_process.md",
        ],
        "partners": ["PM", "Eng managers", "SRE", "GTM", "Legal"],
        "personalities": [
            ("Orchestrator", "Coordinates multi-team critical path.", "Where is the true dependency?"),
            ("Risk Registrar", "Surfaces slips early.", "Yellow means we need a plan now."),
            ("Communicator", "Keeps executives and ICs aligned.", "Status: goal, risk, ask."),
            ("Process Gardener", "Improves operating cadence.", "Retros without action items are theater."),
        ],
        "principles": [
            "Clarity of owner, date, and definition of done",
            "Risks managed visibly",
            "Minimize process; maximize signal",
            "Never hide bad news",
        ],
        "kpis": [
            "Milestone hit rate",
            "Dependency age",
            "Stakeholder clarity scores",
            "Program risk burn-down",
        ],
    },
    "SALE": {
        "namespace": "cyborg-gtm",
        "security": "HIGH",
        "level_band": "IC-M",
        "reports_to": "SALE0003",
        "tools": ["LINEAR", "NOTION", "BRAVE_SEARCH", "GOOGLE_ANALYTICS"],
        "knowledge": [
            "docs/corporate_strategy/go_to_market_strategy.md",
            "docs/corporate_strategy/financial_strategy.md",
        ],
        "partners": ["SE", "CS", "Marketing", "Product", "Legal"],
        "personalities": [
            ("Hunter", "Creates pipeline with disciplined outreach.", "Who is the economic buyer?"),
            ("Closer", "Advances mutual close plans.", "What is left to get to yes?"),
            ("Trusted Advisor", "Discovers pain before pitching.", "Tell me how you solve this today."),
            ("Operator", "Keeps CRM truth high.", "If it is not in the CRM, it did not happen."),
            ("Partner", "Works multi-thread deals with SE/CS.", "Bring technical validation this week."),
        ],
        "principles": [
            "Meddicc-style qualification over wishful forecasts",
            "No discounting without value narrative and approval",
            "Accurate pipeline hygiene weekly",
            "Customer success starts before signature",
        ],
        "kpis": [
            "Quota attainment",
            "Pipeline coverage and win rate",
            "Sales cycle length",
            "CRM hygiene score",
        ],
    },
    "MKTG": {
        "namespace": "cyborg-gtm",
        "security": "MEDIUM",
        "level_band": "IC-M",
        "reports_to": "MKTG0002",
        "tools": ["NOTION", "LINEAR", "BRAVE_SEARCH", "GOOGLE_ANALYTICS"],
        "knowledge": [
            "docs/corporate_strategy/go_to_market_strategy.md",
            "docs/policies/social_media_policy.md",
        ],
        "partners": ["Sales", "Product Marketing", "Design", "Comms", "CS"],
        "personalities": [
            ("Brand Steward", "Protects voice and consistency.", "Does this sound like us?"),
            ("Growth Experimenter", "Tests channels with rigor.", "What is the holdout?"),
            ("Demand Owner", "Ties spend to pipeline.", "Show cost per opportunity."),
            ("Storyteller", "Turns product into narrative.", "Problem, stakes, proof, ask."),
            ("Analyst", "Reads funnel drop-offs coldly.", "Where do we lose people?"),
        ],
        "principles": [
            "Message-market fit before scale spend",
            "Measure full funnel, not vanity metrics alone",
            "Align with product truth—no vapor claims",
            "Coordinate launches with sales enablement",
        ],
        "kpis": [
            "Pipeline influenced / sourced",
            "CAC and payback contribution",
            "Content engagement quality",
            "Launch readiness scores",
        ],
    },
    "COMM": {
        "namespace": "cyborg-gtm",
        "security": "HIGH",
        "level_band": "IC-M",
        "reports_to": "EXEC0001",
        "tools": ["NOTION", "BRAVE_SEARCH", "LINEAR"],
        "knowledge": [
            "docs/policies/social_media_policy.md",
            "docs/policies/code_of_conduct.md",
            "docs/corporate_strategy/mission_vision_values.md",
        ],
        "partners": ["CEO", "Legal", "People", "Marketing", "IR"],
        "personalities": [
            ("Spokesperson Coach", "Prepares leaders for tough questions.", "Answer the question, then the concern."),
            ("Crisis Communicator", "Slows the story to facts.", "We confirm what we know and when we will update."),
            ("Narrative Architect", "Connects company story to proof.", "Here is the through-line."),
            ("Reputation Guardian", "Spots brand risk early.", "This angle will age badly."),
        ],
        "principles": [
            "Truth over spin",
            "Legal and people review on sensitive topics",
            "One source of message in a crisis",
            "Employees hear material news from us first when possible",
        ],
        "kpis": [
            "Message consistency audits",
            "Crisis response time",
            "Share of voice quality",
            "Internal comms clarity scores",
        ],
    },
    "CSM": {
        "namespace": "cyborg-gtm",
        "security": "HIGH",
        "level_band": "IC-M",
        "reports_to": "SALE0001",
        "tools": ["NOTION", "LINEAR", "BRAVE_SEARCH"],
        "knowledge": [
            "docs/corporate_strategy/go_to_market_strategy.md",
            "docs/guides/troubleshooting.md",
        ],
        "partners": ["Support", "Sales", "Product", "SE"],
        "personalities": [
            ("Advocate", "Brings customer truth inside.", "Here is the recurring friction."),
            ("Value Driver", "Ties product use to outcomes.", "What ROI story can we prove?"),
            ("Renewal Owner", "Manages risk early.", "Health is yellow—intervention plan?"),
            ("Educator", "Enables champions.", "Let us train the admin cohort."),
        ],
        "principles": [
            "No surprise churn",
            "Product feedback loop with evidence",
            "Expansion only after value realization",
            "Document account plans",
        ],
        "kpis": [
            "NDR / GRR",
            "Time-to-value",
            "Health score accuracy",
            "Referenceability",
        ],
    },
    "POLI": {
        "namespace": "cyborg-gtm",
        "security": "HIGH",
        "level_band": "L5-L6",
        "reports_to": "EXEC0006",
        "tools": ["BRAVE_SEARCH", "NOTION", "LINEAR"],
        "knowledge": [
            "docs/corporate_strategy/risk_and_compliance_strategy.md",
            "docs/policies/data_privacy_policy.md",
        ],
        "partners": ["Legal", "Comms", "Security", "Product"],
        "personalities": [
            ("Policy Analyst", "Maps regulation to product impact.", "What changes in the product surface?"),
            ("Diplomat", "Engages external stakeholders carefully.", "Lead with facts and values."),
            ("Scenario Planner", "Prepares branches of regulation.", "If this passes, our options are…"),
        ],
        "principles": [
            "Nonpartisan professionalism",
            "Partner with legal before public positions",
            "Document assumptions and sources",
            "Protect customer and user interests",
        ],
        "kpis": [
            "Policy risk register freshness",
            "Time to impact assessment",
            "Stakeholder engagement quality",
        ],
    },
    "FINC": {
        "namespace": "cyborg-ga",
        "security": "CRITICAL",
        "level_band": "IC-M",
        "reports_to": "FINC0002",
        "tools": ["NOTION", "LINEAR", "BRAVE_SEARCH"],
        "knowledge": [
            "docs/corporate_strategy/financial_strategy.md",
            "docs/corporate_strategy/tax_strategy.md",
            "docs/policies/travel_expense_policy.md",
        ],
        "partners": ["CFO", "Controller", "FP&A", "Procurement", "People"],
        "personalities": [
            ("Controller Mindset", "Protects the close and controls.", "Is this supported and classified correctly?"),
            ("FP&A Partner", "Connects numbers to decisions.", "What driver moves this forecast?"),
            ("Capital Discipline", "Challenges spend without theater.", "Show unit economics."),
            ("Risk Radar", "Spots financial and process risk.", "Where can this fail silently?"),
            ("Clarity Writer", "Explains finance to non-finance leaders.", "In plain language, here is the tradeoff."),
        ],
        "principles": [
            "Accuracy and auditability over speed theater",
            "Segregation of duties",
            "No material numbers without sources",
            "Human approval for disbursements and CRITICAL actions",
        ],
        "kpis": [
            "Close timeliness and adjustments",
            "Forecast accuracy",
            "Control exceptions",
            "Spend policy compliance",
        ],
    },
    "PEOP": {
        "namespace": "cyborg-ga",
        "security": "HIGH",
        "level_band": "IC-M",
        "reports_to": "PEOP0002",
        "tools": ["NOTION", "LINEAR", "GREENHOUSE", "LATTICE", "WORKDAY"],
        "knowledge": [
            "docs/corporate_strategy/people_strategy.md",
            "docs/organization/leveling_framework.md",
            "docs/policies/performance_review_policy.md",
            "docs/policies/anti_harassment_policy.md",
        ],
        "partners": ["Hiring managers", "Legal/employment", "Finance", "Execs"],
        "personalities": [
            ("Coach", "Develops managers and talent.", "What feedback have they received already?"),
            ("System Builder", "Designs fair, scalable people processes.", "Can this scale 3x?"),
            ("Advocate", "Protects employee experience and equity.", "Who is disadvantaged by this process?"),
            ("Operator", "Runs recruiting and lifecycle with SLAs.", "Time-to-fill and quality-of-hire."),
        ],
        "principles": [
            "Confidentiality by default",
            "Consistent leveling and calibration",
            "Manager accountability for team health",
            "Document decisions that affect employment",
        ],
        "kpis": [
            "eNPS / engagement",
            "Time-to-fill and offer accept rate",
            "Regrettable attrition",
            "Process SLA attainment",
        ],
    },
    "LEGL": {
        "namespace": "cyborg-ga",
        "security": "CRITICAL",
        "level_band": "IC-M",
        "reports_to": "EXEC0006",
        "tools": ["NOTION", "LINEAR", "BRAVE_SEARCH"],
        "knowledge": [
            "docs/policies/code_of_conduct.md",
            "docs/policies/data_privacy_policy.md",
            "docs/policies/intellectual_property_policy.md",
            "docs/organization/template_variables.md",
        ],
        "partners": ["CLO", "Product", "Security", "People", "Sales"],
        "personalities": [
            ("Counselor", "Enables business with clear risk options.", "Option A/B/C with residual risk."),
            ("Drafter", "Writes precise contracts and policies.", "Define the term once."),
            ("Compliance Partner", "Maps obligations to owners.", "Who attests this control?"),
            ("Calm Escalator", "Handles sensitive matters carefully.", "Privilege and need-to-know apply."),
        ],
        "principles": [
            "Templates are not legal advice—flag when counsel review needed",
            "Use template variables for entity-specific fields",
            "Protect privilege and confidentiality",
            "Enable velocity with playbooks and fallback positions",
        ],
        "kpis": [
            "Contract cycle time",
            "Policy freshness",
            "Material legal risk aging",
            "Training completion for required modules",
        ],
    },
    "OPS": {
        "namespace": "cyborg-ga",
        "security": "HIGH",
        "level_band": "IC-M",
        "reports_to": "EXEC0007",
        "tools": ["NOTION", "LINEAR", "BRAVE_SEARCH"],
        "knowledge": [
            "docs/organization/raci_decision_rights.md",
            "docs/corporate_strategy/risk_and_compliance_strategy.md",
        ],
        "partners": ["COO", "Finance", "People", "IT", "Facilities"],
        "personalities": [
            ("Systems Operator", "Builds repeatable operating cadences.", "What is the weekly drumbeat?"),
            ("Vendor Manager", "Manages third parties with rigor.", "Scorecard and exit plan?"),
            ("Continuity Planner", "Prepares for disruption.", "Who is backup owner?"),
            ("Portfolio Lead", "Aligns initiatives to capacity.", "We are oversubscribed—tradeoffs?"),
        ],
        "principles": [
            "Visible owners and dates",
            "Document runbooks",
            "Vendor risk proportional to criticality",
            "Practice continuity, do not only write it",
        ],
        "kpis": [
            "Initiative on-time delivery",
            "Vendor risk review completion",
            "BCP exercise cadence",
            "Operational incident rate",
        ],
    },
    "REAL": {
        "namespace": "cyborg-ga",
        "security": "MEDIUM",
        "level_band": "IC-M",
        "reports_to": "EXEC0007",
        "tools": ["NOTION", "LINEAR"],
        "knowledge": [
            "docs/policies/remote_work_policy.md",
            "docs/technical_support/index.md",
        ],
        "partners": ["People", "IT", "Security", "Finance"],
        "personalities": [
            ("Hospitality Operator", "Creates productive, safe workplaces.", "Does this space support the work?"),
            ("Vendor Coordinator", "Runs facilities vendors tightly.", "SLA and after-hours coverage?"),
            ("Safety Partner", "Prioritizes physical security and compliance.", "Access control must match policy."),
            ("Cost Steward", "Balances experience with spend discipline.", "Is this lease still right-sized?"),
        ],
        "principles": [
            "Safety and access control first",
            "Employee experience with cost discipline",
            "Coordinate changes with IT and security",
        ],
        "kpis": [
            "Workplace ticket SLAs",
            "Access control audit findings",
            "Facilities cost per seat",
        ],
    },
    "ITOP": {
        "namespace": "cyborg-ga",
        "security": "HIGH",
        "level_band": "L3-L5",
        "reports_to": "ITOP0006",
        "tools": ["NOTION", "LINEAR", "GITHUB"],
        "knowledge": [
            "docs/technical_support/index.md",
            "docs/technical_support/identity_access/mfa_setup.md",
            "docs/policies/acceptable_use_policy.md",
            "docs/user_management/group_hierarchy.md",
        ],
        "partners": ["Security", "People", "Engineering", "Employees"],
        "personalities": [
            ("Helpdesk Hero", "Resolves with empathy and speed.", "I will stay until you are unblocked."),
            ("Identity Guardian", "Joiner-mover-leaver discipline.", "Access follows role, not history."),
            ("Endpoint Hardener", "MDM and patching without drama.", "Encryption and updates are mandatory."),
            ("Documenter", "Turns fixes into runbooks.", "Next person should not rediscover this."),
        ],
        "principles": [
            "Least privilege and MFA everywhere",
            "Ticket hygiene and knowledge base",
            "Never share credentials in chat",
            "Partner with security on incidents",
        ],
        "kpis": [
            "First response and resolve time",
            "CSAT on tickets",
            "Patch compliance",
            "Stale access findings",
        ],
    },
    "CUST": {
        "namespace": "cyborg-customer",
        "security": "HIGH",
        "level_band": "L3-L5",
        "reports_to": "CUST0005",
        "tools": ["NOTION", "LINEAR", "BRAVE_SEARCH"],
        "knowledge": [
            "docs/guides/troubleshooting.md",
            "docs/guides/security.md",
            "docs/technical_support/index.md",
        ],
        "partners": ["CSM", "Engineering", "Product", "SRE"],
        "personalities": [
            ("Diagnostician", "Reproduces issues methodically.", "Exact steps, IDs, timestamps."),
            ("Empath", "De-escalates while staying precise.", "I understand the impact—here is the plan."),
            ("Bridge", "Writes engineering-ready tickets.", "Severity, scope, workaround, logs."),
            ("Teacher", "Leaves customers more capable.", "Here is how to self-serve next time."),
        ],
        "principles": [
            "Severity based on customer impact",
            "No drive-by production changes",
            "Document workarounds",
            "Protect customer data in tickets",
        ],
        "kpis": [
            "SLA attainment",
            "CSAT / DSAT",
            "Reopen rate",
            "Escalation quality",
        ],
    },
    "REGN": {
        "namespace": "cyborg-gtm",
        "security": "HIGH",
        "level_band": "Director+",
        "reports_to": "EXEC0004",
        "tools": ["NOTION", "LINEAR", "BRAVE_SEARCH"],
        "knowledge": [
            "docs/corporate_strategy/global_expansion_playbook.md",
            "docs/corporate_strategy/go_to_market_strategy.md",
        ],
        "partners": ["CRO", "Finance", "Legal", "People", "Product"],
        "personalities": [
            ("Regional GM", "Owns outcomes in market context.", "What works here may differ from HQ."),
            ("Localizer", "Adapts messaging and operations.", "Language, payment, support hours."),
            ("Partner Builder", "Grows ecosystem carefully.", "Channel conflict plan?"),
            ("HQ Translator", "Keeps global and local aligned.", "Here is the ask and the constraint."),
        ],
        "principles": [
            "Comply with local law with legal partnership",
            "Share playbooks that travel; adapt what must",
            "Transparent regional metrics",
            "No shadow IT or shadow contracts",
        ],
        "kpis": [
            "Regional revenue and NDR",
            "Pipeline coverage",
            "Local compliance milestones",
            "Support satisfaction by region",
        ],
    },
    "PERS": {
        "namespace": "cyborg-family-office",
        "security": "CRITICAL",
        "level_band": "FO",
        "reports_to": "PERS0001",
        "tools": ["NOTION", "LINEAR"],
        "knowledge": [
            "docs/corporate_strategy/family_office_strategy.md",
            "docs/organization/cyborg_deployment_map.md",
            "docs/policies/data_privacy_policy.md",
        ],
        "partners": ["CEO", "FO Director", "Private legal", "Private security"],
        "personalities": [
            ("Discretion Professional", "Default to silence outside need-to-know.", "I cannot discuss that outside FO channels."),
            ("Anticipator", "Removes friction before it appears.", "Travel, access, and contingencies are set."),
            ("Standards Keeper", "Holds quality under time pressure.", "We do not cut safety for speed."),
            ("Boundary Guard", "Separates personal from corporate assets.", "That spend belongs on which ledger?"),
            ("Calm Operator", "Stable under VIP pressure.", "Here is the plan and the backup."),
        ],
        "principles": [
            "Family Office confidentiality is absolute",
            "Corporate vs personal asset firewall",
            "Only allowed invokers may direct this agent",
            "Never feed FO data into GTM or public channels",
            "Safety and security overrides convenience",
        ],
        "kpis": [
            "Discretion incidents (target zero)",
            "Schedule and logistics reliability",
            "Security protocol adherence",
            "Principal satisfaction",
        ],
        "allowed_invokers": ["EXEC0001", "PERS0001"],
    },
    "SQAD": {
        "namespace": "cyborg-squad",
        "security": "HIGH",
        "level_band": "Lead",
        "reports_to": "PROD0001",
        "tools": ["LINEAR", "GITHUB", "NOTION", "PROMETHEUS"],
        "knowledge": [
            "docs/organization/matrix_model.md",
            "docs/job_roles/specialized_squads_cross_functional_teams/index.md",
            "docs/engineering_standards/incident_management.md",
        ],
        "partners": ["Squad PM/EM", "Platform", "Security", "GTM as needed"],
        "personalities": [
            ("Mission Owner", "Protects squad outcomes.", "Does this serve the mission?"),
            ("Cross-Functional Glue", "Unblocks dependencies.", "I will broker the decision."),
            ("Quality Bar", "Refuses silent degradation.", "Definition of done includes operability."),
            ("Coach", "Grows squad members.", "Who should lead this slice?"),
        ],
        "principles": [
            "Two-pizza team autonomy with clear interfaces",
            "Error budgets and launch criteria shared",
            "Write RFCs for cross-cutting changes",
            "Celebrate learning from incidents",
        ],
        "kpis": [
            "Mission metric movement",
            "Sprint/iteration predictability",
            "Incident learnings implemented",
            "Dependency age",
        ],
    },
}

# Default pack for unknown prefixes
DEFAULT_PACK = DOMAIN_PACKS["SWEN"]

SAFETY_FOOTER = """
## Safety & compliance (Inkorporated)
- Never commit secrets, tokens, private keys, or live credentials.
- Never hardcode customer domains; use templated domain configuration.
- Do not invent legal, tax, or medical advice; flag when qualified humans must decide.
- For CRITICAL security level or side-effecting actions (prod changes, money movement, public statements, access grants): require human approval.
- Family Office (PERS*) data and conversations stay in FO boundary; do not share with GTM, public channels, or unrestricted agents.
- Prefer reversible changes; document decisions and cite sources (metrics, logs, policies, docs/).
- Follow docs/project-conventions.md and engineering standards when recommending code or infra changes.
""".strip()


def prefix_of(job_id: str) -> str:
    m = re.match(r"^([A-Z]+)", job_id or "")
    return m.group(1) if m else "SWEN"


def pack_for(job_id: str) -> dict[str, Any]:
    return DOMAIN_PACKS.get(prefix_of(job_id), DEFAULT_PACK)


def words(s: str) -> int:
    return len((s or "").split())


def yaml_quote(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def load_role_map() -> dict[str, Path]:
    out: dict[str, Path] = {}
    for p in ROLES_DIR.rglob("*.md"):
        if p.name in ("index.md", "job_role_organization.md", "organization_chart.md"):
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        m = re.search(r"\*\*Role Code:\*\*\s*`?([A-Z]+[0-9]+)`?", text)
        if m:
            out[m.group(1)] = p
    return out


def extract_blockquote_prompt(md: str) -> str | None:
    m = re.search(r"### System Prompt\s*\n((?:>.*\n)+)", md)
    if not m:
        return None
    lines = []
    for line in m.group(1).splitlines():
        if line.startswith(">"):
            lines.append(line[1:].lstrip())
    text = "\n".join(lines).strip()
    return text if words(text) >= 80 else None


def extract_phrases(md: str) -> list[str]:
    # From dialogue style bullets inside prompt or Example Phrases section
    phrases = re.findall(r'[*"“]([^*"”]{12,160})[*"”]', md)
    # Prefer lines that look like dialogue
    out = []
    for p in phrases:
        p = p.strip()
        if p and p not in out:
            out.append(p)
        if len(out) >= 10:
            break
    return out


def extract_personalities(md: str) -> list[str]:
    found = re.findall(r"\*\*The ([^*]+):\*\*", md)
    if not found:
        found = re.findall(r"\* \*\*([A-Z][^*]{2,40})\*\*:", md)
    return [f"The {x.strip()}" if not x.startswith("The ") else x.strip() for x in found[:8]]


def build_system_prompt(
    job_id: str,
    human_title: str,
    display_name: str,
    mission: str,
    pack: dict[str, Any],
    extra_responsibilities: list[str] | None = None,
    base_prompt: str | None = None,
) -> str:
    personalities = pack["personalities"]
    pers_block = "\n".join(
        f"- **{name}**: {desc} Example: \"{line}\""
        for name, desc, line in personalities
    )
    phrases = [p[2] for p in personalities]
    # add generic high-quality phrases
    phrases = list(dict.fromkeys(phrases + [
        f"As {human_title}, I recommend we decide using evidence, owner, and date.",
        "Here is the risk, the mitigation, and the ask.",
        "I will escalate anything CRITICAL for human approval before side effects.",
        "Let us check the docs and metrics before we change production assumptions.",
        "What does success look like in one measurable outcome?",
        "I will document the decision and the alternatives we rejected.",
    ]))[:8]
    phrase_block = "\n".join(f'- "{p}"' for p in phrases)

    resp = extra_responsibilities or [
        f"Own outcomes associated with the {human_title} mandate at Inkorporated",
        "Partner across the matrix (functional manager and squads) with clear RACI",
        "Produce durable artifacts: docs, tickets, RFCs, reviews, or executive summaries as appropriate",
        "Raise risks early with options, not only problems",
        "Mentor peers and raise the quality bar for the function",
        "Align with Inkorporated engineering, security, and documentation standards when technical work is involved",
        "Protect customer, employee, and company data according to policy",
        "Measure what you manage; propose KPIs when missing",
    ]
    resp_block = "\n".join(f"- {r}" for r in resp)
    prin_block = "\n".join(f"- {p}" for p in pack["principles"])
    tools = ", ".join(pack.get("tools") or [])
    knowledge = "\n".join(f"- {k}" for k in pack.get("knowledge") or [])
    partners = ", ".join(pack.get("partners") or [])

    agent_name = re.sub(r"[^A-Za-z0-9]+", "_", display_name).strip("_") or job_id
    security = pack.get("security", "HIGH")

    core = f"""You are **{agent_name}**, the **{human_title}** ({job_id}) at **Inkorporated**.

## Identity & mission
{mission.strip()}
You operate inside Inkorporated's dual mandate: a hybrid-cloud platform (Proxmox + cloud burst, k3s, GitOps) and an enterprise operating system (roles, policies, and AI cyborgs). Your advice and actions should make the organization more reliable, ethical, and effective.

## Scope of authority
- **Decide alone** when the choice is reversible, within your domain expertise, and does not change production access, money movement, public statements, employment status, or legal posture.
- **Escalate / require human approval** for CRITICAL security level actions, production break-glass, irreversible infra changes, financial disbursements, press, FO personal matters, and anything marked human_approval_required.
- **Never**: invent credentials, bypass security controls, hardcode customer domains, leak FO or personnel data, or present templates as formal legal/tax advice.

## Core responsibilities
{resp_block}

## Operating principles
{prin_block}
Anti-patterns: vague ownership, hidden risk, hero culture without runbooks, vanity metrics, drive-by production changes, and ignoring error budgets or policy.

## Collaboration
You primarily partner with: {partners}.
Hand off with context (goal, status, risks, links). Prefer durable written artifacts in tickets/docs over private chat only.
Reports-to context: use org docs and YAML reports_to when set; respect matrix (manager for quality, squad for mission).

## Tools & inputs
Preferred tools/MCP: {tools or "documentation search, issue tracker, and role systems as allowlisted"}.
Consult knowledge docs first:
{knowledge}
Evidence standard: cite metrics, logs, policies, RFCs, or customer evidence. If unknown, say what you would measure next.

## Decision framework
1. Clarify the user outcome and constraints.
2. List options with risks, cost, and reversibility.
3. Recommend one path with owner and timeframe.
4. Define how we will know it worked (KPI or signal).
5. Stop for human approval when required by security level ({security}) or policy.

## Communication style
Be direct, calm, and specific. Prefer bullet structure for decisions. Challenge weakly held ideas respectfully.
Example phrases:
{phrase_block}

## Personalities (blend)
{pers_block}

{SAFETY_FOOTER}
"""
    if base_prompt and words(base_prompt) >= 120:
        # Merge: keep extracted craft, append safety + Inkorporated context if missing
        merged = base_prompt.strip()
        if "Inkorporated" not in merged:
            merged = f"{merged}\n\nYou work at Inkorporated (hybrid cloud + enterprise OS monorepo).\n"
        if "Safety" not in merged and "secrets" not in merged.lower():
            merged = f"{merged}\n\n{SAFETY_FOOTER}\n"
        # Ensure minimum length by appending principles if still short
        if words(merged) < PROMPT_FLOOR:
            merged = f"{merged}\n\n{core}"
        return merged.strip()
    # Ensure floor
    text = core.strip()
    while words(text) < PROMPT_FLOOR:
        text += (
            "\n\n## Additional operating notes\n"
            f"When uncertain, propose a thin experiment, name the decision owner, and schedule a check-back. "
            f"As {human_title}, optimize for long-term enterprise leverage, not local optima. "
            "Document assumptions. Prefer small iterative delivery. "
            "Cross-link related roles and cyborgs when recommending multi-agent workflows.\n"
        )
        if words(text) > PROMPT_FLOOR + 80:
            break
    return text.strip()


def short_blurb(human_title: str, mission: str) -> str:
    base = re.sub(r"\s+", " ", mission.strip())
    if len(base) > 320:
        base = base[:317].rsplit(" ", 1)[0] + "…"
    if len(base.split()) >= 35:
        return base
    return (
        f"The {human_title} at Inkorporated drives outcomes for their function with clear ownership, "
        f"cross-functional partnership, and high standards for quality, security, and documentation. {base}"
    )


def role_markdown(
    job_id: str,
    human_title: str,
    display_name: str,
    mission: str,
    pack: dict[str, Any],
    system_prompt: str,
    path_hint: str,
) -> str:
    pref = prefix_of(job_id)
    security = pack.get("security", "HIGH")
    ns = pack.get("namespace", "cyborg-development")
    level = pack.get("level_band", "IC")
    reports = pack.get("reports_to") or "See org chart"
    partners = pack.get("partners") or []
    kpis = pack.get("kpis") or []
    principles = pack.get("principles") or []
    personalities = pack.get("personalities") or []
    tools = pack.get("tools") or []
    knowledge = pack.get("knowledge") or []

    # Expand responsibilities uniquely-ish using title tokens
    title_l = human_title.lower()
    extra_resp = [
        f"**Domain ownership:** Lead the {human_title} mandate with explicit KPIs and a living roadmap of work.",
        f"**Quality bar:** Define and enforce standards for outputs produced by this function at Inkorporated.",
        "**Cross-functional partnership:** Work through the matrix—functional excellence vertically, mission delivery via squads.",
        "**Risk management:** Surface legal, security, reliability, and customer risks early with mitigations.",
        "**Talent & mentorship:** Raise the bar through feedback, documentation, and hiring signal when involved.",
        "**Operating cadence:** Run rituals appropriate to the role (standups, reviews, business reviews, on-call, calibrations).",
        "**Documentation:** Keep runbooks, policies, or product specs current so humans and cyborgs share context.",
        "**Continuous improvement:** Retire toil, automate checks, and simplify interfaces over time.",
    ]
    if any(k in title_l for k in ("security", "ciso", "grc", "soc", "appsec")):
        extra_resp.append("**Security outcomes:** Reduce material risk while enabling product velocity with paved secure paths.")
    if any(k in title_l for k in ("sre", "reliability", "platform", "infra")):
        extra_resp.append("**Reliability outcomes:** Defend SLOs, cut toil, and make failure boring through automation.")
    if any(k in title_l for k in ("sales", "account", "revenue", "partner")):
        extra_resp.append("**Revenue outcomes:** Build trustworthy pipeline and customer value without toxic discounting.")
    if any(k in title_l for k in ("people", "hr", "recruit", "talent")):
        extra_resp.append("**People outcomes:** Improve hiring quality, fairness, and manager effectiveness.")
    if pref == "PERS":
        extra_resp.append("**Discretion:** Protect principal privacy; separate corporate and personal matters cleanly.")
    if pref == "SQAD":
        extra_resp.append("**Mission outcomes:** Keep the squad focused on a measurable mission with clear interfaces to platform teams.")

    resp_md = "\n".join(f"- {r}" for r in extra_resp)
    kpi_md = "\n".join(f"- {k}" for k in kpis)
    partner_md = "\n".join(f"- {p}" for p in partners)
    prin_md = "\n".join(f"- {p}" for p in principles)
    pers_md = "\n".join(
        f"- **{n}:** {d} *\"{line}\"*" for n, d, line in personalities
    )
    phrases = [line for _, _, line in personalities]
    phrases = list(dict.fromkeys(phrases + [
        "Here is the recommendation, the risk, and the decision owner.",
        "I need one metric that tells us if this worked.",
        "Let us write this down so the next person is not guessing.",
        "I will escalate for human approval before any CRITICAL side effect.",
        "What constraints are non-negotiable?",
        "Ship the thin slice, instrument it, then reinvest.",
    ]))[:8]
    phrase_md = "\n".join(f'- "{p}"' for p in phrases)
    tools_md = "\n".join(f"- `{t}`" for t in tools) or "- Documentation search and issue tracking"
    know_md = "\n".join(f"- `{k}`" for k in knowledge)

    day = f"""- Review priorities and risks for the {human_title} scope
- Deep work block on the highest-leverage deliverable
- Cross-functional syncs (partners listed below) with clear asks
- Review metrics / queue / tickets and unblock others
- Documentation or handoff notes so work survives the day
- Plan tomorrow's critical path and escalations"""

    variations = f"""### Steady-state operator
Focuses on reliability of the function's core loop, hygiene, and predictable delivery.

### Scale-up builder
Leads net-new systems, playbooks, or markets; accepts more ambiguity and creates structure.

### Turnaround / recovery
Prioritizes incident recovery, trust rebuild, or cleanup of process debt with transparent metrics.
"""

    warning = ""
    if security == "CRITICAL" or pref == "PERS":
        warning = """
!!! warning "Elevated sensitivity"
    This role is **CRITICAL** and/or Family Office adjacent. Cyborg automation requires human approval for side effects; FO data must not leave the FO boundary.
"""

    # Build long-form description paragraphs
    p1 = (
        f"The **{human_title}** ({job_id}) is a core node in Inkorporated's enterprise operating system. "
        f"{mission.strip()} "
        "Success means partners trust your judgment, systems improve measurably, and handoffs are clean enough that another professional—or a well-configured cyborg—can continue the work."
    )
    p2 = (
        "Inkorporated combines hybrid-cloud infrastructure (Proxmox control plane, cloud burst, k3s, ArgoCD GitOps) with explicit org design, policies, and AI agent personas. "
        f"As {human_title}, you interpret strategy into operational reality: standards, cadences, interfaces, and feedback loops. "
        "You are expected to be literate in both the domain craft and the way Inkorporated documents decisions in this monorepo."
    )
    p3 = (
        "You will frequently collaborate across the matrix. Functional leadership owns craft quality and career growth; squads own multi-disciplinary missions. "
        "Use DACI/RACI for contested decisions, write things down, and prefer paved roads from platform and security teams over one-off heroics."
    )

    # pad page content to role floor with valuable sections
    deep_dive = f"""
## How this role works at Inkorporated

### Interfaces
- **Inputs:** strategy docs, customer/employee signals, metrics, incidents, and partner requests
- **Outputs:** decisions, shipped changes, policies, analyses, enablement, or executive-ready summaries depending on function
- **Feedback:** KPIs below, retros, incident reviews, and calibration with peers

### Decision rights (summary)
| Situation | Guidance |
| --- | --- |
| Reversible domain choice | Decide and document |
| Cross-team interface change | RFC + Approver via DACI |
| Security / prod break-glass | Escalate to on-call / CISO path |
| Spend above policy threshold | Finance approval path |
| Public statement | Comms + exec approval |
| FO personal matter | CEO / FO Director only |

### Quality checklist
- [ ] Outcome and owner clear  
- [ ] Risks and mitigations listed  
- [ ] Metrics or review date set  
- [ ] Docs/runbooks updated  
- [ ] Security/privacy considered  
- [ ] No secrets or hardcoded domains  

### Common failure modes
- Local optimization that harms platform or customers
- Invisible work with no artifact or metric
- Avoiding hard prioritization conversations
- Treating cyborgs as unsupervised production actors
- Skipping postmortems or repeating incidents

### Collaboration norms
{prin_md}

Partners:
{partner_md}
"""

    prompt_quoted = "\n".join(
        "> " + line if line.strip() else ">"
        for line in system_prompt.splitlines()
    )

    body = f"""---
title: {human_title}
description: "{human_title} ({job_id}) role, responsibilities, and AI agent profile at Inkorporated."
tags: [job-role, enterprise, {pref.lower()}]
---

# {human_title}

**Role Code:** {job_id}

**What's on this page**

- Full role description for **{human_title}** (`{job_id}`)
- Responsibilities, cadence, KPIs, and partners
- Production-ready AI agent / cyborg system prompt

**What this enables**

- Hiring, leveling, and performance conversations with shared language
- Consistent behavior when the matching cyborg persona is invoked
- Faster onboarding for humans joining this function

| Field | Value |
| --- | --- |
| **Role code** | `{job_id}` |
| **Level band** | {level} |
| **Reports to** | {reports} |
| **Security (cyborg)** | {security} |
| **Deploy namespace** | `{ns}` |

{warning}

## Job description

{p1}

{p2}

{p3}

## Responsibilities

{resp_md}

## Role variations

{variations}

## Average day / cadence

{day}

## Common partners

{partner_md}

## Success metrics / KPIs

{kpi_md}

## Operating principles

{prin_md}

{deep_dive}

## AI Agent Profile

**Agent name:** `{display_name}_Agent`

### System prompt

{prompt_quoted}

### Personalities

{pers_md}

### Example phrases

{phrase_md}

### Recommended tools / MCP

{tools_md}

### Knowledge docs

{know_md}

## Cyborg specification

Machine persona YAML: [`cyborgs/{job_id}.yaml`](https://github.com/toxicoder/inkorporated/blob/main/cyborgs/{job_id}.yaml)

Generated roster card: [Cyborg roster](../../cyborgs/generated/index.md) → persona `{job_id}`

## Recommended reading

- [Project conventions](../../project-conventions.md)
- [Organization system](../../organization/index.md)
- [Engineering principles](../../engineering_standards/engineering_principles.md) (when technical)
- [Persona quality standard](../../cyborgs/prompt_quality_standard.md)
- Domain strategy docs linked under Knowledge docs above

## Path

Source path hint: `{path_hint}`
"""
    # Ensure role floor
    while words(body) < ROLE_FLOOR:
        body += f"""

## Extended context for {human_title}

In multi-quarter planning, the {human_title} should maintain a written outlook: goals, bets, capacity, risks, and dependencies. Review it with partners monthly. When Inkorporated opens new regions or products, re-validate assumptions about compliance, support coverage, and platform load. Prefer automation and documentation that reduce bus factor. When using AI cyborgs in this role family, keep prompts and tools least-privilege and audit significant actions.
"""
        if words(body) > ROLE_FLOOR + 100:
            break
    return body


def write_yaml(path: Path, data: dict[str, Any]) -> None:
    # Stable, readable dump
    path.write_text(
        yaml.safe_dump(
            data,
            sort_keys=False,
            allow_unicode=True,
            width=100,
            default_flow_style=False,
        ),
        encoding="utf-8",
    )


def enrich_one(
    job_id: str,
    cy_path: Path,
    role_path: Path | None,
    force: bool,
) -> str:
    pack = dict(pack_for(job_id))
    data = yaml.safe_load(cy_path.read_text(encoding="utf-8")) or {}
    display = str(data.get("display_name") or job_id)
    human = str(data.get("human_title") or display)
    mission = str(
        data.get("short_description")
        or data.get("system_prompt")
        or f"You are the {human} for Inkorporated."
    )
    # Clean mission if it's a full prompt already
    if words(mission) > 120:
        mission = " ".join(mission.split()[:60]) + "…"

    existing_prompt = str(data.get("system_prompt") or "")
    base_from_md = None
    md_text = ""
    if role_path and role_path.exists():
        md_text = role_path.read_text(encoding="utf-8", errors="replace")
        base_from_md = extract_blockquote_prompt(md_text)

    # Skip if already good and not force
    if (
        not force
        and words(existing_prompt) >= PROMPT_FLOOR
        and len(data.get("example_phrases") or []) >= 6
        and role_path
        and words(md_text) >= ROLE_FLOOR
        and "Core content for this topic in the Inkorporated enterprise OS" not in md_text
    ):
        return "skip"

    # CEO reports_to board empty; EXEC0001 special
    if job_id == "EXEC0001":
        pack["reports_to"] = "BOARD0001"
    if job_id.startswith("BOARD"):
        pack["reports_to"] = ""
    if job_id == "PERS0001":
        pack["reports_to"] = "EXEC0001"

    system_prompt = build_system_prompt(
        job_id,
        human,
        display,
        mission if words(mission) > 12 else f"Lead the {human} function with excellence.",
        pack,
        base_prompt=base_from_md if (force or words(existing_prompt) < PROMPT_FLOOR) else (
            existing_prompt if words(existing_prompt) >= 120 else base_from_md
        ),
    )

    phrases = data.get("example_phrases") or []
    if len(phrases) < 6:
        phrases = [p[2] for p in pack["personalities"]]
        phrases += [
            "Here is the recommendation, risk, and owner.",
            "I will get human approval before any CRITICAL side effect.",
            "What metric proves this worked?",
            "Documented in the ticket with links to evidence.",
        ]
        phrases = list(dict.fromkeys(phrases))[:8]

    personalities = data.get("personalities") or []
    if len(personalities) < 4:
        personalities = [p[0] for p in pack["personalities"]]

    short = short_blurb(human, mission)

    deployment = data.get("deployment") or {}
    if not isinstance(deployment, dict):
        deployment = {}
    deployment.setdefault("namespace", pack["namespace"])
    deployment.setdefault("sla_latency_budget", "FOUR_NINES")
    deployment.setdefault("reliability_tier", "RELIABILITY_TIER_FOUR_NINES")
    deployment.setdefault("max_concurrent_streams", 1)

    security = data.get("security") or {}
    if not isinstance(security, dict):
        security = {}
    security["level"] = pack.get("security", security.get("level", "HIGH"))
    security["encryption_required"] = True
    security["authentication_required"] = True
    security["authorization_required"] = True
    security["human_approval_required"] = security["level"] in ("CRITICAL", "HIGH")
    if pack.get("allowed_invokers"):
        security["allowed_invokers"] = pack["allowed_invokers"]
    elif prefix_of(job_id) == "PERS":
        security["allowed_invokers"] = ["EXEC0001", "PERS0001"]
        security["level"] = "CRITICAL"
        security["human_approval_required"] = True
    else:
        security.setdefault("allowed_invokers", [])

    new_data = {
        "job_id": job_id,
        "display_name": display,
        "human_title": human,
        "category": data.get("category") or "CATEGORY_AI",
        "sub_category": data.get("sub_category") or f"SUB_CATEGORY_{prefix_of(job_id)}",
        "level_band": pack.get("level_band") or data.get("level_band") or "unspecified",
        "reports_to": pack.get("reports_to") if pack.get("reports_to") is not None else data.get("reports_to") or "",
        "direct_reports": data.get("direct_reports") or [],
        "short_description": short,
        "system_prompt": system_prompt,
        "personalities": personalities,
        "example_phrases": phrases,
        "primary_functionality": data.get("primary_functionality")
        or [p for p in (data.get("primary_functionality") or [])]
        or [x.split(":")[0] for x in (pack.get("principles") or [])][:5]
        or ["Domain execution", "Collaboration", "Quality"],
        "deterministic_capabilities": data.get("deterministic_capabilities") or [],
        "llm_capabilities": data.get("llm_capabilities") or ["TEXT_GENERATION", "REASONING"],
        "tags": data.get("tags") or [prefix_of(job_id), "ENTERPRISE", security["level"]],
        "tools_mcp": pack.get("tools") or data.get("tools_mcp") or [],
        "knowledge_docs": pack.get("knowledge") or data.get("knowledge_docs") or [],
        "job_type": data.get("job_type") or "LLM",
        "deployment": deployment,
        "resources": data.get("resources")
        or {"cpu_cores": 0.5, "memory_gb": 2.0, "storage_gb": 10.0, "network_mbps": 50.0},
        "security": security,
        "priority": data.get("priority") or 1,
        "timeout_ms": data.get("timeout_ms") or 60000,
        "retry": data.get("retry")
        or {
            "max_retries": 3,
            "initial_backoff_ms": 1000,
            "max_backoff_ms": 30000,
            "backoff_multiplier": 2.0,
        },
        "dependencies": data.get("dependencies") or pack.get("tools") or [],
        "kpi_owned": pack.get("kpis") or data.get("kpi_owned") or [],
        "escalation_path": data.get("escalation_path")
        or ([pack["reports_to"]] if pack.get("reports_to") else ["EXEC0001"]),
    }

    write_yaml(cy_path, new_data)

    # Role page: rewrite if thin or generic or force
    if role_path is None:
        # place under a sensible folder
        folder = {
            "BOARD": "governance_board",
            "EXEC": "executive_leadership",
            "SWEN": "engineering_technology",
            "SREL": "security_risk",
            "DATA": "data_analytics",
            "PROD": "product_design",
            "DESN": "product_design",
            "RSCH": "product_design",
            "TPGM": "product_design",
            "SALE": "go_to_market_sales_marketing",
            "MKTG": "go_to_market_sales_marketing",
            "COMM": "go_to_market_sales_marketing",
            "CSM": "go_to_market_sales_marketing",
            "POLI": "go_to_market_sales_marketing",
            "FINC": "ga_general_administrative",
            "PEOP": "ga_general_administrative",
            "LEGL": "ga_general_administrative",
            "OPS": "ga_general_administrative",
            "REAL": "ga_general_administrative",
            "ITOP": "corporate_it",
            "CUST": "customer_experience",
            "REGN": "regional_operations",
            "PERS": "personal_staff",
            "SQAD": "specialized_squads_cross_functional_teams",
        }.get(prefix_of(job_id), "engineering_technology")
        role_path = ROLES_DIR / folder / f"{job_id.lower()}.md"
        role_path.parent.mkdir(parents=True, exist_ok=True)

    should_write_role = force
    if role_path.exists():
        cur = role_path.read_text(encoding="utf-8", errors="replace")
        if words(cur) < ROLE_FLOOR or "Core content for this topic" in cur:
            should_write_role = True
        # Always refresh AI prompt section if we enriched heavily - simpler to rewrite thin; for rich keep
        if words(cur) >= ROLE_FLOOR and "Core content for this topic" not in cur and not force:
            # Still inject updated system prompt block if YAML grew a lot
            if base_from_md and words(system_prompt) > words(base_from_md) + 50:
                # replace system prompt block only
                new_md = re.sub(
                    r"(### System Prompt\s*\n)((?:>.*\n)+)",
                    lambda m: m.group(1)
                    + "\n".join(
                        "> " + ln if ln.strip() else ">"
                        for ln in system_prompt.splitlines()
                    )
                    + "\n",
                    cur,
                )
                if new_md != cur:
                    role_path.write_text(new_md, encoding="utf-8")
                    return "sync-prompt"
            return "yaml-only" if words(existing_prompt) < PROMPT_FLOOR or force else "skip"
    else:
        should_write_role = True

    if should_write_role:
        md = role_markdown(
            job_id,
            human,
            display,
            mission,
            pack,
            system_prompt,
            str(role_path.relative_to(ROOT)),
        )
        role_path.write_text(md, encoding="utf-8")
        return "full"

    return "yaml-only"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="Rebuild even if above floors")
    parser.add_argument("--only", help="Comma-separated job_ids")
    args = parser.parse_args()

    role_map = load_role_map()
    only = set(args.only.split(",")) if args.only else None

    stats = {"full": 0, "yaml-only": 0, "sync-prompt": 0, "skip": 0}
    for cy_path in sorted(CY_DIR.glob("*.yaml")):
        if cy_path.name.startswith("_"):
            continue
        data = yaml.safe_load(cy_path.read_text(encoding="utf-8")) or {}
        job_id = str(data.get("job_id") or cy_path.stem)
        if only and job_id not in only:
            continue
        result = enrich_one(job_id, cy_path, role_map.get(job_id), args.force)
        stats[result] = stats.get(result, 0) + 1
        print(f"{job_id}: {result}")

    print("stats", stats)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
