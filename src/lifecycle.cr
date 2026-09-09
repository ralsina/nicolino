require "./markdown"
require "./date_utils"

# Content lifecycle management for posts (issue #46)
#
# A post can be excluded from the build because it is:
#
# * a draft: it has `draft: true` (or `yes`, `on`, `1`) in its front
#   matter, unless the build was started with `--drafts`
# * in the future: its date is after the current time, unless the
#   build was started with `--future`
# * expired: it has an `expires` date in its front matter (anything
#   DateUtils can parse, including natural language dates like
#   "2026-12-31" or "next week") and that date has passed
#
# The flags live here because they are set by the build/auto commands
# before tasks are created, and consulted during Posts.enable_from_scan.
module Lifecycle
  class_property? include_drafts : Bool = false
  class_property? include_future : Bool = false

  # Truthy front-matter values for the draft flag
  TRUTHY = {"true", "yes", "on", "1"}

  def self.apply(posts : Array(Markdown::File)) : Array(Markdown::File)
    posts.reject do |post|
      excluded?(post).tap do |reason|
        Log.info { "⏭  Skipping #{File.basename(post.source)}: #{reason}" } if reason
      end
    end
  end

  # Returns nil if the post should be built, or the reason it is
  # excluded.
  def self.excluded?(post : Markdown::File) : String?
    return "it's a draft" if !include_drafts? && draft?(post)

    if date = post.date
      return "its date is in the future" if !include_future? && date > Time.local
    end

    if expires_at = expires_at(post)
      return "it expired at #{expires_at}" if expires_at < Time.local
    end

    nil
  end

  private def self.draft?(post : Markdown::File) : Bool
    TRUTHY.includes?(post.metadata.fetch("draft", "").downcase)
  end

  private def self.expires_at(post : Markdown::File) : Time?
    DateUtils.parse(post.metadata.fetch("expires", "")) if post.metadata.has_key?("expires")
  end
end
