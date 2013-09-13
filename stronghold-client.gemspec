Gem::Specification.new do |s|
  s.name        = 'stronghold-client'
  s.version     = '0.0.1'
  s.date        = '2013-08-28'
  s.summary     = "Stronghold client"
  s.description = "Client for the stronghold configuration store"
  s.authors     = ["Daniel Waterworth", "Samuel Kleiner"]
  s.email       = 'sk@pusher.com'
  s.files       = ["lib/stronghold_client.rb","bin/stronghold-cli"]
  s.executables = ["stronghold-cli"]
  s.homepage    =
    'http://github.com/pusher/ruby-stronghold-client'
  s.license       = 'Not yet agreed'
  s.add_runtime_dependency 'excon'
end