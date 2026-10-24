require "net/http"

module Ai
  class OpenAiClient
    ENDPOINT = URI("https://api.openai.com/v1/responses").freeze
    DEFAULT_MODEL = "gpt-6-luna".freeze
    MAX_OUTPUT_TOKENS = 2_000
    TIMEOUT_SECONDS = 30
    CONNECTION_ERRORS = [ Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError ].freeze

    attr_reader :model

    def initialize(api_key:, model: DEFAULT_MODEL, transport: nil)
      @api_key = api_key
      @model = model
      @transport = transport || method(:post)
    end

    def complete(system:, prompt:, schema: nil)
      status, body = @transport.call(ENDPOINT, headers, request_body(system, prompt, schema).to_json)
      raise Error, "OpenAI returned #{status}: #{error_message(body)}" unless (200..299).cover?(status)

      output_text(JSON.parse(body))
    rescue JSON::ParserError
      raise Error, "OpenAI returned a reply that is not JSON"
    rescue *CONNECTION_ERRORS => e
      raise Error, "Could not reach OpenAI (#{e.class})"
    end

    private

    def request_body(system, prompt, schema)
      body = {
        model: model,
        input: [ { role: "system", content: system }, { role: "user", content: prompt } ],
        max_output_tokens: MAX_OUTPUT_TOKENS
      }
      body[:text] = { format: { type: "json_schema", name: schema[:name], schema: schema[:schema], strict: true } } if schema
      body
    end

    def headers
      { "Authorization" => "Bearer #{@api_key}", "Content-Type" => "application/json" }
    end

    def output_text(reply)
      raise Error, "OpenAI returned an unexpected reply" unless reply.is_a?(Hash)
      raise Error, "OpenAI's answer was incomplete" if reply["status"] == "incomplete"

      parts = Array(reply["output"]).grep(Hash).select { |item| item["type"] == "message" }
        .flat_map { |item| Array(item["content"]).grep(Hash) }
      refusal = parts.find { |part| part["type"] == "refusal" }
      raise Error, "OpenAI refused: #{refusal["refusal"]}" if refusal

      text = parts.select { |part| part["type"] == "output_text" }.map { |part| part["text"].to_s }.join
      raise Error, "OpenAI's reply had no text" if text.empty?

      text
    end

    def error_message(body)
      JSON.parse(body).dig("error", "message") || "no details"
    rescue JSON::ParserError, TypeError
      "no details"
    end

    def post(uri, headers, body)
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT_SECONDS, read_timeout: TIMEOUT_SECONDS) do |http|
        response = http.post(uri.path, body, headers)
        [ response.code.to_i, response.body ]
      end
    end
  end
end
