require "socket"
require "securerandom"

# Real attached streams with a simulated Platform API; no external credentials.
class HerokuJudgeStub
  attr_reader :requests, :payloads, :stopped

  def initialize(result:)
    @result = result
    @requests, @payloads, @stopped = Queue.new, Queue.new, Queue.new
    @sockets = {}
    @threads = []
    @mutex = Mutex.new
    key = OpenSSL::PKey::RSA.new(2048)
    certificate = OpenSSL::X509::Certificate.new
    certificate.version = 2
    certificate.serial = 1
    certificate.subject = certificate.issuer = OpenSSL::X509::Name.parse("/CN=example.test")
    certificate.public_key = key.public_key
    certificate.not_before = Time.now - 60
    certificate.not_after = Time.now + 3600
    certificate.sign(key, OpenSSL::Digest::SHA256.new)
    @server_context = OpenSSL::SSL::SSLContext.new
    @server_context.key = key
    @server_context.cert = certificate
  end

  def runner
    stub = self
    api = Class.new(Judge::HerokuDynoRunner::Api) do
      define_method(:request) { |_uri, request| stub.request(request) }
    end.new
    rendezvous = Judge::HerokuDynoRunner::Rendezvous.new(socket_factory: ->(uri) { @mutex.synchronize { @sockets.fetch(uri.path.delete_prefix("/")) } })
    Judge::HerokuDynoRunner.new(app: "codecoach", token: "test-secret", api: api, rendezvous: rendezvous, pool: nil)
  end

  def request(request)
    if request.path.end_with?("/actions/stop")
      @stopped << request.path.split("/")[-3]
      return Struct.new(:code, :body).new("202", "")
    end
    @requests << JSON.parse(request.body)
    id = SecureRandom.uuid
    client_io, server_io = Socket.pair(:UNIX, :STREAM, 0)
    client = OpenSSL::SSL::SSLSocket.new(client_io)
    server = OpenSSL::SSL::SSLSocket.new(server_io, @server_context)
    client.sync_close = server.sync_close = true
    @mutex.synchronize do
      @sockets[id] = client
      @threads << Thread.new do
        begin
          server.accept
          server.gets
          server.write("connected\nCODECOACH_JUDGE_READY\n")
          input = +""
          input << server.readpartial(4096) until input.end_with?("\u0004")
          @payloads << JSON.parse(input.delete_suffix("\u0004"))
          server.write(@result)
        rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
          # Pool shutdown closes unused attachments before a payload arrives.
        ensure
          server.close
        end
      end
    end
    client.connect
    Struct.new(:code, :body).new("201", JSON.generate(id: id, attach_url: "rendezvous://example.test:5000/#{id}"))
  end

  def close
    @sockets.each_value { |socket| socket.close unless socket.closed? }
    @threads.each(&:join)
  end
end
