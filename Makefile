.PHONY: test run run-constructive run-clpfd run-all-constructive run-all-clpfd

# Default example instance/output
INSTANCE ?= data/itc2007/comp01.ctt
OUT ?= results/comp01.sol
CSV ?=
SEED ?= 0
TIMELIMIT ?= 30
TIMEOUT ?= 120
INST_DIR ?= data/itc2007
OUT_DIR ?= results/batch


run: run-constructive

run-constructive:
	@mkdir -p results
	timeout "$(TIMEOUT)s" swipl -q -g "['src/main'], main(['--instance','$(INSTANCE)','--out','$(OUT)','--csv','$(CSV)','--solver','constructive','--seed','$(SEED)','--timelimit','$(TIMELIMIT)'])" -t halt

run-clpfd:
	@mkdir -p results
	timeout "$(TIMEOUT)s" swipl -q -g "['src/main'], main(['--instance','$(INSTANCE)','--out','$(OUT)','--csv','$(CSV)','--solver','clpfd','--seed','$(SEED)','--timelimit','$(TIMELIMIT)'])" -t halt

run-all-constructive:
	@mkdir -p "$(OUT_DIR)"
	@printf 'instance,status,exit_code\n' > "$(OUT_DIR)/summary.csv"
	@for f in "$(INST_DIR)"/*.ctt; do \
		[ -e "$$f" ] || { echo "No .ctt files found in $(INST_DIR)"; exit 1; }; \
		base=$$(basename "$$f" .ctt); \
		out="$(OUT_DIR)/$$base.sol"; \
		csv="$(OUT_DIR)/$$base.csv"; \
		if timeout "$(TIMEOUT)s" swipl -q -g "['src/main'], main(['--instance','$$f','--out','$$out','--csv','$$csv','--solver','constructive','--seed','$(SEED)','--timelimit','$(TIMELIMIT)'])" -t halt; then \
			code=0; status=ok; \
		else \
			code=$$?; \
			if [ "$$code" -eq 124 ]; then status=timeout; else status=failed; fi; \
		fi; \
		printf '%s,%s,%s\n' "$$base" "$$status" "$$code" >> "$(OUT_DIR)/summary.csv"; \
	done

run-all-clpfd:
	@mkdir -p "$(OUT_DIR)"
	@printf 'instance,status,exit_code\n' > "$(OUT_DIR)/summary.csv"
	@for f in "$(INST_DIR)"/*.ctt; do \
		[ -e "$$f" ] || { echo "No .ctt files found in $(INST_DIR)"; exit 1; }; \
		base=$$(basename "$$f" .ctt); \
		out="$(OUT_DIR)/$$base.sol"; \
		csv="$(OUT_DIR)/$$base.csv"; \
		if timeout "$(TIMEOUT)s" swipl -q -g "['src/main'], main(['--instance','$$f','--out','$$out','--csv','$$csv','--solver','clpfd','--seed','$(SEED)','--timelimit','$(TIMELIMIT)'])" -t halt; then \
			code=0; status=ok; \
		else \
			code=$$?; \
			if [ "$$code" -eq 124 ]; then status=timeout; else status=failed; fi; \
		fi; \
		printf '%s,%s,%s\n' "$$base" "$$status" "$$code" >> "$(OUT_DIR)/summary.csv"; \
	done

test:
	swipl -q -g "[tests/test_runner]" -t halt
