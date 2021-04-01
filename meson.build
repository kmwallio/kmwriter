project('kmwriter', ['vala', 'c'],
  version: '0.0.1'
)

example_deps = [ dependency('gtk+-3.0'), dependency('gtksourceview-4'), dependency('gee-0.8') ]

executable(
    'kmwriter',
    'src/KMWriter.vala',
    'src/Helpers.vala',
    'src/Grammar.vala',
    'src/Markdown.vala',
    dependencies: example_deps,
    install: false
)