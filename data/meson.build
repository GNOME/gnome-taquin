install_data(
    [
        'gameover.ogg',
        'sliding-1.ogg',
        'sliding-n.ogg'    
    ],
    install_dir: soundsdir
)

# Desktop file
desktop_file = i18n.merge_file(
    input: '@0@.desktop.in'.format(project_id),
    output: '@0@.desktop'.format(project_id),
    po_dir: join_paths(meson.source_root(), 'po'),
    type: 'desktop',
    install: true,
    install_dir: join_paths(get_option('datadir'), 'applications')
)

# Validate desktop file
if desktop_file_validate.found()
  test(
    'validate-desktop',
    desktop_file_validate,
    args: [
      desktop_file.full_path()
    ]
  )
endif

# AppData file
appdata_file = i18n.merge_file(
    input: '@0@.appdata.xml.in'.format(application_id),
    output: '@0@.appdata.xml'.format(application_id),
    po_dir: join_paths(meson.source_root(), 'po'),
    install: true,
    install_dir: join_paths(get_option('datadir'), 'metainfo')
)

# Validate AppData file
if appstream_util.found()
  test(
    'validate-appdata', appstream_util,
    args: [
      'validate-relax', '--nonet', appdata_file.full_path()
    ]
  )
endif

install_man('@0@.6'.format(meson.project_name()))

subdir('icons')
subdir('themes')