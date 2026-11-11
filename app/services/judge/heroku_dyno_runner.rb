require "json"
require "net/http"
require "openssl"
require "socket"
require "timeout"
require "uri"

module Judge
  class HerokuDynoRunner
    PLATFORM_API = "https://api.heroku.com".freeze
    COMMAND = "55s ruby -rcoverage -e \"load '/judge/main.rb'\"".freeze
    PROCESS_TYPE = "judge".freeze
    SENSITIVE_ENV_PATTERN = /DATABASE|PASSWORD|SECRET|TOKEN|_KEY(?:_|\z)|_URL(?:_|\z)/i
    APP_PATTERN = /\A[a-z][a-z0-9-]{1,28}[a-z0-9]\z/.freeze
    OPEN_TIMEOUT = 5
    COMPILE_TIMEOUT = 15
    CASE_TIMEOUT = 4
    DYNO_OVERHEAD_TIMEOUT = 30
    MAX_RESPONSE_BYTES = 1_048_576
    SUCCESS_STATUS = DockerRunner::SUCCESS_STATUS
    VALID_STATUSES = DockerRunner::VALID_STATUSES

    class << self
      attr_accessor :pool
    end

    class ResponseTooLarge < StandardError; end
    class InvalidResponse < StandardError; end

    class Api
      def create_dyno(app:, token:, env:)
        launch(app: app, token: token, env: env, command: COMMAND, lifetime: 60).fetch("attach_url")
      end

      def prepare_dyno(app:, token:, env:)
        launch(app: app, token: token, env: env,
          command: "960s ruby /judge/ready.rb", lifetime: 1080)
      end

      def stop_dyno(app:, token:, id:)
        uri = URI("#{PLATFORM_API}/apps/#{app}/dynos/#{id}/actions/stop")
        request = Net::HTTP::Post.new(uri.request_uri)
        request["Authorization"] = "Bearer #{token}"
        request["Accept"] = "application/vnd.heroku+json; version=3"
        request(uri, request)
      end

      private

      def launch(app:, token:, env:, command:, lifetime:)
        uri = URI("#{PLATFORM_API}/apps/#{app}/dynos")
        request = Net::HTTP::Post.new(uri.request_uri)
        request["Authorization"] = "Bearer #{token}"
        request["Content-Type"] = "application/json"
        request["Accept"] = "application/vnd.heroku+json; version=3"
        request.body = JSON.generate(
          attach: true,
          command: command,
          env: env,
          force_no_tty: true,
          time_to_live: lifetime,
          size: "Basic",
          type: PROCESS_TYPE
        )
        response = request(uri, request)
        raise InvalidResponse unless response.code.to_i == 201
        raise ResponseTooLarge if response.body.bytesize > MAX_RESPONSE_BYTES

        JSON.parse(response.body)
      end

      def request(uri, request)
        http = Net::HTTP.new(uri.host, uri.port, nil)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.open_timeout = OPEN_TIMEOUT
        http.read_timeout = OPEN_TIMEOUT
        http.write_timeout = OPEN_TIMEOUT
        http.request(request)
      end
    end

    class Rendezvous
      END_OF_TRANSMISSION = "\u0004".freeze

      def initialize(socket_factory: nil)
        @socket_factory = socket_factory
      end

      def call(url:, input:, timeout:)
        Timeout.timeout(timeout) do
          ssl = connect(url)
          ssl.write(input)
          ssl.write(END_OF_TRANSMISSION)
          read(ssl)
        ensure
          ssl&.close
        end
      end

      def prepare(url:, on_close:)
        Timeout.timeout(90) do
          ssl = connect(url)
          raise InvalidResponse unless ssl.gets("\n", 64)&.strip == "CODECOACH_JUDGE_READY"

          session = Session.new(ssl, on_close: on_close)
        ensure
          ssl&.close unless session
        end
      end

      class Session
        def initialize(socket, on_close:)
          @socket, @on_close = socket, on_close
          @closed = false
        end

        def usable?
          return false if @closed || @socket.closed?

          # Process TLS control frames too; a readable TCP socket need not have
          # application output. Any real output before a payload is invalid.
          [ :wait_readable, :wait_writable ].include?(@socket.read_nonblock(1, exception: false))
        rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
          false
        end

        def call(input:, timeout:)
          Timeout.timeout(timeout) do
            @socket.write(input)
            @socket.write(END_OF_TRANSMISSION)
            output = +""
            begin
              loop do
                output << @socket.readpartial(4096)
                raise ResponseTooLarge if output.bytesize > MAX_RESPONSE_BYTES
              end
            rescue EOFError
              output.gsub("\r\n", "\n").strip
            end
          end
        ensure
          close
        end

        def close
          return if @closed

          @closed = true
          begin
            @socket.close
          ensure
            @on_close.call
          end
        rescue StandardError
          # The attachment closes first; the dyno TTL also bounds failed cleanup.
          nil
        end
      end

      private

      def connect(url)
        connected = false
        uri = endpoint(url)
        ssl = @socket_factory ? @socket_factory.call(uri) : open(uri)
        ssl.write("#{uri.path.delete_prefix("/")}#{uri.query ? "?#{uri.query}" : ""}\r\n")
        raise InvalidResponse unless ssl.gets("\n", 1024)

        connected = true
        ssl
      ensure
        ssl&.close unless connected
      end

      def endpoint(url)
        uri = URI.parse(url)
        raise InvalidResponse unless uri.scheme == "rendezvous" && uri.host.present? && uri.port && uri.path.present?

        uri
      end

      def open(uri)
        connected = false
        socket = Socket.tcp(uri.host, uri.port, connect_timeout: OPEN_TIMEOUT)
        context = OpenSSL::SSL::SSLContext.new
        context.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
        ssl = OpenSSL::SSL::SSLSocket.new(socket, context)
        ssl.hostname = uri.host
        ssl.sync_close = true
        ssl.connect
        ssl.post_connection_check(uri.host)
        connected = true
        ssl
      ensure
        socket&.close unless connected
      end

      def read(ssl)
        output = +""
        loop do
          output << ssl.readpartial(4096)
          raise ResponseTooLarge if output.bytesize > MAX_RESPONSE_BYTES
        end
      rescue EOFError
        output.gsub("\r\n", "\n").strip
      end
    end

    def initialize(
      app: ENV["JUDGE_HEROKU_APP"],
      token: ENV["JUDGE_HEROKU_TOKEN"],
      api: Api.new,
      rendezvous: Rendezvous.new,
      pool: self.class.pool
    )
      @app = app
      @token = token
      @api = api
      @rendezvous = rendezvous
      @pool = pool
    end

    def prepare
      raise InvalidResponse unless valid_configuration?

      dyno = @api.prepare_dyno(app: @app, token: @token, env: scrubbed_environment)
      cleanup = -> { @api.stop_dyno(app: @app, token: @token, id: dyno.fetch("id")) }
      session = @rendezvous.prepare(url: dyno.fetch("attach_url"), on_close: cleanup)
    ensure
      cleanup&.call if !session && dyno
    end

    def call(code:, language:, problem:, inputs:)
      return unavailable unless valid_configuration?

      payload = JSON.generate(Payload.build(code: code, language: language, problem: problem, inputs: inputs))
      if @pool
        session = @pool.checkout
        response = session.call(input: payload, timeout: 55)
      else
        attach_url = @api.create_dyno(app: @app, token: @token, env: scrubbed_environment)
        response = @rendezvous.call(url: attach_url, input: payload, timeout: timeout(inputs.length))
      end
      result = JSON.parse(response)
      return unavailable unless valid_result?(result, language, inputs.length)

      result
    rescue JSON::ParserError, KeyError, InvalidResponse, ResponseTooLarge, SystemCallError, SocketError, IOError,
      Timeout::Error, OpenSSL::SSL::SSLError, Net::ProtocolError
      unavailable
    ensure
      session&.close
    end

    private

    def valid_configuration?
      @app.present? && @app.match?(APP_PATTERN) && @token.present? && !@token.match?(/[\r\n]/)
    end

    def valid_result?(result, language, input_count)
      result.is_a?(Hash) &&
        VALID_STATUSES.include?(result["status"]) &&
        result["outputs"].is_a?(Array) &&
        result["outputs"].length <= input_count &&
        result["runtime"] == Attempt.language_version(language)
    end

    def scrubbed_environment
      ENV.each_key.filter_map do |name|
        [ name, "" ] if name.match?(SENSITIVE_ENV_PATTERN)
      end.to_h
    end

    def timeout(input_count)
      COMPILE_TIMEOUT + (CASE_TIMEOUT * input_count) + DYNO_OVERHEAD_TIMEOUT
    end

    def unavailable
      { "status" => Attempt::JUDGE_UNAVAILABLE, "outputs" => [] }
    end
  end
end
