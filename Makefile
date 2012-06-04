all:

# ------ Dependency ------

WGET = wget
PERL = perl
PERL_VERSION = latest
PERL_PATH = $(abspath local/perlbrew/perls/perl-$(PERL_VERSION)/bin)
REMOTEDEV_HOST = remotedev.host.example
REMOTEDEV_PERL_VERSION = $(PERL_VERSION)

PMB_PMTAR_REPO_URL = 
PMB_PMPP_REPO_URL = 

Makefile-setupenv: Makefile.setupenv
	$(MAKE) --makefile Makefile.setupenv setupenv-update \
	    SETUPENV_MIN_REVISION=20120336

Makefile.setupenv:
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/Makefile.setupenv

local-perl perl-version perl-exec \
local-submodules config/perl/libs.txt \
carton-install carton-update carton-install-module \
remotedev-test remotedev-reset remotedev-reset-setupenv \
pmb-install pmb-update pmb-Makefile.PL cinnamon \
generatepm: %: Makefile-setupenv
	$(MAKE) --makefile Makefile.setupenv $@ \
            REMOTEDEV_HOST=$(REMOTEDEV_HOST) \
            REMOTEDEV_PERL_VERSION=$(REMOTEDEV_PERL_VERSION) \
	    PMB_PMTAR_REPO_URL=$(PMB_PMTAR_REPO_URL) \
	    PMB_PMPP_REPO_URL=$(PMB_PMPP_REPO_URL)

# ------ Tests ------

GIT = git

git-submodules:
	$(GIT) submodule update --init

test-deps: git-submodules pmb-install

PERL_ENV = PATH=$(PERL_PATH):$(PATH) PERL5LIB=$(shell cat config/perl/libs.txt)
PROVE = prove

test: test-deps test-main

test-main:
	$(PERL_ENV) $(PROVE) t/*.t
