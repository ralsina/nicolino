require "cr-wren/src/wren.cr"

module Vm
  # A subclass of Wren::VM that integrates logging with the rest of Nicolino
  class VM < Wren::VM
    @error_fn = ->(_vm : API::WrenVM, type : API::WrenErrorType, _module : LibC::Char*, line : LibC::Int32T, msg : LibC::Char*) : Nil {
      msg = String.new(msg)
      _module = String.new(_module) if _module
      case type
      when API::WrenErrorType::WREN_ERROR_COMPILE
        Log.error { "Wren compilation error: #{_module} line #{line}] [Error] #{msg}" }
      when API::WrenErrorType::WREN_ERROR_STACK_TRACE
        Log.error { "  #{_module} line #{line}] #{msg}" }
      when API::WrenErrorType::WREN_ERROR_RUNTIME
        Log.error { "[Wren Runtime Error] #{msg}" }
      end
      raise "Wren Error"
    }

    def _cast_value(v : Crinja::Value)
      case v
      when .string?            then v.as_s?
      when .number?            then v.as_number
      when .none?, .undefined? then nil
      when .truthy?            then true
      else                          false
      end
    end

    # Convert Crinja::Arguments into an array of normal basic types
    def parse_args(arguments : Crinja::Arguments)
      [arguments.target.to_s] + arguments.to_h.keys.sort!.map { |k|
        _cast_value(arguments[k])
      }
    end
  end
end
