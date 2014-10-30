bin_PROGRAMS = gnome-taquin

BUILT_SOURCES = taquin-resources.c

gnome_taquin_SOURCES = \
	taquin-main.vala \
	taquin-view.vala \
	taquin-game.vala \
	config.vapi \
	$(BUILT_SOURCES)

gnome_taquin_CFLAGS = \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATA_DIRECTORY=\"$(datadir)/gnome-taquin\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	-w \
	$(GNOME_TAQUIN_CFLAGS)

gnome_taquin_VALAFLAGS = \
	--pkg posix \
	--pkg gtk+-3.0 \
	--pkg librsvg-2.0 \
	--target-glib 2.40

gnome_taquin_LDADD = $(GNOME_TAQUIN_LIBS)

taquin-resources.c: $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies taquin.gresource.xml)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target=$@ --sourcedir=$(srcdir) --generate-source $<

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp \
	taquin-resources.c

-include $(top_srcdir)/git.mk
