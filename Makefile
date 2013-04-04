PWD              = $(shell pwd)
RPMBUILD_OPTIONS = --define "_topdir $(PWD)/rpmbuild"
SPECTOOL_OPTIONS = --get-files --directory '$(PWD)/rpmbuild/SOURCES'


# TARGET: help            Print this information
.PHONY: help
help:
	# Usage:
	#   make <target>
	#
	# Targets:
	@egrep "^# TARGET:" [Mm]akefile | sed 's/^# TARGET:\s*/#   /'


# TARGET: setup           Setup rpmbuild directories
.PHONY: setup
setup:
	@mkdir -p -m 755 ./rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SRPMS}
	@mkdir -p -m 755 ./rpmbuild/RPMS/noarch


# TARGET: drupal6-update  Update/add all Drupal 6 packages
.PHONY: drupal6-update
drupal6-update:
	./bin/assert-pkgs.sh $(shell ./bin/fedora-pkgdb-grep.py drupal6)


# TARGET: drupal7-update  Update/add all Drupal 7 packages
.PHONY: drupal7-update
drupal7-update:
	./bin/assert-pkgs.sh $(shell ./bin/fedora-pkgdb-grep.py drupal7)


# TARGET: php-update      Update/add all PHP packages
.PHONY: php-update
php-update: setup
	./bin/assert-pkgs.sh $(shell ./bin/fedora-pkgdb-grep.py php)


# TARGET: update          Update/add all packages
.PHONY: update
update: drupal6-update drupal7-update php-update


# TARGET: clean           Delete any temporary or generated files
.PHONY: clean
clean:
	rm -rf ./rpmbuild
	find . -name '*~' -delete
	find . -name '*.gz' -delete
	find . -name '*.tgz' -delete
	find . -name '*.rpm' -delete
