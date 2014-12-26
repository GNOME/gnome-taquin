SUBDIRS = \
	icons \
	themes

dist_noinst_DATA = \
	taquin-menus.ui \
	taquin.ui \
	taquin.css \
	schema-15.png \
	schema-16.png

soundsdir = $(datadir)/gnome-taquin/sounds
sounds_DATA = \
	sliding-1.ogg \
	sliding-n.ogg \
	gameover.ogg

desktopdir = $(datadir)/applications
desktop_in_files = gnome-taquin.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appstream_in_files = gnome-taquin.appdata.xml.in
appstream_XML = $(appstream_in_files:.xml.in=.xml)
@APPSTREAM_XML_RULES@
@INTLTOOL_XML_RULE@

gsettings_SCHEMAS = org.gnome.taquin.gschema.xml
@GSETTINGS_RULES@

man_MANS = gnome-taquin.6

EXTRA_DIST = \
	$(appstream_in_files) \
	$(desktop_in_files) \
	$(sounds_DATA) \
	$(gsettings_SCHEMAS) \
	$(man_MANS)

CLEANFILES = \
	$(appstream_XML) \
	$(desktop_DATA)

check-local: $(desktop_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

DISTCHECK_CONFIGURE_FLAGS = --enable-appdata-check

-include $(top_srcdir)/git.mk
