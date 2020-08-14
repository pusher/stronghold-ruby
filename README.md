# DEPRECATED
`stronghold-ruby` is officially deprecated and unmaintained.
It is recommended that users transition to alternatives.

# Stronghold

Command line client and gem for modifying and reading from the stronghold configuration store

## Using the command-line client, `stronghold-cli`

To install:

````bash
git clone git@github.com:pusher/stronghold-ruby.git
cd stronghold-ruby
gem build stronghold
gem install stronghold
````

To use:

````
stronghold-cli (--path /path/ |--app app | --list) [operation]
````

## Using the `stronghold` Ruby library

Add this line to your application's Gemfile:

````ruby
gem "stronghold", git: "git@github.com:pusher/stronghold-ruby.git", branch: "master"
````

And then execute:

````bash
bundle
````

### Stronghold path

The stronghold path is used for allowing environments, clusters, servers, and applications to inherit in a logical chain, like `/environment/cluster/server/application`

You can list existing paths with `--list`

For most applications, consider using files like `/etc/stronghold-cli.d/app`, which allow you to write to, and read from stronghold in a logical way.

### Data path

The data path is the path into the hash of variables on a specific level.
Generally your data path should only be one level deep, but for certain applications- e.g hostname and port combinations- it's sometimes useful to have constructs like

````json
{
        "best_messaging_service": "pusher",
        "connect_to": { "hostname": "ws.pusherapp.com", "port": 80}
}
````

In this case getting the data path `/connect_to/port` would return 80

### Operations:

- `--next [/data/path]`
  Wait for next stronghold change matched by optional data path and print

- `--get [/data/path]`
  Get data matched by data path from stronghold head and print

- `--history [/data/path]`
  Show the impact of the last 5 versions on this data path

- `--set /data/path:to_value`
  Set value of data path, creating hashes as we go. Use --force to overwrite

- `--env /data/path:PATHDATA ... -- runnable`
  Get data from stronghold head and put in environment variable, and run runnable

### Examples:

````bash
stronghold-cli --path / --env /environment:ENVIRONMENT -- bash -c "echo $ENVIRONMENT"
````

## API Usage Example

    # You can optionally pass a url for stronghold, defaults to "http://127.0.0.1:5040"
    stronghold = Stronghold::Client.new

    config = stronghold.head.tree.materialized('/foo/bar')

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
