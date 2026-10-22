require "rails_helper"

RSpec.describe Ai::OpenAiClient do
  let(:sent) { {} }
  let(:schema) { { name: "code_review", schema: { type: "object", properties: {}, required: [], additionalProperties: false } } }

  def openai_reply(text: '{"summary":"ok"}', status: "completed", content: nil)
    {
      status: status,
      output: [
        { type: "reasoning", summary: [] },
        { type: "message", content: content || [ { type: "output_text", text: text } ] }
      ]
    }.to_json
  end

  def client_returning(code, body)
    transport = lambda do |uri, headers, payload|
      sent.merge!(uri: uri, headers: headers, payload: JSON.parse(payload))
      [ code, body ]
    end
    described_class.new(api_key: "sk-test", model: "gpt-6-luna", transport: transport)
  end

  def client_raising(error)
    described_class.new(api_key: "sk-test", model: "gpt-6-luna", transport: ->(*) { raise error })
  end

  it "returns the generated text" do
    expect(client_returning(200, openai_reply).complete(system: "s", prompt: "p")).to eq('{"summary":"ok"}')
  end

  it "sends the model, both messages, and the API key to the Responses endpoint" do
    client_returning(200, openai_reply).complete(system: "Be a reviewer.", prompt: "Review this.")

    expect(sent[:uri].to_s).to eq("https://api.openai.com/v1/responses")
    expect(sent[:headers]["Authorization"]).to eq("Bearer sk-test")
    expect(sent[:payload]["model"]).to eq("gpt-6-luna")
    expect(sent[:payload]["input"]).to eq([
      { "role" => "system", "content" => "Be a reviewer." },
      { "role" => "user", "content" => "Review this." }
    ])
  end

  it "requests strict structured output when given a schema" do
    client_returning(200, openai_reply).complete(system: "s", prompt: "p", schema: schema)

    format = sent[:payload].dig("text", "format")
    expect(format).to include("type" => "json_schema", "name" => "code_review", "strict" => true)
    expect(format["schema"]).to eq(schema[:schema].deep_stringify_keys)
  end

  it "requests plain text when no schema is given" do
    client_returning(200, openai_reply).complete(system: "s", prompt: "p")

    expect(sent[:payload]).not_to have_key("text")
  end

  it "raises Ai::Error with the status and OpenAI's message for an error response" do
    body = { error: { message: "Incorrect API key provided." } }.to_json

    expect { client_returning(401, body).complete(system: "s", prompt: "p") }
      .to raise_error(Ai::Error, /401.*Incorrect API key provided/)
  end

  it "raises Ai::Error for an error response that is not JSON" do
    expect { client_returning(502, "<html>Bad gateway</html>").complete(system: "s", prompt: "p") }
      .to raise_error(Ai::Error, /502/)
  end

  it "raises Ai::Error when the model refuses" do
    reply = openai_reply(content: [ { type: "refusal", refusal: "I can't help with that." } ])

    expect { client_returning(200, reply).complete(system: "s", prompt: "p") }
      .to raise_error(Ai::Error, /refused/)
  end

  it "raises Ai::Error when the answer was cut off" do
    expect { client_returning(200, openai_reply(status: "incomplete")).complete(system: "s", prompt: "p") }
      .to raise_error(Ai::Error, /incomplete/)
  end

  it "raises Ai::Error when the reply has no text" do
    expect { client_returning(200, { status: "completed", output: [] }.to_json).complete(system: "s", prompt: "p") }
      .to raise_error(Ai::Error, /no text/)
  end

  it "raises Ai::Error when a successful reply is not JSON" do
    expect { client_returning(200, "not json").complete(system: "s", prompt: "p") }
      .to raise_error(Ai::Error)
  end

  [ Net::ReadTimeout, Net::OpenTimeout, SocketError, Errno::ECONNREFUSED, OpenSSL::SSL::SSLError ].each do |error|
    it "raises Ai::Error when the connection fails with #{error}" do
      expect { client_raising(error.new).complete(system: "s", prompt: "p") }.to raise_error(Ai::Error)
    end
  end
end
