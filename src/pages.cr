# Pages helper module for enabling pages feature
# This module reads and renders static pages from multiple sources

require "./markdown"
require "./html"
require "./pandoc"
require "./creatable"

module Pages
  # Enable pages feature
  # Render pages last because it's a catchall and will find gallery
  # posts, blog posts, etc.
  def self.enable(is_enabled : Bool, content_path : Path, feature_set : Set(Totem::Any))
    return unless is_enabled

    # Note: Pages are already registered by nicolino new command,
    # but features can register additional types here if needed

    # Convert Totem::Any set to string set for easier use
    features = feature_set.map(&.as_s).to_set

    # Read pages from multiple sources
    pages = Markdown.read_all(content_path)
    pages += HTML.read_all(content_path)
    pages += Pandoc.read_all(content_path) if features.includes?("pandoc")

    # Render pages without requiring dates
    Markdown.render(pages, require_date: false)
  end
end
