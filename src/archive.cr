require "./markdown"
require "./theme"
require "./utils"
require "./render"
require "lexbor"

module Archive
  include Utils

  # Individual post entry in archive
  record ArchivePost,
    title : String,
    link : String,
    date : String do
    def self.from_post(post : Markdown::File) : self
      post_date = post.date
      raise "Archive post #{post.source} has no date (required for archive)" unless post_date.is_a?(Time)
      new(
        title: post.title,
        link: post.link,
        date: post_date.to_s("%Y-%m-%d")
      )
    end

    def to_h : Hash(String, String)
      {
        "title" => title,
        "link"  => link,
        "date"  => date,
      }
    end
  end

  # Month containing posts
  record ArchiveMonth,
    name : String,
    posts : Array(ArchivePost) do
    def self.create(year : Int32, month : Int32, posts : Array(Markdown::File)) : self
      month_name = "#{year}-#{month.to_s.rjust(2, '0')}"
      archive_posts = posts.map { |post| ArchivePost.from_post(post) }
      new(name: month_name, posts: archive_posts)
    end

    def to_h : Hash(String, String | Array(Hash(String, String)))
      {
        "name"  => name,
        "posts" => posts.map(&.to_h),
      }
    end
  end

  # Year containing months
  record ArchiveYear,
    year : String,
    months : Array(ArchiveMonth) do
    def self.create(year : Int32, months_data : Hash(String, Array(Markdown::File))) : self
      sorted_months = months_data.keys.sort!.reverse!
      archive_months = sorted_months.map do |month_key|
        month_num = month_key.split("-")[1].to_i
        ArchiveMonth.create(year, month_num, months_data[month_key])
      end
      new(year: year.to_s, months: archive_months)
    end

    def to_h : Hash(String, String | Array(Hash(String, String | Array(Hash(String, String)))))
      {
        "year"   => year,
        "months" => months.map(&.to_h),
      }
    end
  end

  # Register output folder to exclude from folder_indexes
  FolderIndexes.register_exclude { Config.archive }

  # Enable archive feature if posts are available
  def self.enable(is_enabled : Bool, posts : Array(Markdown::File))
    return unless is_enabled

    Log.info { "📅 Building archive..." }
    render(posts)
    Log.info { "✓ Archive queued" }
  end

  def self.render(posts : Array(Markdown::File))
    # Generate archive for each language
    Config.languages.each do |lang|
      base_path = Path[Config.options(lang).output]
      # Make output path language-specific to avoid conflicts
      lang_suffix = Utils.lang_suffix(lang)
      output_path = (base_path / "#{Config.archive.rstrip('/')}#{lang_suffix}" / "index.html").normalize.to_s

      # Collect all dependencies from all posts (no eager date loading)
      all_dependencies = posts.flat_map(&.dependencies)

      archive_template = Theme.template_path("archive.tmpl")
      title_template = Theme.template_path("title.tmpl")
      page_template = Theme.template_path("page.tmpl")

      FeatureTask.new(
        feature_name: "archive",
        id: "archive",
        output: output_path,
        inputs: all_dependencies + [
          "kv://#{archive_template}",
          "kv://#{title_template}",
          "kv://#{page_template}",
        ],
        mergeable: false
      ) do
        # Filter posts that have dates (done during task execution)
        dated_posts = posts.select { |post| !post.date.nil? }

        # If no posts with dates, don't generate archive
        if dated_posts.empty?
          Log.info { "No posts with dates found, skipping archive generation" }
          next
        end

        # Group posts by year and month using proper structures
        years_data = Hash(Int32, Hash(String, Array(Markdown::File))).new

        dated_posts.each do |post|
          # dated_posts is filtered above; coalesce for the type system
          post_date = post.date || Time.unix(0)
          year = post_date.year
          month_key = post_date.to_s("%Y-%m")

          years_data[year] ||= Hash(String, Array(Markdown::File)).new
          years_data[year][month_key] ||= [] of Markdown::File
          years_data[year][month_key] << post
        end

        # Sort each month's posts newest first, with the output path as
        # a tiebreaker: content reading is parallel, so the input order
        # of same-date posts is not stable
        years_data.each_value do |months|
          months.each_value do |month_posts|
            month_posts.sort_by! { |post| {post.date || Time.unix(0), post.output} }.reverse!
          end
        end

        # Create ArchiveYear records
        sorted_years = years_data.keys.sort!.reverse!
        archive_years = sorted_years.map do |year|
          ArchiveYear.create(year, years_data[year])
        end

        # Get the latest year for the default open state
        latest_year = sorted_years.first?.try(&.to_s) || ""

        Log.info { "👉 #{output_path}" }

        # Create breadcrumbs for archive
        archive_link = "/#{Config.archive.rstrip('/')}#{lang_suffix}/"
        breadcrumbs = Render.section_breadcrumbs("Archive", archive_link)

        # Include title.tmpl which handles breadcrumbs
        title_html = Render.title_html("Archive", archive_link, breadcrumbs)

        # Render the archive template
        archive_template = Theme.template_path("archive.tmpl")
        rendered = Templates.environment.get_template(archive_template).render({
          "years"       => archive_years.map(&.to_h),
          "latest_year" => latest_year,
        })

        # Apply to page template with HTML filters
        Render.page_html(archive_link, title_html + rendered, "Archive", breadcrumbs, lang)
      end
    end
  end
end
