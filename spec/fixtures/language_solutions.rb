module LanguageSolutions
  CORRECT = {
    "python" => {
      "contains-duplicate" => <<~PYTHON,
        class Solution:
            def containsDuplicate(self, nums):
                return any(count > 1 for count in Counter(nums).values())
      PYTHON
      "reverse-linked-list" => <<~PYTHON
        class Solution:
            def reverseList(self, head):
                previous = None
                while head:
                    following = head.next
                    head.next = previous
                    previous = head
                    head = following
                return previous
      PYTHON
    },
    "go" => {
      "contains-duplicate" => <<~GO,
        func containsDuplicate(nums []int) bool {
          sort.Ints(nums)
          for index := 1; index < len(nums); index++ {
            if nums[index] == nums[index - 1] {
              return true
            }
          }
          return false
        }
      GO
      "reverse-linked-list" => <<~GO
        package main

        func reverseList(head *ListNode) *ListNode {
          var previous *ListNode
          for head != nil {
            following := head.Next
            head.Next = previous
            previous = head
            head = following
          }
          return previous
        }
      GO
    },
    "cpp" => {
      "contains-duplicate" => <<~CPP,
        class Solution {
        public:
          bool containsDuplicate(vector<int>& nums) {
            unordered_set<int> values(nums.begin(), nums.end());
            return values.size() != nums.size();
          }
        };
      CPP
      "reverse-linked-list" => <<~CPP
        class Solution {
        public:
          ListNode* reverseList(ListNode* head) {
            ListNode* previous = nullptr;
            while (head != nullptr) {
              ListNode* following = head->next;
              head->next = previous;
              previous = head;
              head = following;
            }
            return previous;
          }
        };
      CPP
    }
  }.freeze

  INVALID = {
    "ruby" => "def contains_duplicate(nums)\n",
    "python" => "class Solution:\n    def containsDuplicate(self, nums)\n",
    "go" => "package main\nfunc containsDuplicate(nums []int) bool {",
    "cpp" => "class Solution {"
  }.freeze

  RUNTIME_ERROR = {
    "python" => <<~PYTHON,
      class Solution:
          def containsDuplicate(self, nums):
              raise RuntimeError()
    PYTHON
    "go" => <<~GO,
      package main

      func containsDuplicate(nums []int) bool {
        panic("failure")
      }
    GO
    "cpp" => <<~CPP
      #include <stdexcept>
      #include <vector>
      using namespace std;

      class Solution {
      public:
        bool containsDuplicate(vector<int>& nums) {
          throw runtime_error("failure");
        }
      };
    CPP
  }.freeze

  TIMEOUT = {
    "python" => <<~PYTHON,
      class Solution:
          def containsDuplicate(self, nums):
              while True:
                  pass
    PYTHON
    "go" => <<~GO,
      package main

      func containsDuplicate(nums []int) bool {
        for {}
      }
    GO
    "cpp" => <<~CPP
      #include <vector>
      using namespace std;

      class Solution {
      public:
        bool containsDuplicate(vector<int>& nums) {
          while (true) {}
        }
      };
    CPP
  }.freeze
end
