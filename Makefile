.PHONY: test lint check flake-check format-check lint-nix update help hooks-test hooks-lint

FLAKE_CHECK ?= nix flake check --keep-going --show-trace --no-build --option warn-dirty false
NIX_FILES := $(shell find . \( -path './.git' -o -path './reference' -o -path './.direnv' -o -path './venv' -o -path './.venv' \) -prune -o -name '*.nix' -print)

# Default target
all: check

# Help target
help:
	@echo "Nix Configuration Management"
	@echo "============================"
	@echo "Available targets:"
	@echo "  make lint        - Run linters on configuration files"
	@echo "  make test        - Run all test suites"
	@echo "  make format-check - Check Nix syntax/formatting"
	@echo "  make flake-check - Evaluate flake outputs without building"
	@echo "  make check       - Run lint, tests, and flake evaluation"
	@echo "  make update  - Rebuild and apply system configuration"
	@echo "  make help    - Show this help message"
	@echo ""
	@echo "Hook-specific targets:"
	@echo "  make hooks-test  - Test Claude Code hooks only"
	@echo "  make hooks-lint  - Lint Claude Code hooks only"
	@echo ""
	@echo "The lint and test targets accept FILE= for specific file changes:"
	@echo "  make lint FILE=path/to/file"
	@echo "  make test FILE=path/to/file"

# Run all linters
lint:
	@# Check if FILE is a shell file in hooks directory
	@if [ -n "$(FILE)" ] && echo "$(FILE)" | grep -q "^home-manager/claude-code/hooks/.*\.sh$$"; then \
		echo "Shell file in hooks directory changed: $(FILE)"; \
		echo "Running lint on all hook files..."; \
		$(MAKE) hooks-lint; \
		$(MAKE) format-check; \
	elif [ -n "$(FILE)" ]; then \
		echo "File changed: $(FILE)"; \
		echo "Running standard linters..."; \
		$(MAKE) format-check; \
		$(MAKE) lint-nix; \
	else \
		$(MAKE) hooks-lint; \
		$(MAKE) format-check; \
		$(MAKE) lint-nix; \
	fi
	@echo "✅ All linting passed!"

lint-nix:
	@STATIX_CMD=statix; \
	if ! command -v statix >/dev/null 2>&1; then \
		STATIX_CMD="nix run nixpkgs#statix --"; \
	fi; \
	DEADNIX_CMD=deadnix; \
	if ! command -v deadnix >/dev/null 2>&1; then \
		DEADNIX_CMD="nix run nixpkgs#deadnix --"; \
	fi; \
	echo "Running statix..."; \
	$$STATIX_CMD check . || exit 1; \
	echo "Running deadnix..."; \
	$$DEADNIX_CMD --exclude ./reference . || exit 1

# Check Nix syntax/formatting without mutating files
format-check:
	@if [ -z "$(NIX_FILES)" ]; then \
		echo "No Nix files detected, skipping format check."; \
	else \
		echo "Checking Nix formatting/syntax..."; \
		FMT_CMD=""; \
		if command -v alejandra >/dev/null 2>&1; then \
			FMT_CMD="alejandra -c"; \
		elif command -v nixpkgs-fmt >/dev/null 2>&1; then \
			FMT_CMD="nixpkgs-fmt --check"; \
		else \
			FMT_CMD="nix run nixpkgs#alejandra -- -c"; \
		fi; \
		$$FMT_CMD $(NIX_FILES); \
	fi

# Run all tests
test:
	@# Check if FILE is a shell file in hooks directory
	@if [ -n "$(FILE)" ] && echo "$(FILE)" | grep -q "^home-manager/claude-code/hooks/.*\.sh$$"; then \
		echo "Shell file in hooks directory changed: $(FILE)"; \
		echo "Running tests on all hook files..."; \
		$(MAKE) hooks-test; \
	elif [ -n "$(FILE)" ]; then \
		echo "File changed: $(FILE)"; \
		echo "No specific tests for this file type"; \
	else \
		$(MAKE) hooks-test; \
	fi
	@echo "✅ All tests passed!"

# Evaluate the flake without building derivations
flake-check:
	@echo "Evaluating flake (no builds)..."
	@${FLAKE_CHECK}
	@echo "✅ Flake evaluation succeeded!"

# Run lint, tests, and flake evaluation
check: lint test flake-check

# Update system configuration
update:
	@echo "Rebuilding system configuration..."
	@if [ "$$(uname)" = "Darwin" ]; then \
		darwin-rebuild switch --flake ".#$$(hostname -s)" --option warn-dirty false; \
	else \
		sudo nixos-rebuild switch --flake ".#$$(hostname)" --option warn-dirty false; \
	fi

# Delegate to hooks Makefile
hooks-test:
	@if [ -f home-manager/claude-code/hooks/Makefile ]; then \
		$(MAKE) -C home-manager/claude-code/hooks test; \
	else \
		echo "No hook test target defined, skipping"; \
	fi

hooks-lint:
	@if [ -f home-manager/claude-code/hooks/Makefile ]; then \
		$(MAKE) -C home-manager/claude-code/hooks lint; \
	else \
		echo "No hook lint target defined, skipping"; \
	fi
