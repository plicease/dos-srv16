BINDIR := root/bin
EXTRA_REPOS := tico-edit/tico16

.PHONY: fetch

# Download the .exe assets from the latest release of each non-fork
# dos-*16 repo (and EXTRA_REPOS) into $(BINDIR).  Assets whose sha256 matches the
# local copy are skipped.
fetch:
	@mkdir -p $(BINDIR)
	@set -e; \
	repos="$$(gh repo list plicease --source --limit 1000 --json name -q '.[].name' \
	          | grep -E '^dos-.*16$$' | grep -vx 'dos-srv16' \
	          | sed 's|^|plicease/|') $(EXTRA_REPOS)"; \
	for repo in $$repos; do \
	  assets="$$(gh api repos/$$repo/releases/latest \
	             --jq '.assets[] | select(.name | test("\\.exe$$"; "i")) | "\(.name) \(.digest // "") \(.browser_download_url)"' \
	             2>/dev/null)" || { echo "$$repo: no release, skipping"; continue; }; \
	  [ -n "$$assets" ] || { echo "$$repo: no .exe assets"; continue; }; \
	  echo "$$assets" | while read -r name digest url; do \
	    dest="$(BINDIR)/$$name"; \
	    if [ -f "$$dest" ] && [ -n "$$digest" ] && \
	       [ "sha256:$$(sha256sum "$$dest" | cut -d' ' -f1)" = "$$digest" ]; then \
	      echo "$$repo: $$name up to date"; \
	      continue; \
	    fi; \
	    echo "$$repo: fetching $$name"; \
	    curl -fsSL -o "$$dest.tmp" "$$url"; \
	    mv "$$dest.tmp" "$$dest"; \
	  done; \
	done
