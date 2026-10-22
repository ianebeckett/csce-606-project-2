class ListNode
  attr_accessor :val, :next

  def initialize(val = 0, next_node = nil)
    @val = val
    @next = next_node
  end
end

class RubySubmission
  SOURCE_FILENAME = "submission.rb".freeze
  LINKED_LIST_INPUT = "linked_list".freeze
  SUCCESS_STATUS = "ok".freeze
  COMPILATION_ERROR = "Compilation Error".freeze
  RUNTIME_ERROR = "Runtime Error".freeze
  ERROR_MESSAGE_LIMIT = 1000
  MAX_LIST_NODES = 5000

  def call(payload)
    code = payload.fetch("code")
    RubyVM::InstructionSequence.compile(code, SOURCE_FILENAME)
    solution = Object.new
    solution.instance_eval(code, SOURCE_FILENAME)
    arguments = payload.fetch("input").fetch("args")
    linked_list = payload.fetch("input_kind") == LINKED_LIST_INPUT
    arguments[0] = build_list(arguments[0]) if linked_list
    output = solution.send(payload.fetch("method_name"), *arguments)
    output = list_values(output) if linked_list
    { "status" => SUCCESS_STATUS, "output" => output }
  rescue SyntaxError => error
    { "status" => COMPILATION_ERROR, "message" => error.message[0, ERROR_MESSAGE_LIMIT] }
  rescue StandardError, ScriptError, SystemExit, NoMemoryError, SystemStackError => error
    { "status" => RUNTIME_ERROR, "message" => "#{error.class}: #{error.message}"[0, ERROR_MESSAGE_LIMIT] }
  end

  private

  def build_list(values)
    values.reverse_each.reduce(nil) { |following, value| ListNode.new(value, following) }
  end

  def list_values(node)
    values = []
    visited = {}
    while node
      raise TypeError, "Return a ListNode or nil, not an array." unless node.is_a?(ListNode)
      raise ArgumentError, "Returned list contains a cycle or too many nodes." if visited[node.object_id] || values.length >= MAX_LIST_NODES

      visited[node.object_id] = true
      values << node.val
      node = node.next
    end
    values
  end
end
