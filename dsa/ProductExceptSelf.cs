public class Solution
{
    // Time: O(n). Extra space: O(n).
    public int[] ProductExceptSelfWithArrays(int[] nums)
    {
        int n = nums.Length;
        int[] prefix = new int[n];
        int[] suffix = new int[n];
        int[] result = new int[n];
        prefix[0] = 1;
        suffix[n - 1] = 1;
        for (int i = 1; i < n; i++)
            prefix[i] = prefix[i - 1] * nums[i - 1];
        for (int i = n - 2; i >= 0; i--)
            suffix[i] = suffix[i + 1] * nums[i + 1];
        for (int i = 0; i < n; i++)
            result[i] = prefix[i] * suffix[i];
        return result;
    }

    // Time: O(n). Extra space: O(1), excluding the output array.
    public int[] ProductExceptSelf(int[] nums)
    {
        int[] result = new int[nums.Length];
        int prefix = 1;
        for (int i = 0; i < nums.Length; i++)
        {
            result[i] = prefix;
            prefix *= nums[i];
        }
        int suffix = 1;
        for (int i = nums.Length - 1; i >= 0; i--)
        {
            result[i] *= suffix;
            suffix *= nums[i];
        }
        return result;
    }
}
