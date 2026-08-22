require "./spec_helper"

require "../src/lua_filters"

# Fixture helpers -----------------------------------------------------------

def lua_spec_dir(name : String) : Path
  tmp = Path["/tmp/opencode", "lua-spec-#{name}-#{Random::Secure.hex(6)}"]
  FileUtils.mkdir_p(tmp)
  tmp
end

def lua_spec_write(dir : Path, filename : String, content : String) : String
  path = dir / filename
  File.write(path, content)
  path.to_s
end

def lua_spec_state(*scripts : String) : LuaFilters::State
  LuaFilters::State.new(scripts.to_a)
end

# Clear Croupier's modified registry so tests don't leak into each other
module LuaSpecCleanup
  def self.reset_modified
    Croupier::TaskManager.modified.clear
  end
end

describe LuaFilters do
  describe ".combine_paths" do
    it "orders theme scripts before site scripts" do
      LuaFilters.combine_paths(["themes/t/filters/b.lua"], ["filters/a.lua"]).should eq [
        "themes/t/filters/b.lua",
        "filters/a.lua",
      ]
    end

    it "keeps each group alphabetically sorted" do
      combined = LuaFilters.combine_paths(
        ["themes/t/filters/z.lua", "themes/t/filters/a.lua"],
        ["filters/m.lua", "filters/b.lua"],
      )
      combined.should eq [
        "themes/t/filters/a.lua",
        "themes/t/filters/z.lua",
        "filters/b.lua",
        "filters/m.lua",
      ]
    end

    it "lets site paths win collisions by loading last" do
      # State loads in order and the last export of a name wins, so
      # site files must come after theme files
      theme = ["x.lua"]
      site = ["x.lua"]
      LuaFilters.combine_paths(theme, site).last.should eq "x.lua"
      LuaFilters.combine_paths(theme, site).size.should eq 2
    end
  end
end

describe LuaFilters::State do
  describe "value marshaling" do
    it "passes strings through and returns strings" do
      dir = lua_spec_dir("strings")
      path = lua_spec_write(dir, "s.lua", <<-LUA)
        return {
          shout = function(text)
            return string.upper(text) .. "!"
          end,
        }
        LUA
      state = lua_spec_state(path)
      result = state.call_function("shout", Crinja::Value.new("hello"), [] of Crinja::Value)
      result.as_s.should eq "HELLO!"
    end

    it "forwards extra positional arguments" do
      dir = lua_spec_dir("args")
      path = lua_spec_write(dir, "w.lua", <<-LUA)
        return {
          wrap = function(text, tag)
            return "<" .. tag .. ">" .. text .. "</" .. tag .. ">"
          end,
        }
        LUA
      state = lua_spec_state(path)
      result = state.call_function("wrap", Crinja::Value.new("hi"), [Crinja::Value.new("em")] of Crinja::Value)
      result.as_s.should eq "<em>hi</em>"
    end

    it "returns integral numbers as integers, not floats" do
      dir = lua_spec_dir("ints")
      path = lua_spec_write(dir, "i.lua", <<-LUA)
        return {
          five = function()
            return 5
          end,
        }
        LUA
      state = lua_spec_state(path)
      result = state.call_function("five", Crinja::Value.new(nil), [] of Crinja::Value)
      result.raw.should be_a(Int64)
      result.raw.should eq 5
    end

    it "keeps fractional numbers as floats" do
      dir = lua_spec_dir("floats")
      path = lua_spec_write(dir, "f.lua", <<-LUA)
        return {
          half = function()
            return 0.5
          end,
        }
        LUA
      state = lua_spec_state(path)
      result = state.call_function("half", Crinja::Value.new(nil), [] of Crinja::Value)
      result.raw.should be_a(Float64)
    end

    it "round-trips arrays in both directions" do
      dir = lua_spec_dir("arrays")
      path = lua_spec_write(dir, "a.lua", <<-LUA)
        return {
          total = function(numbers)
            local sum = 0
            for _, value in ipairs(numbers) do
              sum = sum + value
            end
            return sum
          end,
          letters = function(text)
            local result = {}
            for char in text:gmatch(".") do
              table.insert(result, char)
            end
            return result
          end,
        }
        LUA
      state = lua_spec_state(path)

      total = state.call_function("total", Crinja::Value.new([1, 2, 3, 4]), [] of Crinja::Value)
      total.raw.should eq 10

      letters = state.call_function("letters", Crinja::Value.new("abc"), [] of Crinja::Value)
      letters.as_a.map(&.as_s).join.should eq "abc"
    end

    it "converts dictionaries to hashes on the way out" do
      dir = lua_spec_dir("dicts_out")
      path = lua_spec_write(dir, "d.lua", <<-LUA)
        return {
          info = function()
            return { name = "spike", version = 2 }
          end,
        }
        LUA
      state = lua_spec_state(path)
      result = state.call_function("info", Crinja::Value.new(nil), [] of Crinja::Value)
      result.as_h["name"].as_s.should eq "spike"
      result.as_h["version"].raw.should be_a(Int64)
    end

    it "passes dictionaries in as Lua tables" do
      dir = lua_spec_dir("dicts_in")
      path = lua_spec_write(dir, "e.lua", <<-LUA)
        return {
          pick_name = function(record)
            return record.name
          end,
        }
        LUA
      state = lua_spec_state(path)
      record = Crinja.value({"name" => "nicolino"})
      result = state.call_function("pick_name", record, [] of Crinja::Value)
      result.as_s.should eq "nicolino"
    end

    it "supports boolean and nil returns" do
      dir = lua_spec_dir("bools")
      path = lua_spec_write(dir, "b.lua", <<-LUA)
        return {
          yes = function()
            return true
          end,
          nothing = function()
            return nil
          end,
        }
        LUA
      state = lua_spec_state(path)
      state.call_function("yes", Crinja::Value.new(nil), [] of Crinja::Value).raw.should be_true
      state.call_function("nothing", Crinja::Value.new(nil), [] of Crinja::Value).raw.should be_nil
    end
  end

  describe "error reporting" do
    it "names the missing filter and lists what exists" do
      dir = lua_spec_dir("unknown")
      path = lua_spec_write(dir, "u.lua", <<-LUA)
        return {
          existing = function(text)
            return text
          end,
        }
        LUA
      state = lua_spec_state(path)
      ex = expect_raises(Exception, /'missing'.*existing/m) do
        state.call_function("missing", Crinja::Value.new("x"), [] of Crinja::Value)
      end
      (ex.message || "").should contain "Available: existing"
    end

    it "reports syntax errors with the script path" do
      dir = lua_spec_dir("syntax")
      path = lua_spec_write(dir, "broken.lua", "return { oops = function() return . end }")
      state = lua_spec_state(path)
      ex = expect_raises(Exception, /syntax error in .*broken\.lua/) do
        state.filter_names
      end
      (ex.message || "").should contain "unexpected symbol"
    end

    it "rejects scripts that do not return a table" do
      dir = lua_spec_dir("nontable")
      path = lua_spec_write(dir, "n.lua", "return 42")
      state = lua_spec_state(path)
      expect_raises(Exception, /must return a table/) do
        state.filter_names
      end
    end

    it "wraps runtime errors with the filter name" do
      dir = lua_spec_dir("runtime")
      path = lua_spec_write(dir, "r.lua", <<-LUA)
        return {
          boom = function(text)
            error("kaboom")
          end,
        }
        LUA
      state = lua_spec_state(path)
      expect_raises(Exception, /Lua filter 'boom' failed:.*kaboom/m) do
        state.call_function("boom", Crinja::Value.new("x"), [] of Crinja::Value)
      end
    end
  end

  describe "reloading" do
    it "fires the rebuild signal once per detected change" do
      LuaSpecCleanup.reset_modified
      dir = lua_spec_dir("reload")
      path = lua_spec_write(dir, "c.lua", "return { label = function(text) return text end }")
      state = lua_spec_state(path)

      # Building consumes no change signal
      state.filter_names.should eq ["label"]
      state.scripts_changed_since_build?.should be_false

      # One reported modification fires exactly once even though
      # Croupier keeps the entry in its set for a whole cycle
      Croupier::TaskManager.modified.add(path)
      state.scripts_changed_since_build?.should be_true
      state.scripts_changed_since_build?.should be_false

      # When the cycle ends and the entry leaves the modified set, a
      # new report fires again instead of being swallowed forever
      Croupier::TaskManager.modified.delete(path)
      state.scripts_changed_since_build?.should be_false
      Croupier::TaskManager.modified.add(path)
      state.scripts_changed_since_build?.should be_true

      LuaSpecCleanup.reset_modified
    end

    it "picks up edited function bodies after a rebuild" do
      LuaSpecCleanup.reset_modified
      dir = lua_spec_dir("edit")
      path = lua_spec_write(dir, "g.lua", <<-LUA)
        return {
          greet = function(text)
            return "hello " .. text
          end,
        }
        LUA
      state = lua_spec_state(path)
      state.call_function("greet", Crinja::Value.new("world"), [] of Crinja::Value).as_s.should eq "hello world"

      lua_spec_write(dir, "g.lua", <<-LUA)
        return {
          greet = function(text)
            return "goodbye " .. text
          end,
        }
        LUA
      Croupier::TaskManager.modified.add(path)
      state.call_function("greet", Crinja::Value.new("world"), [] of Crinja::Value).as_s.should eq "goodbye world"
      LuaSpecCleanup.reset_modified
    end
  end

  describe "multiple scripts" do
    it "unions exports across files and resolves collisions by load order" do
      dir = lua_spec_dir("multi")
      first = lua_spec_write(dir, "aaa.lua", <<-LUA)
        return {
          shared = function(text)
            return "from-aaa:" .. text
          end,
          only_a = function(text)
            return text
          end,
        }
        LUA
      second = lua_spec_write(dir, "zzz.lua", <<-LUA)
        return {
          shared = function(text)
            return "from-zzz:" .. text
          end,
        }
        LUA
      state = lua_spec_state(first, second)

      state.filter_names.should eq ["only_a", "shared"]
      result = state.call_function("shared", Crinja::Value.new("x"), [] of Crinja::Value)
      result.as_s.should eq "from-zzz:x"
    end
  end

  describe "#close" do
    it "is safe to call more than once" do
      dir = lua_spec_dir("close")
      path = lua_spec_write(dir, "q.lua", "return { id = function(text) return text end }")
      state = lua_spec_state(path)
      state.filter_names.should eq ["id"]
      state.close
      state.close
    end
  end
end
