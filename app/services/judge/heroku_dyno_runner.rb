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

    class ResponseTooLarge < StandardError; end
    class InvalidResponse < StandardError; end

    class Api
      def create_dyno(app:, token:, env:)
        uri = URI("#{PLATFORM_API}/apps/#{app}/dynos")
        request = Net::HTTP::Post.new(uri.request_uri)
        request["Authorization"] = "Bearer #{token}"
        request["Content-Type"] = "application/json"
        request["Accept"] = "application/vnd.heroku+json; version=3"
        request.body = JSON.generate(
          attach: true,
          command: COMMAND,
          env: env,
          force_no_tty: true,
          time_to_live: 60,
          type: PROCESS_TYPE
        )
        response = request(uri, request)
        raise InvalidResponse unless response.code.to_i == 201
        raise ResponseTooLarge if response.body.bytesize > MAX_RESPONSE_BYTES

        JSON.parse(response.body).fetch("attach_url")
      end

      private

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
          uri = endpoint(url)
          ssl = @socket_factory ? @socket_factory.call(uri) : open(uri)
          ssl.write("#{uri.path.delete_prefix("/")}#{uri.query ? "?#{uri.query}" : ""}\r\n")
          raise InvalidResponse unless ssl.gets

          ssl.write(input)
          ssl.write(END_OF_TRANSMISSION)
          read(ssl)
        ensure
          ssl&.close
        end
      end

      private

      def endpoint(url)
        uri = URI.parse(url)
        raise InvalidResponse unless uri.scheme == "rendezvous" && uri.host.present? && uri.port && uri.path.present?

        uri
      end

      def open(uri)
        socket = Socket.tcp(uri.host, uri.port, connect_timeout: OPEN_TIMEOUT)
        context = OpenSSL::SSL::SSLContext.new
        context.set_params(verify_mode: OpenSSL::SSL::VERIFY_PEER)
        ssl = OpenSSL::SSL::SSLSocket.new(socket, context)
        ssl.hostname = uri.host
        ssl.sync_close = true
        ssl.connect
        ssl.post_connection_check(uri.host)
        ssl
      rescue StandardError
        socket&.close
        raise
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
      rendezvous: Rendezvous.new
    )
      @app = app
      @token = token
      @api = api
      @rendezvous = rendezvous
    end

    def call(code:, language:, problem:, inputs:)
      return unavailable unless valid_configuration?

      payload = JSON.generate(Payload.build(code: code, language: language, problem: problem, inputs: inputs))
      attach_url = @api.create_dyno(app: @app, token: @token, env: scrubbed_environment)
      response = @rendezvous.call(url: attach_url, input: payload, timeout: timeout(inputs.length))
      result = JSON.parse(response)
      return unavailable unless valid_result?(result, language, inputs.length)

      result
    rescue JSON::ParserError, KeyError, InvalidResponse, ResponseTooLarge, SystemCallError, SocketError, IOError,
      Timeout::Error, OpenSSL::SSL::SSLError, Net::ProtocolError
      unavailable
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
