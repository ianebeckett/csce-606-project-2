require "json"
require_relative "runner"

result_output = STDOUT.dup
STDOUT.reopen(File::NULL, "w")
result = RubySubmission.new.call(JSON.parse(STDIN.read))
result["coverage"] = Coverage.result if Coverage.running?
result_output.puts(JSON.generate(result))
