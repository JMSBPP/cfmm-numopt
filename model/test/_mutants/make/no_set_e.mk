# TEST-09 mutant: a compound recipe line that does not declare `set -e`.
.PHONY: mutant-no-set-e
mutant-no-set-e:
	cd model; rc=0; for f in a b; do printf '%s\n' "$$f"; done; exit $$rc
