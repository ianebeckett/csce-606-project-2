JUDGE_PROBLEMS = [
  {
    topic: "Arrays & Hashing", slug: "contains-duplicate", title: "Contains Duplicate", number: 217,
    description: "Return true when an integer occurs more than once in nums; otherwise return false. The array contains 1 to 100,000 integers, each between -1,000,000,000 and 1,000,000,000.",
    interview: {
      prompt: "Given a short list of numbers, tell me whether any number repeats.",
      details: [
        { key: "size", fact: "1 to 100,000 numbers" },
        { key: "range", fact: "values between -10^9 and 10^9" },
        { key: "output", fact: "return true/false, not the duplicates" }
      ],
      twist: "Actually, the list can hold up to 100,000 numbers. Does your approach still work?"
    },
    method_name: "contains_duplicate", arguments: "nums",
    cases: [
      [ [ [ 1, 2, 3, 1 ] ], true ], [ [ [ 1, 2, 3, 4 ] ], false ], [ [ [ 1 ] ], false ],
      [ [ [ -1, -2, -1 ] ], true ], [ [ [ 0, 0 ] ], true ], [ [ [ 1_000_000_000, -1_000_000_000, 0 ] ], false ]
    ]
  },
  {
    topic: "Two Pointers", slug: "valid-palindrome", title: "Valid Palindrome", number: 125,
    prerequisites: [ "Arrays & Hashing" ],
    description: "Ignore punctuation and spaces, compare ASCII letters without case, and keep digits. Return whether the remaining characters read identically in both directions. The input has 1 to 200,000 printable ASCII characters.",
    interview: {
      prompt: "Given a lowercase word, tell me whether it reads the same forwards and backwards.",
      details: [
        { key: "input", fact: "a single lowercase word at first" },
        { key: "output", fact: "return true or false" },
        { key: "size", fact: "up to 200,000 characters" }
      ],
      twist: "Actually, the input will be full sentences with mixed case, spaces, punctuation and digits. Ignore anything that is not a letter or digit. How does that change your approach?"
    },
    method_name: "is_palindrome", arguments: "s",
    cases: [
      [ [ "A man, a plan, a canal: Panama" ], true ], [ [ "race a car" ], false ], [ [ " " ], true ],
      [ [ "0P" ], false ], [ [ "a" ], true ], [ [ "ab_a" ], true ]
    ]
  },
  {
    topic: "Stack", slug: "valid-parentheses", title: "Valid Parentheses", number: 20,
    prerequisites: [ "Arrays & Hashing" ],
    description: "Check a string made only of round, square, and curly brackets. Return true only when every closing bracket matches the most recent unmatched opening bracket and no opening bracket remains. The string has 1 to 10,000 characters.",
    interview: {
      prompt: "Given a string containing only round brackets, tell me whether they are balanced.",
      details: [
        { key: "input", fact: "only ( and ) characters" },
        { key: "output", fact: "return true or false" },
        { key: "size", fact: "1 to 10,000 characters" }
      ],
      twist: "Actually, the string can also contain square and curly brackets, and each closing bracket must match the most recent unmatched opener. How do you handle that?"
    },
    method_name: "is_valid", arguments: "s",
    cases: [
      [ [ "()" ], true ], [ [ "()[]{}" ], true ], [ [ "(]" ], false ],
      [ [ "([])" ], true ], [ [ "([)]" ], false ], [ [ "[" ], false ]
    ]
  },
  {
    topic: "Binary Search", slug: "binary-search", title: "Binary Search", number: 704,
    prerequisites: [ "Arrays & Hashing" ],
    description: "Find target in an increasing array of distinct integers. Return its zero-based index, or -1 when absent. Use O(log n) time. The array has 1 to 10,000 values, with values and target strictly between -10,000 and 10,000.",
    interview: {
      prompt: "Given a short sorted list of distinct integers and a target, tell me where the target is.",
      details: [
        { key: "order", fact: "sorted in increasing order, no duplicates" },
        { key: "output", fact: "zero-based index, or -1 if absent" },
        { key: "size", fact: "only a handful of values" }
      ],
      twist: "Actually, the list can hold up to 10,000 values, and your solution must run in O(log n) time. Does your approach meet that?"
    },
    method_name: "search", arguments: "nums, target",
    cases: [
      [ [ [ -1, 0, 3, 5, 9, 12 ], 9 ], 4 ], [ [ [ -1, 0, 3, 5, 9, 12 ], 2 ], -1 ],
      [ [ [ 5 ], 5 ], 0 ], [ [ [ 5 ], 1 ], -1 ], [ [ [ 1, 2, 3 ], 1 ], 0 ], [ [ [ 1, 2, 3 ], 3 ], 2 ]
    ]
  },
  {
    topic: "Sliding Window", slug: "maximum-average-subarray-i", title: "Maximum Average Subarray I", number: 643,
    prerequisites: [ "Two Pointers" ],
    description: "Among all consecutive groups of exactly k elements in nums, return the largest average. Absolute error must be less than 0.00001. The array has at most 100,000 integers between -10,000 and 10,000, and 1 <= k <= nums.length.",
    interview: {
      prompt: "Given a list of integers where k is always 2, find the largest average of any two consecutive elements.",
      details: [
        { key: "window", fact: "exactly k consecutive elements, with k = 2" },
        { key: "values", fact: "integers between -10,000 and 10,000" },
        { key: "output", fact: "the largest average as a float" }
      ],
      twist: "Actually, k can be any value from 1 to n, and n can be up to 100,000. How do you keep it efficient?"
    },
    method_name: "find_max_average", arguments: "nums, k", comparison: "float",
    cases: [
      [ [ [ 1, 12, -5, -6, 50, 3 ], 4 ], 12.75 ], [ [ [ 5 ], 1 ], 5.0 ],
      [ [ [ -5, -2, -3 ], 2 ], -2.5 ], [ [ [ 1, 2, 3, 4 ], 2 ], 3.5 ],
      [ [ [ 1, 2, 3, 4 ], 4 ], 2.5 ], [ [ [ -1, -2, -3 ], 1 ], -1.0 ], [ [ [ 1, 0, 0 ], 3 ], 1.0 / 3 ]
    ]
  },
  {
    topic: "Linked List", slug: "reverse-linked-list", title: "Reverse Linked List", number: 206,
    prerequisites: [ "Arrays & Hashing" ],
    description: "Reverse a singly linked list and return its new head. The judge provides ListNode with val and next accessors and converts the input array into nodes for you. Return a ListNode or nil, not an array. Lists have 0 to 5,000 nodes, with values between -5,000 and 5,000.",
    interview: {
      prompt: "Given a singly linked list of integers, return the values in reverse order as an array.",
      details: [
        { key: "input", fact: "a singly linked list with 0 to 5,000 nodes" },
        { key: "values", fact: "between -5,000 and 5,000" },
        { key: "output", fact: "an array of the values reversed" }
      ],
      twist: "Actually, return the new head ListNode instead of an array, reversing the list itself. How would you do that?"
    },
    method_name: "reverse_list", arguments: "head", input_kind: "linked_list",
    cases: [
      [ [ [ 1, 2, 3, 4, 5 ] ], [ 5, 4, 3, 2, 1 ] ], [ [ [ 1, 2 ] ], [ 2, 1 ] ], [ [ [] ], [] ],
      [ [ [ 0 ] ], [ 0 ] ], [ [ [ -1, 0, 1 ] ], [ 1, 0, -1 ] ], [ [ [ 4, 4, 2 ] ], [ 2, 4, 4 ] ]
    ]
  }
].freeze
