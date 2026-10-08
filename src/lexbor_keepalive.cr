require "lexbor"

# lexbor's Node#to_html hands the raw element pointer to
# lxb_html_serialize_tree_cb and then never touches the Node (or its
# Parser) again, so in release builds nothing keeps the Parser
# reachable while lexbor serializes. The serialize callback allocates
# (it writes into an IO), a collection can run mid-serialization, and
# the Parser's finalizer frees the document lexbor is still walking:
# parallel builds then fail with "Unknown problem with serialization:
# LXB_STATUS_ERROR" or segfault in lxb_html_serialize_cb.
#
# Same body as upstream, plus an empty asm that reads the Parser and
# the IO wrapper after the call so both stay live until it returns.
struct Lexbor::Node
  def to_html(io : IO, deep = true)
    iow = IOWrapper.new(io)
    parser = @parser
    status = if deep
               Lib.serialize_tree_cb(@element, SERIALIZE_CALLBACK, iow.as(Void*))
             else
               Lib.serialize_cb(@element, SERIALIZE_CALLBACK, iow.as(Void*))
             end
    asm("" :: "r"(parser.as(Void*)), "r"(iow.as(Void*)) :: "volatile")

    if status != Lib::StatusT::LXB_STATUS_OK
      raise LibError.new("Unknown problem with serialization: #{status}")
    end

    self
  end
end
