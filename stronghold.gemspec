# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'stronghold/version'

Gem::Specification.new do |s|
  s.name          = "stronghold"
  s.version       = Stronghold::VERSION
  s.authors       = ["Daniel Waterworth","Samuel Kleiner"]
  s.email         = ["sk@pusher.com"]
  s.description   = "Stronghold client"
  s.summary       = "Client for the stronghold configuration store"
  s.homepage      = "https://github.com/pusher/stronghold-ruby"
  s.license       = "MIT"

  s.files         = `git ls-files`.split($/)
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|s|features)/})
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler", "~> 1.3"
  s.add_development_dependency "rake"

  s.add_runtime_dependency 'excon'
end
