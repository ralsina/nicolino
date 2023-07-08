@[Link("markdown")]
lib Discount
  fun mkd_string(buffer : Pointer(LibC::Char), size : Int32, flags : Int32) : Void*
  fun mkd_compile(doc : Void*, flags : Int32) : Int32
  fun mkd_document(doc : Void*, html : Pointer(Pointer(LibC::Char))) : Int32
  fun mkd_cleanup(doc : Void*)
end
