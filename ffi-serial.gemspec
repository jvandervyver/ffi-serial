Gem::Specification.new do |s|
  s.name = 'ffi-serial'
  s.version = '1.0.5'
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ['LICENSE'] + Dir['doc/*.rdoc']
  s.rdoc_options += ['--quiet', '--line-numbers', '--inline-source', '--title', 'FFI Serial', '--main', 'README.rdoc']
  s.summary = 'FFI Serial'
  s.description = 'Ruby Serial port library that uses Ruby standard library IO to open a connection to a serial port. Then configures the port using FFI'
  s.author = 'Johan van der Vyver'
  s.email = 'code@johan.vdvyver.com'
  s.homepage = 'https://github.com/jovandervyver/ffi-serial'
  s.license = 'MIT'
  s.required_ruby_version = '>= 1.9.3'
  s.files = ['LICENSE', 'README.md' ] + Dir['lib/**/*.rb'] + Dir['doc/**/*.{rdoc,txt}']
  s.add_runtime_dependency 'ffi', '~> 1.9', '>= 1.9.3'
end