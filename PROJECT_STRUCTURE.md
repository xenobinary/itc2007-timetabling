# Project Structure

This repository is intentionally structured to support:
- a rule-based **expert system** (separate rule base from solver engine)
- reproducible experiments (scripts + results)
- academic deliverables (proposal/report/paper/presentation)

Top-level:
- `src/`: Prolog implementation
- `tests/`: automated tests
- `docs/`: writing deliverables
- `results/`: outputs and tables produced by runs
- `scripts/`: reproducible run/benchmark helpers
- `data/`: local datasets (not committed by default)
