require "json"
require_relative "runner"

def merge_coverage(parent, child)
  parent.merge(child) do |_path, parent_data, child_data|
    parent_lines = parent_data.fetch(:lines)
    child_lines = child_data.fetch("lines")
    length = [ parent_lines.length, child_lines.length ].max
    { "lines" => Array.new(length) do |index|
      parent_count = parent_lines[index]
      child_count = child_lines[index]
      parent_count || child_count ? (parent_count || 0) + (child_count || 0) : nil
    end }
  end
end

result_reader, result_writer = IO.pipe
submission_pid = Process.fork do
  result_reader.close
  begin
    STDOUT.reopen(File::NULL, "w")
    result = RubySubmission.new.call(JSON.parse(STDIN.read))
    result["coverage"] = Coverage.result if Coverage.running?
    result_writer.puts(JSON.generate(result))
  ensure
    result_writer.close
  end
end
result_writer.close
result_json = result_reader.read
result_reader.close
_, status = Process.wait2(submission_pid)
abort unless status.success?

result = JSON.parse(result_json)
if Coverage.running?
  child_coverage = result.delete("coverage")
  result["coverage"] = merge_coverage(Coverage.result, child_coverage)
end
puts JSON.generate(result)
