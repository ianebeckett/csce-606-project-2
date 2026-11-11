require "json"
require "net/http"
require "openssl"
require "timeout"
require "uri"

module Judge
  class RemoteRunner
    Response = Data.define(:status, :body)
    OPEN_TIMEOUT = 3
    COMPILE_TIMEOUT = 15
    CASE_TIMEOUT = 4
    RESPONSE_OVERHEAD_TIMEOUT = 5
    MAX_RESPONSE_BYTES = 1_048_576
    SUCCESS_STATUS = DockerRunner::SUCCESS_STATUS
    VALID_STATUSES = DockerRunner::VALID_STATUSES

    class ResponseTooLarge < StandardError; end

    class Transport
      def call(uri:, token:, body:, open_timeout:, read_timeout:)
        request = Net::HTTP::Post.new(uri.request_uri)
        request["Authorization"] = "Bearer #{token}"
        request["Content-Type"] = "application/json"
        request["Accept"] = "application/json"
        request.body = body
        response_body = +""
        status = nil

        http = Net::HTTP.new(uri.host, uri.port, nil)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.open_timeout = open_timeout
        http.read_timeout = read_timeout
        http.write_timeout = open_timeout
        http.request(request) do |response|
          status = response.code.to_i
          response.read_body do |chunk|
            response_body << chunk
            raise ResponseTooLarge if response_body.bytesize > MAX_RESPONSE_BYTES
          end
        end
        Response.new(status, response_body)
      end
    end

    def initialize(url: ENV["JUDGE_URL"], token: ENV["JUDGE_TOKEN"], transport: Transport.new)
      @url = url
      @token = token
      @transport = transport
    end

    def call(code:, language:, problem:, inputs:)
      uri = endpoint
      return unavailable unless uri && valid_token?

      body = JSON.generate(Payload.build(code: code, language: language, problem: problem, inputs: inputs))
      response = @transport.call(
        uri: uri,
        token: @token,
        body: body,
        open_timeout: OPEN_TIMEOUT,
        read_timeout: read_timeout(inputs.length)
      )
      return unavailable unless response.status == 200

      parsed = JSON.parse(response.body)
      return unavailable unless valid_result?(parsed, language, inputs.length)

      parsed
    rescue JSON::ParserError, URI::InvalidURIError, ResponseTooLarge, SystemCallError, SocketError, IOError,
      Timeout::Error, OpenSSL::SSL::SSLError, Net::ProtocolError
      unavailable
    end

    private

    def endpoint
      return if @url.blank?

      uri = URI.parse(@url)
      return unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.nil?

      uri
    end

    def valid_token?
      @token.present? && !@token.match?(/[\r\n]/)
    end

    def valid_result?(result, language, input_count)
      result.is_a?(Hash) &&
        VALID_STATUSES.include?(result["status"]) &&
        result["outputs"].is_a?(Array) &&
        result["outputs"].length <= input_count &&
        result["runtime"] == Attempt.language_version(language)
    end

    def read_timeout(input_count)
      COMPILE_TIMEOUT + (CASE_TIMEOUT * input_count) + RESPONSE_OVERHEAD_TIMEOUT
    end

    def unavailable
      { "status" => Attempt::JUDGE_UNAVAILABLE, "outputs" => [] }
    end
  end
end
