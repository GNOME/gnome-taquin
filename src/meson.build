# Tests
taquin_tests = executable(
    'taquin_tests',
    [
        'taquin-game.vala',
        'test-taquin.vala'
    ],
    dependencies : [
        gio_dependency
    ]
)
test('taquin-tests', taquin_tests)

# Application
resources = gnome.compile_resources (meson.project_name(), 'taquin.gresource.xml')

executable(meson.project_name(),[
        'about-list.vala',
        'adaptative-window.vala',
        'base-headerbar.vala',
        'base-view.vala',
        'base-window.vala',
        'game-actionbar.vala',
        'game-headerbar.vala',
        'game-view.vala',
        'game-window.vala',
        'history-button.vala',
        'new-game-screen.vala',
        'night-light-monitor.vala',
        'notifications-revealer.vala',
        'overlayed-list.vala',
        'registry-placeholder.vala',
        'taquin-game.vala',
        'taquin-main.vala',
        'taquin-view.vala',
        'vapi/config.vapi'
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
        gsound_dependency,
        gtk_dependency,
        libm_dependency,
        posix_dependency,
        rsvg_dependency
    ]
)
