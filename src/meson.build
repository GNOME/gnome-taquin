resources = gnome.compile_resources (meson.project_name(), 'taquin.gresource.xml')

executable(meson.project_name(),[
        'config.vapi',
        'game-window.vala',
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
        glib_dependency,
        gtk_dependency,
        rsvg_dependency,
        canberra_depenency,
        canberra_gtk3_depenency,
        posix_dependency
    ]
)
