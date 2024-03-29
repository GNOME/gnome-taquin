project('gnome-taquin', 'vala', 'c',
    version: '3.38.1', meson_version: '>= 0.59.0',)

project_id = 'org.gnome.Taquin'

# used to install help
gnome = import('gnome')
# used for internationalization
i18n = import('i18n')
# used to run post install script
python3 = import('python3')

cc = meson.get_compiler('c')
valac = meson.get_compiler('vala')

gio_dependency = dependency('gio-2.0', version: '>= 2.42.0')
glib_dependency = dependency('glib-2.0', version: '>= 2.42.0')
gsound_dependency = dependency('gsound', version: '>= 1.0.2')
gtk_dependency = dependency('gtk+-3.0', version: '>= 3.24.0')
libm_dependency = cc.find_library('m', required: false) # some platforms do not have libm separated from libc
posix_dependency = valac.find_library('posix')
rsvg_dependency = dependency('librsvg-2.0', version: '>= 2.32.0')

desktop_file_validate = find_program('desktop-file-validate', required: false)
appstream_util = find_program('appstream-util', required: false)
glib_compile_schema = find_program('glib-compile-schemas', required: true)

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language: 'c')

localedir   = join_paths(get_option('prefix'), get_option('localedir'))
datadir     = join_paths(get_option('prefix'), get_option('datadir'))
bindir      = join_paths(get_option('prefix'), get_option('bindir'))
pkgdatadir  = join_paths(datadir, meson.project_name())
soundsdir   = join_paths(pkgdatadir, 'sounds')

conf = configuration_data ()
conf.set_quoted('VERSION', meson.project_version())
conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('SOUND_DIRECTORY', soundsdir)
conf.set_quoted('LOCALEDIR', localedir)
conf.set_quoted('DATA_DIRECTORY', pkgdatadir)

configure_file(output: 'config.h', configuration: conf)
config_h_dir = include_directories('.')

subdir('data')
subdir('help')
subdir('po')
subdir('src')

gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
  update_desktop_database: true,
)
