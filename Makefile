# Shortcuts. Everything here is also runnable directly (see the scripts).
.PHONY: help test build install uninstall icon clean dist hooks lint structure check version

help:        ## list targets
	@grep -E '^[a-z-]+:.*##' Makefile | sed 's/:.*##/	/'

version:     ## print the release number (the VERSION file)
	@cat VERSION

test:        ## unit tests only (swift test)
	swift test

lint:        ## shellcheck on every shell script
	shellcheck -S warning ./*.sh scripts/*.sh

structure:   ## confirm dangerous code (process, network, admin) sits only in its named files
	./scripts/check-structure.sh

check:       ## what CI runs: shellcheck, the structure guard and unit tests
	$(MAKE) lint
	$(MAKE) structure
	swift test

build:       ## tests, universal build, sign, dist/TBPK-<version>.dmg and its .sha256
	./build.sh

install:     ## install the newest dist/TBPK-*.dmg (or: make install V=1.0.1)
	./install.sh $(V)

uninstall:   ## remove the app and everything it changed
	./uninstall.sh

hooks:       ## install the git hooks in this clone (needs: brew install pre-commit gitleaks)
	pre-commit install

icon:        ## regenerate Resources/AppIcon.icns (only when the artwork changes)
	./scripts/build-icon.sh

clean:       ## remove build/, .build/ and dist/
	rm -rf build .build dist

dist:        ## list the dmgs in dist/
	@ls -1 dist/TBPK-*.dmg
