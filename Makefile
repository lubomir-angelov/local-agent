cat > Makefile <<'EOF'
.PHONY: fmt lint fix test test-fast ci

fmt:
	ruff format .

lint:
	ruff check .

fix:
	ruff check . --fix

test:
	pytest -q

test-fast:
	pytest -q --maxfail=1

ci: lint test
EOF
