resources = gnome.compile_resources (meson.project_name(), 'taquin.gresource.xml')

executable(meson.project_name(),[
        'config.vapi',

        'about-list.vala',
        'adaptative-window.vala',
        'base-headerbar.vala',
        'base-view.vala',
        'base-window.vala',
        'game-headerbar.vala',
        'game-view.vala',
        'game-window.vala',
        'new-game-screen.vala',
        'night-light-monitor.vala',
        'notifications-revealer.vala',
        'overlayed-list.vala',
        'registry-placeholder.vala',
        'taquin-game.vala',
        'taquin-main.vala',
        'taquin-view.vala'
     ] + resources,
    install: true,
    c_args: [
        '-include', 'config.h'
    ],
    vala_args: [
        '--vapidir', join_paths(meson.current_source_dir(), 'vapi'),
        '--enable-experimental-non-null'
    ],
    dependencies: [
        glib_dependency,
        gtk_dependency,
        rsvg_dependency,
        canberra_dependency,
        canberra_gtk3_dependency,
        posix_dependency
    ]
)
