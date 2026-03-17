# Project Proposal — ITC2007 Course Timetabling Expert System

LaTeX version: see `docs/proposal/proposal.tex` (with `docs/proposal/refs.bib`).

## 1. Problem statement
Build a rule-based expert system in Prolog to generate course timetables using ITC2007 Track 2 datasets.

## 2. Objectives
- Parse `.ctt` instances and build an internal model.
- Enforce hard constraints (feasible timetable).
- Optimize soft constraints (minimize penalty).
- Provide reproducible benchmarking and reports.

## 3. Approach (high-level)
- Knowledge base: encode constraints as Prolog rules.
- Inference/solver: construct timetable using greedy heuristics with backtracking and validation.
- Validation: check hard constraints; compute penalty.

## 4. Deliverables
- Code, tests, benchmark results, proposal, report, paper, presentation.

## 5. Timeline
- Week 1: parser + model
- Week 2: hard constraints + feasibility checks
- Week 3: soft constraints + objective
- Week 4: search + benchmarks
- Week 5: write-up + slides

## 6. Risks & mitigations
- Dataset quirks → robust parser + unit tests.
- Search performance → incremental improvements, time limits, profiling.

## 7. Evaluation
- Feasibility rate across selected instances.
- Penalty vs baseline (simple greedy).
- Runtime per instance.
