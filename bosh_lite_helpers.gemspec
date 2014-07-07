Gem::Specification.new do |s|
  s.name        = 'bosh_lite_helpers'
  s.version     = '0.1.0'
  s.licenses    = ['Apache']
  s.summary     = 'Basic wrapper around bosh-lite'
  s.description = s.summary
  s.authors     = ['Andrew Crump']
  s.email       = 'andrew@cloudcredo.com'
  s.files       = Dir['lib/**/**.rb']
  s.homepage    = 'https://github.com/cloudcredo/bosh_lite_helpers'
  s.add_runtime_dependency 'bosh_cli', '~> 1.2624'
end
