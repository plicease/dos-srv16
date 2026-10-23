BINDIR := root/bin
EXTRA_REPOS := tico-edit/tico16

.PHONY: help fetch checksum

help:
	@echo "Targets:"
	@echo "  help      show this message (default)"
	@echo "  fetch     download latest release .exe files into $(BINDIR)"
	@echo "  checksum  write md5sum and crcsum files in root and each subdirectory"

# Download the .exe assets from the latest release of each non-fork
# dos-*16 repo (and EXTRA_REPOS) into $(BINDIR).  Assets whose sha256
# matches the local copy are skipped.
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

# Write md5sum and crcsum files in root and each of its subdirectories
# covering the regular files there, excluding the md5sum and crcsum files.
checksum:
	@find root -type d | while read -r dir; do \
	  files="$$(cd "$$dir" && find . -maxdepth 1 -type f \
	            ! -name md5sum ! -name crcsum | sed 's|^\./||' | LC_ALL=C sort)"; \
	  [ -n "$$files" ] || continue; \
	  echo "$$dir/md5sum $$dir/crcsum"; \
	  (cd "$$dir" && md5sum $$files > md5sum && crcsum $$files > crcsum); \
	done
