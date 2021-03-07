project('kmwriter', ['vala', 'c'],
  version: '0.0.1'
)

example_deps = [ dependency('gtk+-3.0'), dependency('gtksourceview-3.0'), ]

executable(
    'kmwriter',
    'src/KMWriter.vala',
    dependencies: example_deps,
    install: false
)