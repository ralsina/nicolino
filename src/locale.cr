module Locale
  def self.language(language : String | Nil = nil)
    return @@current_language = language unless language.nil?
    # FIXME: support LANG environment variable / config setting
    @@current_language ||= "en"
  end
end
