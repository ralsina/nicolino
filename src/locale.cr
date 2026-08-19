module Locale
  def self.language(language : String? = nil)
    return @@current_language = language unless language.nil?
    # ameba:disable Documentation/DocumentationAdmonition
    # FIXME: support LANG environment variable / config setting
    @@current_language ||= "en"
  end
end
