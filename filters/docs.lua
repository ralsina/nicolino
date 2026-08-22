-- Demo Lua filters for this documentation site.
--
-- This script makes the user guide's Lua Filters page self-documenting:
-- the examples below are loaded by every build of this site, and the
-- page renders live output from them through a shortcode.

return {
  -- Reverse title case: the opposite of Title Case. The first letter
  -- of each word goes lowercase and the rest go uppercase,
  -- so "hi there" becomes "hI tHERE".
  reverse_title_case = function(text)
    return (text:gsub("(%a)(%a*)", function(first, rest)
      return first:lower() .. rest:upper()
    end))
  end,
}
