# Builds the app binaries. Every target delegates to scripts/make.sh, which
# documents the settings, e.g. `make android MODE=debug`.
#
#   make           build the web app
#   make web       roborules_app/build/web/
#   make clean     flutter clean

# One build time for every target in a run, so they share a version (see
# scripts/version.sh).
ifndef BUILD_NUMBER
BUILD_NUMBER := $(shell date -u +%s)
endif

export MODE WEB_BASE_HREF API_BASE_URL BUILD_NUMBER VERSION_Z

.PHONY: all web clean

all web clean:
	@bash scripts/make.sh $@
