require "json"
require_relative "runner"

payload = JSON.parse(STDIN.read)
result = Submission.new.call(payload)
result["runtime"] = payload.fetch("runtime")
result["coverage"] = Coverage.result if Coverage.running?
puts JSON.generate(result)
