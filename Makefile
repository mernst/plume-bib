# Put user-specific changes in your own Makefile.user.
# Make will silently continue if that file does not exist.
-include Makefile.user

BIB_ABBREVIATE ?= ./bib-abbreviate.pl

GENERATED_FILES = bibstring-unabbrev.bib bibstring-abbrev.bib crossrefs-abbrev.bib bibroot bibtest.tex

# TODO: reinstate bibstring-crossrefs-abbrev.bib
all: ${GENERATED_FILES} style-check

BIBFILES := $(shell ls *.bib | grep -v bibstring-unabbrev.bib | grep -v bibstring-abbrev.bib)

clean: bibtest-aux-clean
	rm -f bibstring-unabbrev.bib bibstring-abbrev.bib bibroot bibtest.tex

bibstring-unabbrev.bib: bibstring-master.bib $(BIB_ABBREVIATE)
	@rm -f $@
	$(BIB_ABBREVIATE) $< > $@
	@chmod oga-w $@

bibstring-abbrev.bib: bibstring-master.bib $(BIB_ABBREVIATE)
	@rm -f $@
	$(BIB_ABBREVIATE) -abbrev $< > $@
	@chmod oga-w $@

crossrefs-abbrev.bib: crossrefs.bib $(BIB_ABBREVIATE)
	@rm -f $@
	$(BIB_ABBREVIATE) -abbrev $< > $@
	perl -pi -e 's/(^\s*(book)?title\s*=\s*\".*?)(\s+'\''?[0-9]+)?(:|\s*---)\s.*(\",$$)/\1\5/' $@
	perl -pi -e 's/(^\s*(book)?title\s*=\s*\"[A-Za-z]*)(\s+'\''?[0-9]+)?,\s.*(\",$$)/\1\4/' $@
	perl -pi -e 's/(^\s*address\s*=\s*\".*\",?\n)//' $@
	@chmod oga-w $@

## TODO: write a new abbreviaton script, only for [book]titles
# bibstring-crossrefs-abbrev.bib: bibstring-crossrefs-master.bib $(BIB_ABBREVIATE)
# 	@rm -f $@
# 	$(BIB_TITLE_ABBREVIATE) -abbrev $< > $@
# 	@chmod oga-w $@

bibroot: *.bib
	@ls -1 *.bib | perl -p -e 'BEGIN { print "% File for finding bibliography items with the lookup program.\n\n"; } if (/^bibstring/ || /^crossrefs/) { $$_=""; next; }; s:^(.*)$$:\\include{$$1}:;' > $@.new
	if cmp -s $@ $@.new ; then \
	  rm -f $@.new; \
	else \
	  mv -f $@.new $@; \
	  chmod oga-w $@; \
	fi

bibtest-aux-clean:
	rm -f bibtest.aux bibtest.bbl bibtest.blg bibtest.dvi bibtest.log

# bibtest.tex lists all the files and contains "\nocite{*}"
bibtest.tex: *.bib
	ls -1 *.bib | perl -p -e 'BEGIN { print "\\documentclass{report}\n\\usepackage{url}\n\\usepackage{fullpage}\n\\usepackage{relsize}\n\\begin{document}\\hbadness=10000\n\n\\bibliographystyle{alpha}\n\\nocite{*}\n\n\\bibliography{bibstring-unabbrev,crossrefs"; } END { print "}\n\n\\end{document}\n"; } if (/^bibstring/ || /^crossrefs/) { $$_=""; next; }; s:^(.*)\.bib\n:,$$1:;' > $@.new
	if cmp -s $@ $@.new ; then \
	  rm -f $@.new; \
	else \
	  mv -f $@.new $@; \
	  chmod oga-w $@; \
	fi

# Before doing this, run bibtex-validate-globally
# I'm not sure why this doesn't work (so for now do it by hand):
#   emacs -batch -l bibtex --eval="(progn (setq bibtex-files '(bibtex-file-path) enable-local-eval t) (bibtex-validate-globally))"
test bibtest: bibtest.pdf
bibtest.pdf: ${GENERATED_FILES} bibtest.tex
	@echo -n 'First pdflatex run, suppressing warnings...'
	@-pdflatex -interaction=nonstopmode bibtest >/dev/null 2>&1
	@echo 'done'
	@echo
	@echo "bibtex bibtest"
	@bibtex -terse -min-crossrefs=9999 bibtest 2>&1 | grep -v "Warning--to sort, need editor, organization" | grep -v "Warning--empty note in EWD:EWD303" | grep -v "Warning--empty author in IR95:tr" | grep -v "Warning--empty publisher in LindholmBBY:JVMS3" | grep -v "Warning--empty year in LindholmBBY:JVMS3"
	@echo
	@echo -n 'Second pdflatex run, suppressing warnings...'
	@-pdflatex -interaction=nonstopmode bibtest >/dev/null 2>&1
	@echo 'done'
	@echo
	@echo 'Third pdflatex run, now warnings matter:'
	pdflatex -interaction=nonstopmode bibtest
# This doesn't work.  I don't want non-ASCII characters within used fields of
# bib entries, but elsewhere in the file, and in the authorASCII field, is OK.
# chartest:
# 	grep -P "[\x80-\xFF]" *.bib

PUBS_SRC ?= /afs/csail.mit.edu/group/pag/www/pubs-src

# Make a version of the bibliography web pages, based on your working copy,
# in the subdirectory webtest. If it looks good, you can regenerate the
# real version by doing a "make" in $pag/www/pubs, or wait for an automatic
# update that currently happens once a month.
# You must have the Daikon scripts directory in your path, to find the
# html-update-toc command.
webtest: all
	mkdir -p webtest
	rsync -rC $(PUBS_SRC)/ webtest
	$(MAKE) -C webtest -f $(PUBS_SRC)/Makefile-pubs BIBDIR=`pwd`

tags: TAGS

TAGS: ${BIBFILES}
	etags ${BIBFILES}

showvars::
	@echo "BIBFILES = ${BIBFILES}"

# Code style; defines `style-check` and `style-fix`.
ifeq (,$(wildcard .plume-scripts))
dummy := $(git clone -q https://github.com/plume-lib/plume-scripts.git .plume-scripts)
endif
include .plume-scripts/code-style.mak
