VIRTUALENV=$(shell echo "$${VDIR:-'.env'}")

all: $(VIRTUALENV)

.PHONY: help
# target: help - Display callable targets
help:
	@egrep "^# target:" [Mm]akefile

.PHONY: clean
# target: clean - Clean the repository
clean:
	@rm -rf build dist docs/_build *.deb
	find $(CURDIR)/$(MODULE) -name "*.pyc" -delete
	find $(CURDIR)/$(MODULE) -name "*.orig" -delete
	find $(CURDIR)/$(MODULE) -name "__pycache__" -delete

# ==============
#  Bump version
# ==============

.PHONY: release
VERSION?=minor
# target: release - Bump version
release:
	@pip install bumpversion
	@bumpversion $(VERSION)
	@git checkout master
	@git merge develop
	@git checkout develop
	@git push origin develop master
	@git push --tags

.PHONY: minor
minor: release

.PHONY: patch
patch:
	make release VERSION=patch

.PHONY: major
major:
	make release VERSION=major

# ===============
#  Build package
# ===============

.PHONY: register
# target: register - Register module on PyPi
register:
	@python setup.py register

.PHONY: upload
# target: upload - Upload module on PyPi
upload: clean
	@pip install twine wheel
	@python setup.py sdist upload
	@python setup.py bdist_wheel upload
	# @python setup.py sdist bdist_wheel
	# @twine upload dist/*

.PHONY: deb
BUILD=$(CURDIR)/build
TARGET=/opt/graphite/beacon
PACKAGE_POSTFIX?=
PACKAGE_VERSION?=$(shell git describe --tags `git rev-list master --tags --max-count=1`) 
PACKAGE_NAME="graphite-beacon"
PACKAGE_FULLNAME=$(PACKAGE_NAME)$(PACKAGE_POSTFIX)
PACKAGE_MAINTAINER="Kirill Klenov <horneds@gmail.com>"
PACKAGE_DESCRIPTION="Simple allerting system for Graphite metrics."
PACKAGE_URL=https://github.com/klen/graphite-beacon.git
deb: clean
	@mkdir -p $(BUILD)/etc/init $(BUILD)/$(TARGET)
	@cp -r $(CURDIR)/graphite_beacon debian/config.json $(BUILD)/$(TARGET)/.
	@cp $(CURDIR)/debian/upstart.conf $(BUILD)/etc/init/graphite-beacon.conf
	@fpm -s dir -t deb -a all \
	    -n $(PACKAGE_FULLNAME) \
	    -v $(PACKAGE_VERSION) \
	    -m $(PACKAGE_MAINTAINER) \
	    --directories $(TARGET) \
	    --description $(PACKAGE_DESCRIPTION) \
	    --url $(PACKAGE_URL) \
	    --license "Copyright (C) 2014 horneds@gmail.com." \
	    --deb-user root \
	    --deb-group root \
	    --config-files /etc/init/graphite-beacon.conf \
	    --config-files /opt/graphite/beacon/config.json \
	    --before-install $(CURDIR)/debian/before_install.sh \
	    --before-remove $(CURDIR)/debian/before_remove.sh \
	    --after-install $(CURDIR)/debian/after_install.sh \
	    -C $(CURDIR)/build \
	    -d "python2.7" \
	    opt etc
	for name in *.deb; do \
	    [ -f bintray ] && curl -T "$$name" -uklen:`cat bintray` https://api.bintray.com/content/klen/deb/graphite-beacon/all/$$name ; \
	done

# =============
#  Development
# =============

$(VIRTUALENV): requirements.txt
	@[ -d $(VIRTUALENV) ]	|| virtualenv --no-site-packages $(VIRTUALENV)
	@$(VIRTUALENV)/bin/pip install -r requirements.txt
	@touch $(VIRTUALENV)

$(VIRTUALENV)/bin/py.test: requirements-test.txt
	@$(VIRTUALENV)/bin/pip install -r requirements-test.txt
	@touch $(VIRTUALENV)/bin/py.test

.PHONY: run
# target: run - Run graphite-beacon
run: $(VIRTUALENV)
	@$(VIRTUALENV)/bin/pip install -r requirements-test.txt
	$(VIRTUALENV)/bin/python -m graphite_beacon.app --config=local.json

.PHONY: t
# target: t - Runs tests
t: $(VIRTUALENV)/bin/py.test
	py.test -xs tests.py
