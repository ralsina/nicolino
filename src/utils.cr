module Utils
    def self.slugify(string)
        string.downcase.strip.gsub(' ', '-').gsub(/[^\w]/, '-').gsub(/-+/, '-')
    end
end
