# Demo Script (Presenter Notes)

1. Show repo layout and explain rule-based separation.
2. Run unit tests: `make test`.
3. Run mini instance: `make run INSTANCE=tests/fixtures/mini.ctt OUT=results/mini.sol`.
4. Optionally show CLPFD run: `make run-clpfd INSTANCE=tests/fixtures/mini.ctt OUT=results/mini-clpfd.sol TIMEOUT=30`.
5. Optionally show full-dataset command: `make run-all-constructive INST_DIR=data/itc2007 OUT_DIR=results/constructive-batch TIMEOUT=120`.
6. Explain constraints checked + how penalty will be improved.
