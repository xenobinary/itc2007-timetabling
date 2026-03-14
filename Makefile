.PHONY: test run lint format

# Default example instance/output
INSTANCE ?= data/itc2007/comp01.ctt
OUT ?= results/comp01.sol

run:
	@mkdir -p results
	swipl -q -g "[src/main], main(['--instance','$(INSTANCE)','--out','$(OUT)'])" -t halt

test:
	swipl -q -g "[tests/test_runner]" -t halt

validate:
	@# Usage: make validate INSTANCE=... SOL=...
	swipl -q -g "[src/validate], main(['--instance','$(INSTANCE)','--solution','$(SOL)'])" -t halt

lint:
	@echo "No linter configured (optional)."

format:
	@echo "Prolog formatting: consider swipl formatter or editor settings."
