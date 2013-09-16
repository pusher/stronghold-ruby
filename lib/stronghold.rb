require 'excon'
require 'json'

module Stronghold
  class Tree
    attr_reader :version

    def initialize(client, version)
      @client = client
      @version = version
    end

    ##
    # List the paths that stronghold knows about
    def paths
      resp = @client.connection.get(
        path: "/#{version}/tree/paths",
        expects: 200,
        idempotent: true
      )
      JSON.parse(resp.body)
    end

    ##
    # Extracts the set variables from a particular path level.
    # This means variables set at that level, and none others
    # Generally this is not what you want, unless you are
    # writing an editor
    def peculiar(path)
      raise "path should start with a forward slash" unless path[0] == '/' || path.empty?
      resp = @client.connection.get(
        path: "/#{version}/tree/peculiar#{path}",
        expects: 200,
        idempotent: true
      )
      JSON.parse(resp.body)
    end

    ##
    # Extracts the set variables for a path. This means variables
    # from this level of the path and all previous levels
    # superimposed in order of specialization (lower overrides higher)
    def materialized(path)
      raise "path should start with a forward slash" unless path[0] == '/' || path.empty?
      resp = @client.connection.get(
        path: "/#{version}/tree/materialized#{path}",
        expects: 200,
        idempotent: true
      )
      JSON.parse(resp.body)
    end

    def next_materialized(path)
      raise "path should start with a forward slash" unless path[0] == '/' || path.empty?
      resp = @client.connection.get(
        path: "/#{version}/next/tree/materialized#{path}",
        expects: 200,
        idempotent: true
      )
      result = JSON.parse(resp.body)
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

    def change
      @change ||= begin
        response = @client.connection.get(
          path: "/#{version}/change",
          expects: 200,
          idempotent: true
        )
        options = JSON.parse(response.body)
        Update.new(
          author: options["author"],
          comment: options["comment"],
          timestamp: options["timestamp"],
          previous: Version.new(@client, options["previous"]),
          changes: ChangeSet.new(options["changes"])
        )
      end
    end

    def update(options)
      path, data, author, comment = options.values_at(:path, :data, :author, :comment)
      raise "path should start with a forward slash" unless path[0] == '/' || path.empty?
      resp = @client.connection.post(
        path: "/#{version}/update#{path}",
        body: JSON.generate(data: data, author: author, comment: comment),
        expects: 200,
        idempotent: true
      )
      Version.new(@client, resp.body)
    end
  end

  class Versions
    def initialize(client)
      @client = client
    end

    def at(ts)
      raise "expected a time" unless ts.kind_of?(Time)
      Version.new(@client, @client.connection.get(
        path: '/versions',
        query: {at: ts.to_i},
        expects: 200,
        idempotent: true
      ).body)
    end

    def before(version, n)
      raise "expected a Version" unless version.kind_of?(Version)
      JSON.parse(@client.connection.get(
        path: '/versions',
        query: {last: version.version, size: n},
        expects: 200,
        idempotent: true
      ).body).map { |x|
        Version.new(@client, x['revision'])
      }
    end
  end

  class Error < StandardError;  end
  class ConnectionError < Error
    attr_reader :child_error
    def initialize(child_error)
      super("#{child_error.message} (#{child_error.class})")
      set_backtrace(child_error.backtrace)
      @child_error = child_error
    end
  end

  class Client
    attr_reader :connection

    ##
    # Connect to stronghold
    def initialize(uri = "http://127.0.0.1:5040")
      begin
        @connection = Excon.new(uri)
        unless @connection.get.body == "Stronghold says hi"
          raise Stronghold::ConnectionError.new("#{uri} is not stronghold")
        end
      rescue Excon::Errors::Error => ex
        raise(Stronghold::ConnectionError.new(ex))
      end
    end

    ##
    # Get the latest version, generally what you want
    def head
      Version.new(self, @connection.get(
        path: '/head',
        expects: 200,
        idempotent: true
      ).body)
    end

    def versions
      @versions ||= Versions.new(self)
    end
  end
end
