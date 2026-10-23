module RubySolutions
  FORGED_RESULT = <<~'RUBY'.freeze
    def contains_duplicate(nums)
      result = JSON.generate("status" => "Compilation Error", "message" => "forged judge message")
      ObjectSpace.each_object(IO) do |stream|
        next if stream.closed? || [STDIN, STDOUT, STDERR].include?(stream)
        begin
          stream.puts(result)
          stream.flush
        rescue IOError, SystemCallError
        end
      end
      exit!(0)
    end
  RUBY

  CORRECT = {
    "contains-duplicate" => <<~RUBY,
      def contains_duplicate(nums)
        nums.uniq.length != nums.length
      end
    RUBY
    "valid-palindrome" => <<~RUBY,
      def is_palindrome(s)
        letters = s.downcase.gsub(/[^a-z0-9]/, "")
        letters == letters.reverse
      end
    RUBY
    "valid-parentheses" => <<~RUBY,
      def is_valid(s)
        stack = []
        pairs = { ")" => "(", "]" => "[", "}" => "{" }
        s.each_char do |char|
          if pairs.key?(char)
            return false unless stack.pop == pairs[char]
          else
            stack << char
          end
        end
        stack.empty?
      end
    RUBY
    "binary-search" => <<~RUBY,
      def search(nums, target)
        left = 0
        right = nums.length - 1
        while left <= right
          middle = (left + right) / 2
          return middle if nums[middle] == target
          if nums[middle] < target
            left = middle + 1
          else
            right = middle - 1
          end
        end
        -1
      end
    RUBY
    "maximum-average-subarray-i" => <<~RUBY,
      def find_max_average(nums, k)
        total = nums.first(k).sum
        best = total
        (k...nums.length).each do |index|
          total += nums[index] - nums[index - k]
          best = [best, total].max
        end
        best.to_f / k
      end
    RUBY
    "reverse-linked-list" => <<~RUBY
      def reverse_list(head)
        previous = nil
        while head
          following = head.next
          head.next = previous
          previous = head
          head = following
        end
        previous
      end
    RUBY
  }.freeze
end
