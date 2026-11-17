require "tempfile"
require "tmpdir"

# This cache belongs to one unused dyno and is discarded with its submission.
# Only trusted standard-library code is compiled before receiving user input.
ENV["JUDGE_GO_CACHE"] = Dir.mktmpdir("judge-go-cache")
prepared = system(
  { "GOCACHE" => ENV.fetch("JUDGE_GO_CACHE"), "GOMAXPROCS" => "1" },
  "timeout", "--signal=KILL", "30s", "go", "build", "-p=1", "-o", "/tmp/judge-go-warmup", "/judge/warmup.go",
  out: File::NULL, err: File::NULL
)
abort "Judge warmup unavailable" unless prepared

# Nothing submitted runs until the payload arrives. The outer dyno deadline
# bounds idle cost; exec starts a separate hard execution deadline afterward.
STDOUT.sync = true
puts "CODECOACH_JUDGE_READY"
payload = STDIN.read(1_048_577)
abort "Invalid judge payload" if payload.empty? || payload.bytesize > 1_048_576

file = Tempfile.new("judge-input")
file.write(payload)
file.rewind
STDIN.reopen(file)
file.close!
exec("timeout", "--signal=KILL", "55s", "ruby", "-rcoverage", "-e",
  "Coverage.start(lines: true) if ENV['JUDGE_COVERAGE'] == '1'; load '/judge/main.rb'")
