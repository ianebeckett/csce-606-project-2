module Judge
  class Language
    class << self
      def starter_code(problem, language)
        return problem.starter_code if language == Attempt::LANGUAGE

        parameters = parameter_names(problem)
        case language
        when "python" then python_starter(problem, parameters)
        when "go" then go_starter(problem, parameters)
        when "cpp" then cpp_starter(problem, parameters)
        else raise KeyError, language
        end
      end

      # The Ruby starter code's signature is the source of parameter names.
      def parameter_names(problem)
        match = problem.starter_code.match(/\Adef\s+#{Regexp.escape(problem.method_name)}\(([^)]*)\)/)
        raise ArgumentError, "Invalid Ruby starter code" unless match

        match[1].split(",").map(&:strip)
      end

      private

      def python_starter(problem, parameters)
        <<~PYTHON
          class Solution:
              def #{method_name(problem)}(self, #{parameters.join(", ")}):
                  pass
        PYTHON
      end

      def go_starter(problem, parameters)
        signature = parameters.zip(argument_types(problem, "go")).map { |name, type| "#{name} #{type}" }.join(", ")
        <<~GO
          func #{method_name(problem)}(#{signature}) #{return_type(problem, "go")} {
            #{default_return(problem, "go")}
          }
        GO
      end

      def cpp_starter(problem, parameters)
        signature = parameters.zip(argument_types(problem, "cpp")).map { |name, type| "#{type} #{name}" }.join(", ")
        <<~CPP
          class Solution {
          public:
            #{return_type(problem, "cpp")} #{method_name(problem)}(#{signature}) {
              #{default_return(problem, "cpp")}
            }
          };
        CPP
      end

      def method_name(problem)
        words = problem.method_name.split("_")
        words.first + words.drop(1).map(&:capitalize).join
      end

      def argument_types(problem, language)
        problem.test_cases.first.input.fetch("args").each_with_index.map do |value, index|
          if problem.input_kind == "linked_list" && index.zero?
            language == "go" ? "*ListNode" : "ListNode*"
          elsif value.is_a?(Array)
            language == "go" ? "[]int" : "vector<int>&"
          elsif value.is_a?(String)
            language == "go" ? "string" : "string"
          else
            "int"
          end
        end
      end

      def return_type(problem, language)
        return language == "go" ? "*ListNode" : "ListNode*" if problem.input_kind == "linked_list"

        output = problem.test_cases.first.expected_output
        return "bool" if output == true || output == false
        return language == "go" ? "float64" : "double" if output.is_a?(Float)

        "int"
      end

      def default_return(problem, language)
        type = return_type(problem, language)
        return "return nil" if type == "*ListNode"
        return "return nullptr;" if type == "ListNode*"
        return language == "go" ? "return false" : "return false;" if type == "bool"
        language == "go" ? "return 0" : "return 0;"
      end
    end
  end
end
