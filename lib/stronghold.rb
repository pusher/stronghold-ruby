require 'excon'
require 'json'

module Stronghold
  class Path
    def self.valid(path)
      raise "path should start with a forward slash" unless path[0] == ?/ || path.empty?
      raise "path should not end with a forward slash" if path[-1] == ?/ && path != ?/
    end

    def self.cleanup(path)
      File.expand_path(path, '/').gsub(/\/+/, '/')
    end
  end

  class Tree
    attr_reader :version

    def initialize(client, version)
      @client = client
      @version = version
    end

    ##
    # List the paths that stronghold knows about
    def paths
      @client.get_json(
        path: "/#{version}/tree/paths",
        expects: 200,
        idempotent: true
      )
    end

    ##
    # Extracts the set variables from a particular path level.
    # This means variables set at that level, and none others
    # Generally this is not what you want, unless you are
    # writing an editor
    def peculiar(path)
      Stronghold::Path.valid(path)
      @client.get_json(
        path: "/#{version}/tree/peculiar#{path}",
        expects: 200,
        idempotent: true
      )
    end

    ##
    # Extracts the set variables for a path. This means variables
    # from this level of the path and all previous levels
    # superimposed in order of specialization (lower overrides higher)
    def materialized(path)
      Stronghold::Path.valid(path)
      @client.get_json(
        path: "/#{version}/tree/materialized#{path}",
        expects: 200,
        idempotent: true
      )
    end

    ##
    # Blocks until the materialized JSON for a particular path changes
    def next_materialized(path)
      Stronghold::Path.valid(path)
      result = @client.get_json(
        path: "/#{version}/next/tree/materialized#{path}",
        expects: 200,
        idempotent: true
      )
      {
        data: result["data"],
        version: Version.new(@client, result["revision"])
      }
    end
  end

  class ChangeSet
    def initialize(changes)
      @changes = changes
    end
  end

  class Update
    def initialize(options)
      @options = options
    end

    def author
      @options[:author]
    end

    def timestamp
      @options[:timestamp]
    end

    def comment
      @options[:comment]
    end

    def changeset
      @options[:changes]
    end
  end

  class Version
    attr_reader :version

    def initialize(client, version)
      @client = client
      @version = version
    end

    ##
    # Get the tree of data represented by this version
    def tree
      @tree ||= Tree.new(@client, @version)
    end

    ##
    # Get update data for a past change
    def change
      @change ||= begin
        options = @client.get_json(
          path: "/#{version}/change",
          expects: 200,
          idempotent: true
        )
        Update.new(
          author: options["author"],
          comment: options["comment"],
          timestamp: options["timestamp"],
          previous: Version.new(@client, options["previous"]),
          changes: ChangeSet.new(options["changes"])
        )
      end
    end

    ##
    # Update or create a new path
    def update(options)
      path, data, author, comment = options.values_at(:path, :data, :author, :comment)
      if [data, author, comment].compact.length != 3
        raise ArgumentError, "No null arguments allowed in options: #{options}"
      end
      Stronghold::Path.valid(path)
      version = @client.post(
        path: "/#{version}/update#{path}",
        body: JSON.generate(data: data, author: author, comment: comment),
        expects: 200,
        idempotent: true
      )
      Version.new(@client, version)
    end
  end

  class Versions
    def initialize(client)
      @client = client
    end

    def at(ts)
      raise ArgumentError, "expected a time" unless ts.kind_of?(Time)
      Version.new(@client, @client.get(
        path: '/versions',
        query: {at: ts.to_i},
        expects: 200,
        idempotent: true
      ))
    end

    def before(version, n)
      raise ArgumentError, "expected a Version" unless version.respond_to?(:version)
      @client.get_json(
        path: '/versions',
        query: {last: version.version, size: n},
        expects: 200,
        idempotent: true
      ).map { |x|
        Version.new(@client, x['revision'])
      }
    end
  end

  module Error; end
  class ConnectionError < StandardError
    include Error
  end

  module ResponseWrapper
    attr_reader :response

    def self.wrap(obj, response)
      obj.extend self
      obj.instance_variable_set(:@response, response)
      obj
    end
  end

  class Client
    attr_reader :connection

    ##
    # Connect to stronghold
    def initialize(uri = "http://127.0.0.1:5040")
      @connection = Excon.new(uri)
      unless get() == "Stronghold says hi"
        raise ConnectionError, "#{uri} is not stronghold"
      end
    end

    ##
    # Get the latest version, generally what you want
    def head
      Version.new(self, get(
        path: '/head',
        expects: 200,
        idempotent: true
      ))
    end

    def versions
      @versions ||= Versions.new(self)
    end

    def request(method, params={})
      response = @connection.send(method, params)

      ResponseWrapper.wrap(body, response)
    rescue Excon::Errors::Error => ex
      ex.extend Error # tag
      raise
    end

    def get(params={})
      request(:get, params)
    end

    def get_json(params={})
      body = request(:get, params)
      json = JSON.parse(body)
      ResponseWrapper.wrap(json, body.response)
    end

    def post(params={})
      request(:post, params)
    end
  end
end
