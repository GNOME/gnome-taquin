project('gnome-taquin', 'vala', 'c',
    version: '3.31.90')

project_id = 'org.gnome.Taquin'

gnome = import('gnome')
i18n = import('i18n')
python3 = import('python3')

gio_dependency = dependency('gio-2.0', version: '>= 2.40.0')
glib_dependency = dependency('glib-2.0', version: '>= 2.40.0')
gtk_dependency = dependency('gtk+-3.0', version: '>= 3.22.23')
rsvg_dependency = dependency('librsvg-2.0', version: '>= 2.32.0')
canberra_dependency = dependency('libcanberra')
canberra_gtk3_dependency = dependency('libcanberra-gtk3', version: '>= 0.26')
posix_dependency = meson.get_compiler('vala').find_library('posix')

desktop_file_validate = find_program('desktop-file-validate', required: false)
appstream_util = find_program('appstream-util', required: false)
glib_compile_schema = find_program('glib-compile-schemas', required: true)

add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()), language: 'c')

pkgdatadir = join_paths(get_option('prefix'), get_option('datadir'), meson.project_name())
localedir = join_paths(get_option('prefix'), get_option('localedir'))
soundsdir = join_paths(pkgdatadir, 'sounds')

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

meson.add_install_script(python3.find_python().path(), join_paths(meson.source_root(),
                                                                  'build-aux',
                                                                  'meson_post_install.py'))
