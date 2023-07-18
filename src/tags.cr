# Module for tags
# TODO: generalize to taxonomies

module Tag
  struct Tag
    @posts = Array(String).new
  end

  def self.read_all(posts)
    tags = Hash(String, Tag).new
    posts.each do |post|
      post_tags = post.@metadata.fetch("tags", "[]")
      Array(String).from_yaml(post_tags).each do |t|
        tags[t] = Tag.new unless tags.has_key? t
        tags[t].@posts << post.@source
      end
    end
    tags
  end

  def self.render(tags : Hash(String, Tag))
    tags.map { |name, tag|
      "output/tags/#{name}/index.html"
      Markdown.render_index(
        tag.@posts[..10].map {|p| Markdown::File.posts[p]},
        "output/tags/#{name}/index.html",
        "Posts tagged '#{name}'"
      )
    }
  end
end
