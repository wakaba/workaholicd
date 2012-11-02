all:

# ------ Dependency ------

WGET = wget

Makefile-setupenv: Makefile.setupenv
	$(MAKE) --makefile Makefile.setupenv setupenv-update \
	    SETUPENV_MIN_REVISION=20120336

Makefile.setupenv:
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/Makefile.setupenv

pmbp-install pmbp-update \
generatepm: %: Makefile-setupenv
	$(MAKE) --makefile Makefile.setupenv $@

deps: git-submodules pmbp-install

# ------ Tests ------

GIT = git

git-submodules:
	$(GIT) submodule update --init

test-deps: deps

PROVE = ./prove

test: test-deps test-main

test-main:
	$(PROVE) t/*.t
