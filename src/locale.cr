module Locale
  def self.language(language : String? = nil)
    return @@current_language = language unless language.nil?
    # FIXME: support LANG environment variable / config setting
    @@current_language ||= Config.default_lang
  end
end
