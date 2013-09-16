# Stronghold

TODO: Command line client and gem to access the stronghold configuration store

## Installation

Add this line to your application's Gemfile:

    gem 'stronghold'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install stronghold

## Usage

```sh
stronghold-cli (--app my-server|--path /app/data) --get /data/path ...
stronghold-cli [--url stronghold:port] (--app my-server|--path /app/data) --env /data/path:PATHDATA ... -- runnable
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
