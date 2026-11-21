BINDIR := root/bin
# Extra repos to fetch from.  REPO takes every .exe and .com asset of its
# latest release; REPO:ASSET takes only the asset named ASSET (for repos
# whose releases also hold host programs, such as Windows installers).
EXTRA_REPOS := tico-edit/tico16 plicease/sprocket:sprocket.exe

.PHONY: help fetch checksum image

help:
	@echo "Targets:"
	@echo "  help      show this message (default)"
	@echo "  fetch     download latest release .exe and .com files into $(BINDIR)"
	@echo "  checksum  write md5sum and crcsum files in root and each subdirectory"
	@echo "  image     build srv.img from the contents of root"

# Download the .exe and .com assets from the latest release of each non-fork
# gr-dos/*16 repo (and EXTRA_REPOS) into $(BINDIR).  Assets whose sha256
# matches the local copy are skipped.
fetch:
	@mkdir -p $(BINDIR)
	@set -e; \
	repos="$$(gh repo list gr-dos --source --limit 1000 --json name -q '.[].name' \
	          | grep -E '16$$' \
	          | sed 's|^|gr-dos/|') $(EXTRA_REPOS)"; \
	for entry in $$repos; do \
	  repo="$${entry%%:*}"; \
	  case "$$entry" in \
	    *:*) want="$${entry#*:}"; \
	         select=".name == \"$$want\"";; \
	    *)   want=".exe or .com"; \
	         select='.name | test("\\.(exe|com)$$"; "i")';; \
	  esac; \
	  assets="$$(gh api repos/$$repo/releases/latest \
	             --jq ".assets[] | select($$select)"' | "\(.name) \(.digest // "") \(.browser_download_url)"' \
	             2>/dev/null)" || { echo "$$repo: no release, skipping"; continue; }; \
	  [ -n "$$assets" ] || { echo "$$repo: no $$want assets"; continue; }; \
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

image: srv.img

# Rebuilt when anything under root changes.  interloper refuses to
# overwrite, so build to a temporary name and move it into place.
srv.img: $(shell find root)
	@rm -f $@.tmp
	interloper image create $@.tmp root
	@mv $@.tmp $@
