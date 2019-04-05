DIST_NAME   ?= $(shell sed -ne 's/^name\s*=\s*//p' dist.ini )
MAIN_MODULE ?= $(shell sed -ne 's/^main_module\s*=\s*//p' dist.ini )
CARTON      ?= $(shell which carton 2>/dev/null || echo REQUIRE_CARTON )
CPANFILE    := $(wildcard cpanfile cpanfile.prerelease/*)

# Not sure how to use the .perl-version target before we have it
CPANFILE_SNAPSHOT := $(shell \
  PLENV_VERSION=$$( plenv which carton 2>&1 | grep '^  5' | tail -1 ); \
  [ -n "$$PLENV_VERSION" ] && plenv local $$PLENV_VERSION; \
  carton exec perl -MFile::Spec -E \
	'($$_) = grep { -e } map{ "$$_/../../cpanfile.snapshot" } \
		grep { m(/lib/perl5$$) } @INC; \
		say File::Spec->abs2rel($$_) if $$_' )

ifndef CPANFILE_SNAPSHOT
	CPANFILE_SNAPSHOT := .MAKE
endif

.PHONY : test readme help

# We want this as the first target in the file, so if no target is specified,
# this target will be run
help:
	@echo "The following make targets are recognized:"
	@echo " "
	@echo "clean     - Remove all build artifacts"
	@echo "help      - This message"
	@echo "readme    - Make the README.md file from the main module"
	@echo "realclean - Remove all build artifacts and carton related modules"
	@echo "release   - Use Dist::Zilla to build, test, and release module to GSG::PAN"
	@echo "test      - Run all tests"

test : $(CPANFILE_SNAPSHOT)
	@nice $(CARTON) exec prove -lfr t

readme: README.md

README.md: $(CPANFILE_SNAPSHOT) $(MAIN_MODULE) dist.ini
	pod2markdown $(MAIN_MODULE) ${CURDIR}/$@

# This target requires that you add 'requires "Devel::Cover";'
# to the cpanfile and then run "carton" to install it.
testcoverage : $(CPANFILE_SNAPSHOT)
	$(CARTON) exec -- cover -test -ignore . -select ^lib

$(CPANFILE_SNAPSHOT): .perl-version $(CPANFILE)
	$(CARTON) install

.perl-version:
	plenv local $$( plenv whence carton | grep '^5' | tail -1 )

clean:
	rm -rf cover_db
	dzil clean
	rm -rf .build

realclean: clean
	rm -rf local

release:
	$(CARTON) exec dzil release
	dzil clean


