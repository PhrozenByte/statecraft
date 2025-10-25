# StateCraft
# A CLI tool to create complex directory structures via scripts on Linux.
#
# StateCraft is a CLI tool for creating Linux directory trees via scripts.
# It supports mounting snapshots, creating files, archives, and more.
# Designed for admins seeking flexible, scriptable backup setups.
#
# Copyright (C) 2025  Daniel Rudolf <https://www.daniel-rudolf.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 3 of the License only.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# License: GNU General Public License <https://opensource.org/license/gpl-3-0>
# SPDX-License-Identifier: GPL-3.0-only

SHELL = /bin/sh

INSTALL ?= install
INSTALL_PROGRAM ?= $(INSTALL)
INSTALL_DATA ?= $(INSTALL) -m644

srcdir ?= .
prefix ?= /usr/local
exec_prefix ?= $(prefix)

bindir ?= $(exec_prefix)/bin
libdir ?= $(exec_prefix)/lib/statecraft
datarootdir ?= $(prefix)/share
docdir ?= $(datarootdir)/doc/statecraft
licensedir ?= $(datarootdir)/licenses/statecraft

.PHONY: all install uninstall clean

all:
	@echo "Nothing to build."

install:
	$(INSTALL) -d "$(DESTDIR)$(bindir)"
	$(INSTALL_PROGRAM) -D "$(srcdir)/src/bin/statecraft" "$(DESTDIR)$(bindir)/statecraft"
	
	$(INSTALL) -d "$(DESTDIR)$(libdir)"
	(cd "$(srcdir)/src/lib/statecraft"; find -type d -print0) | xargs -t -0 -I{} \
		$(INSTALL) -d "$(DESTDIR)$(libdir)/{}"
	(cd "$(srcdir)/src/lib/statecraft"; find -type f -print0) | xargs -t -0 -I{} \
		$(INSTALL_DATA) "$(srcdir)/src/lib/statecraft/{}" "$(DESTDIR)$(libdir)/{}"
	
	$(INSTALL) -d "$(DESTDIR)$(docdir)" "$(DESTDIR)$(licensedir)"
	$(INSTALL_DATA) -D "$(srcdir)/README.md" "$(DESTDIR)$(docdir)/README.md"
	$(INSTALL_DATA) -D "$(srcdir)/LICENSE" "$(DESTDIR)$(licensedir)/LICENSE"

uninstall:
	rm -f "$(DESTDIR)$(bindir)/statecraft"
	rm -rf "$(DESTDIR)$(libdir)"
	rm -rf "$(DESTDIR)$(docdir)" "$(DESTDIR)$(licensedir)"

clean:
	@echo "Nothing to clean."
