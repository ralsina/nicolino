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
  end
end
