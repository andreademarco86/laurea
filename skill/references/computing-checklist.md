# Computing, ICT and engineering: technical checklist

Use for dissertations in ICT, computer science, software engineering, information systems, computer engineering, and electronic or systems engineering with a computing focus. Typical work: building a system or tool, designing an algorithm, embedded or hardware/software co-design, networks and distributed systems, security, data platforms, and applications of AI/ML. When ML is a main component, use `ml-cv-checklist.md` as well. Skip items that do not apply. Log every hit with section, page and severity.

## Problem and requirements
- The problem, users or stakeholders and context are clear; the project is not a solution looking for a problem.
- Requirements stated (functional and non-functional: performance, reliability, security, privacy, usability), ideally prioritised and **measurable**.
- Success criteria defined before evaluation, and traceable from requirements to tests and results.
- Scope realistic for the level and time available; limitations of scope acknowledged.

## Design
- Architecture described clearly (diagrams such as component, sequence, data-flow or C4) and justified against alternatives.
- Key design decisions recorded with reasons and trade-offs (technology choices, data model, protocols, algorithms).
- Security, privacy and data protection designed in where relevant (threat model, GDPR, access control), not bolted on.
- For algorithms: correctness argument and complexity analysis (time, space), with assumptions stated.

## Implementation
- Appropriate tools, languages and frameworks; third-party libraries, code and datasets credited with licences respected.
- Code quality evidenced: structure, version control, documentation, build and deployment instructions.
- The dissertation explains the non-obvious parts of the implementation, not a line-by-line code walkthrough.
- Amount and difficulty of the engineering work is visible (what the student built vs what was reused).

## Testing
- A test strategy, not just "it works": unit, integration and system tests; tests derived from requirements; edge cases and failure modes.
- Evidence of tests (results, coverage where meaningful), and bugs found and fixed.
- For hardware: test benches, measurement set-up, instruments and calibration described.

## Evaluation
- Evaluation answers the research questions or objectives and checks the requirements one by one.
- **Performance claims are measured**: latency, throughput, memory, energy or cost, on stated hardware and software versions, with repeated runs and variance, warm-up handled, realistic workloads.
- Fair baselines (existing tools, systems or algorithms) with the same configuration effort; scalability tested if claimed.
- **User studies** (usability, acceptance, HCI): clear protocol, representative participants and enough of them, validated instruments (e.g. SUS, NASA-TLX), ethics approval and consent, appropriate statistics; not only "a few friends liked it".
- **Security evaluation**: threat model, realistic attacks or penetration tests, responsible handling of vulnerabilities.
- Threats to validity discussed (internal, external, construct); results not over-generalised.

## Computer engineering and embedded systems
- Resource budgets on the target hardware: CPU or MCU load, memory, FPGA utilisation (LUTs, DSPs, BRAM), timing closure, power and energy actually measured.
- Real-time requirements (deadlines, jitter) tested under load; simulation results confirmed on hardware where it matters.
- Hardware/software partitioning justified; quantisation or approximation effects on accuracy reported for edge AI.

## Deployment and operations (when relevant)
- Deployment environment, configuration and monitoring described; reliability and failure handling considered.
- For ML systems in production: data drift, monitoring, retraining and rollback considered.

## Project process (common in BSc and MSc ICT projects)
- Method (e.g. agile, iterative, design science) described and actually followed; plan, risks and changes reflected on honestly.
- Process counts in proportion: it does not replace technical depth or evaluation.

## Literature (for criterion (b))
- Related research **and** related systems, products, tools and standards (IEEE, ISO, IETF RFCs, W3C) where relevant.
- Comparison of existing solutions on clear dimensions, leading to the gap or requirements this project addresses.

## Level expectations
- **BSc**: a working, well-tested system or study of sensible scope, clearly designed and honestly evaluated against its requirements.
- **MSc**: as BSc, plus a research question, justified design choices against the state of the art, rigorous measured evaluation and critical reflection.
- **PhD**: a novel contribution (algorithm, system, method or empirical finding) evaluated at the standard of top venues in the area (e.g. ACM/IEEE/USENIX conferences and journals).
