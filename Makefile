.PHONY: test lint check update help hooks-test hooks-lint

# Default target
all: check

# Help target
help:
	@echo "Nix Configuration Management"
	@echo "============================"
	@echo "Available targets:"
	@echo "  make lint    - Run linters on configuration files"
	@echo "  make test    - Run all test suites"
	@echo "  make check   - Run both lint and test"
	@echo "  make update  - Rebuild and apply system configuration"
	@echo "  make help    - Show this help message"
	@echo ""
	@echo "Hook-specific targets:"
	@echo "  make hooks-test  - Test Claude Code hooks only"
	@echo "  make hooks-lint  - Lint Claude Code hooks only"

# Run all linters
lint: hooks-lint
	@echo "Running Nix linters..."
	@if command -v statix >/dev/null 2>&1; then \
		echo "Running statix..."; \
		statix check . || exit 1; \
	fi
	@if command -v deadnix >/dev/null 2>&1; then \
		echo "Running deadnix..."; \
		deadnix . || exit 1; \
	fi
	@echo "✅ All linting passed!"

# Run all tests
test: hooks-test
	@echo "✅ All tests passed!"

# Run both lint and test
check: lint test

# Update system configuration
update:
	@echo "Rebuilding system configuration..."
	@if [ "$$(uname)" = "Darwin" ]; then \
		darwin-rebuild switch --flake ".#$$(hostname -s)"; \
	else \
		sudo nixos-rebuild switch --flake ".#$$(hostname)"; \
	fi

# Delegate to hooks Makefile
hooks-test:
	@$(MAKE) -C home-manager/claude-code/hooks test

hooks-lint:
	@$(MAKE) -C home-manager/claude-code/hooks lint