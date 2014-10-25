SUBDIRS = \
	icons \
	themes

dist_noinst_DATA = \
	taquin-menus.ui \
	taquin.ui \
	taquin.css \
	schema-15.png \
	schema-16.png

desktopdir = $(datadir)/applications
desktop_in_files = gnome-taquin.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appdatadir = $(datadir)/appdata
appdata_in_files = gnome-taquin.appdata.xml.in
appdata_DATA = $(appdata_in_files:.xml.in=.xml)
@INTLTOOL_XML_RULE@

gsettings_SCHEMAS = org.gnome.taquin.gschema.xml
@GSETTINGS_RULES@

man_MANS = gnome-taquin.6

EXTRA_DIST = \
	$(appdata_in_files) \
	$(desktop_in_files) \
	$(gsettings_SCHEMAS) \
	$(man_MANS)

CLEANFILES = \
	$(appdata_DATA) \
	$(desktop_DATA)

check-local: $(appdata_DATA) $(desktop_DATA)
	$(APPDATA_VALIDATE) $(appdata_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

-include $(top_srcdir)/git.mk
