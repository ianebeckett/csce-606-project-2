JUDGE_PROBLEMS = [
  {
    topic: "Arrays & Hashing", slug: "contains-duplicate", title: "Contains Duplicate", number: 217,
    description: "Return true when an integer occurs more than once in nums; otherwise return false. The array contains 1 to 100,000 integers, each between -1,000,000,000 and 1,000,000,000.",
    method_name: "contains_duplicate", arguments: "nums",
    cases: [
      [ [ [ 1, 2, 3, 1 ] ], true ], [ [ [ 1, 2, 3, 4 ] ], false ], [ [ [ 1 ] ], false ],
      [ [ [ -1, -2, -1 ] ], true ], [ [ [ 0, 0 ] ], true ], [ [ [ 1_000_000_000, -1_000_000_000, 0 ] ], false ]
    ]
  },
  {
    topic: "Two Pointers", slug: "valid-palindrome", title: "Valid Palindrome", number: 125,
    description: "Ignore punctuation and spaces, compare ASCII letters without case, and keep digits. Return whether the remaining characters read identically in both directions. The input has 1 to 200,000 printable ASCII characters.",
    method_name: "is_palindrome", arguments: "s",
    cases: [
      [ [ "A man, a plan, a canal: Panama" ], true ], [ [ "race a car" ], false ], [ [ " " ], true ],
      [ [ "0P" ], false ], [ [ "a" ], true ], [ [ "ab_a" ], true ]
    ]
  },
  {
    topic: "Stack", slug: "valid-parentheses", title: "Valid Parentheses", number: 20,
    description: "Check a string made only of round, square, and curly brackets. Return true only when every closing bracket matches the most recent unmatched opening bracket and no opening bracket remains. The string has 1 to 10,000 characters.",
    method_name: "is_valid", arguments: "s",
    cases: [
      [ [ "()" ], true ], [ [ "()[]{}" ], true ], [ [ "(]" ], false ],
      [ [ "([])" ], true ], [ [ "([)]" ], false ], [ [ "[" ], false ]
    ]
  },
  {
    topic: "Binary Search", slug: "binary-search", title: "Binary Search", number: 704,
    description: "Find target in an increasing array of distinct integers. Return its zero-based index, or -1 when absent. Use O(log n) time. The array has 1 to 10,000 values, with values and target strictly between -10,000 and 10,000.",
    method_name: "search", arguments: "nums, target",
    cases: [
      [ [ [ -1, 0, 3, 5, 9, 12 ], 9 ], 4 ], [ [ [ -1, 0, 3, 5, 9, 12 ], 2 ], -1 ],
      [ [ [ 5 ], 5 ], 0 ], [ [ [ 5 ], 1 ], -1 ], [ [ [ 1, 2, 3 ], 1 ], 0 ], [ [ [ 1, 2, 3 ], 3 ], 2 ]
    ]
  },
  {
    topic: "Sliding Window", slug: "maximum-average-subarray-i", title: "Maximum Average Subarray I", number: 643,
    description: "Among all consecutive groups of exactly k elements in nums, return the largest average. Absolute error must be less than 0.00001. The array has at most 100,000 integers between -10,000 and 10,000, and 1 <= k <= nums.length.",
    method_name: "find_max_average", arguments: "nums, k", comparison: "float",
    cases: [
      [ [ [ 1, 12, -5, -6, 50, 3 ], 4 ], 12.75 ], [ [ [ 5 ], 1 ], 5.0 ],
      [ [ [ -5, -2, -3 ], 2 ], -2.5 ], [ [ [ 1, 2, 3, 4 ], 2 ], 3.5 ],
      [ [ [ 1, 2, 3, 4 ], 4 ], 2.5 ], [ [ [ -1, -2, -3 ], 1 ], -1.0 ], [ [ [ 1, 0, 0 ], 3 ], 1.0 / 3 ]
    ]
  },
  {
    topic: "Linked List", slug: "reverse-linked-list", title: "Reverse Linked List", number: 206,
    description: "Reverse a singly linked list and return its new head. The judge provides ListNode with val and next accessors and converts the input array into nodes for you. Return a ListNode or nil, not an array. Lists have 0 to 5,000 nodes, with values between -5,000 and 5,000.",
    method_name: "reverse_list", arguments: "head", input_kind: "linked_list",
    cases: [
      [ [ [ 1, 2, 3, 4, 5 ] ], [ 5, 4, 3, 2, 1 ] ], [ [ [ 1, 2 ] ], [ 2, 1 ] ], [ [ [] ], [] ],
      [ [ [ 0 ] ], [ 0 ] ], [ [ [ -1, 0, 1 ] ], [ 1, 0, -1 ] ], [ [ [ 4, 4, 2 ] ], [ 2, 4, 4 ] ]
    ]
  }
].freeze
