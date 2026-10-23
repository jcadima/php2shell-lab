.PHONY: preflight demo patched verify leak logs down

preflight:
	./scripts/preflight.sh

demo:
	./scripts/run-demo.sh

patched:
	./scripts/run-patched.sh

verify:
	./scripts/run-demo.sh
	./scripts/run-patched.sh

leak:
	python3 scripts/leak-only.py

logs:
	docker compose logs --tail=120 vuln

down:
	docker compose --profile patched down -v
