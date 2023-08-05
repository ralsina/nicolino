module Locale
    def self.language(language : String | Nil = nil)
        return @@current_language = language unless language.nil?
        @@current_language
    end
end
