icons_sizes = ['16x16', '22x22', '24x24', '32x32', '48x48', '256x256']

iconsdir = join_paths(get_option('prefix'), get_option('datadir'), 'icons', 'hicolor')

foreach size: icons_sizes
    install_data(
        join_paths('hicolor', size, '@0@.png'.format(project_id)),
        install_dir: join_paths(iconsdir, size, 'apps')
    )
endforeach

install_data(
    join_paths('hicolor', 'symbolic', '@0@-symbolic.svg'.format(project_id)),
    install_dir: join_paths(iconsdir, 'symbolic', 'apps')
)