module Utils
  def self.slugify(string)
    string.downcase.strip.gsub(' ', '-').gsub(/[^\w]/, '-').gsub(/-+/, '-')
  end

  # Convert path to link
  #
  # >> path_to_link("output/foo/../bar") # => "/bar"
  def self.path_to_link(path, extension = nil)
    p = Path[path].normalize
    raise "Invalid path: #{path}" unless p.parts[0] == "output"

    return "/#{p.parts[1..].join("/")}" if extension.nil?
    "/#{p.parts[1..].join("/").rchop(p.extension)}#{extension}"
  end
end
