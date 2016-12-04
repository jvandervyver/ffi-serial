Gem::Specification.new do |s|
  s.name = 'ffi-serial'
  s.version = '1.0.4'
  s.platform = Gem::Platform::RUBY
  s.has_rdoc = true
  s.extra_rdoc_files = ['LICENSE'] + Dir['doc/*.rdoc']
  s.rdoc_options += ['--quiet', '--line-numbers', '--inline-source', '--title', 'FFI Serial', '--main', 'README.rdoc']
  s.summary = 'FFI Serial'
  s.description = 'Yet another Ruby Serial Port implementation using FFI. Returns a Ruby IO object configured as a serial port to leverage the extensive Ruby IO standard library functionality'
  s.author = 'Johan van der Vyver'
  s.email = 'code@johan.vdvyver.com'
  s.license = 'MIT'
  s.required_ruby_version = '>= 1.9.3'
  s.files = ['LICENSE', 'README.md' ] + Dir['lib/**/*.rb'] + Dir['doc/**/*.{rdoc,txt}']
  s.add_runtime_dependency 'ffi', '~> 1.9', '>= 1.9.3'
end