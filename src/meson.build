resources = gnome.compile_resources (meson.project_name(), 'taquin.gresources.xml')

executable(meson.project_name(),[
        'config.vapi',
        'gnome-window.vala',
        'taquin-game.vala',
        'taquin-main.vala',
        'taquin-view.vala'
     ] + resources,
    install: true,
    c_args: [
        '-include', 'config.h'
    ],
    vala_args: [
        '--vapidir', join_paths(meson.current_source_dir(), 'vapi')
    ],
    dependencies: [
        gee_dependency,
        glib_dependency,
        gnome_games_support_dependency,
        gtk_dependency,
        posix_dependency,
        rsvg_dependency
    ]
)
