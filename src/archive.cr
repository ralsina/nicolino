require "./markdown"
require "./theme"
require "./utils"
require "lexbor"

module Archive
  include Utils

  # Individual post entry in archive
  record ArchivePost,
    title : String,
    link : String,
    date : String do
    def self.from_post(post : Markdown::File) : self
      post_date = post.date.as(Time)
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
  FolderIndexes.register_exclude("archive/")

  # Enable archive feature if posts are available
  def self.enable(is_enabled : Bool, posts : Array(Markdown::File))
    return unless is_enabled

    Log.info { "📅 Building archive..." }
    render(posts)
    Log.info { "✓ Archive queued" }
  end

  def self.render(posts : Array(Markdown::File))
    # Generate archive for each language
    Config.languages.keys.each do |lang|
      base_path = Path[Config.options(lang).output]
      # Make output path language-specific to avoid conflicts
      lang_suffix = lang == "en" ? "" : ".#{lang}"
      output_path = (base_path / "archive#{lang_suffix}" / "index.html").normalize.to_s

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
          post_date = post.date.as(Time)
          year = post_date.year
          month_key = post_date.to_s("%Y-%m")

          years_data[year] ||= Hash(String, Array(Markdown::File)).new
          years_data[year][month_key] ||= [] of Markdown::File
          years_data[year][month_key] << post
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
        archive_link = "/archive#{lang_suffix}/"
        breadcrumbs = [{name: "Home", link: "/"}, {name: "Archive", link: archive_link}] of NamedTuple(name: String, link: String)

        # Include title.tmpl which handles breadcrumbs
        title_template = Theme.template_path("title.tmpl")
        title_html = Templates.environment.get_template(title_template).render({
          "title"       => "Archive",
          "link"        => archive_link,
          "breadcrumbs" => breadcrumbs,
          "taxonomies"  => [] of NamedTuple(name: String, link: NamedTuple(link: String, title: String)),
        })

        # Render the archive template
        archive_template = Theme.template_path("archive.tmpl")
        rendered = Templates.environment.get_template(archive_template).render({
          "years"       => archive_years.map(&.to_h),
          "latest_year" => latest_year,
        })

        # Apply to page template
        page_template = Theme.template_path("page.tmpl")
        html = Render.apply_template(page_template, {
          "content"     => title_html + rendered,
          "title"       => "Archive",
          "breadcrumbs" => breadcrumbs,
        })

        # Process with HTML filters
        doc = Lexbor::Parser.new(html)
        doc = HtmlFilters.make_links_relative(doc, archive_link)
        doc.to_html
      end
    end
  end
end
