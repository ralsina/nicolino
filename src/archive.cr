require "./markdown"
require "./utils"
require "lexbor"

module Archive
  include Utils

  def self.render(posts : Array(Markdown::File))
    # Filter posts that have dates
    dated_posts = posts.select { |post| !post.date.nil? }

    # If no posts with dates, don't generate archive
    if dated_posts.empty?
      Log.info { "No posts with dates found, skipping archive generation" }
      return
    end

    # Group posts by year and month
    years_hash = Hash(Int32, Hash(String, Array(Hash(String, String)))).new

    dated_posts.each do |post|
      post_date = post.date.as(Time)
      year = post_date.year
      month = post_date.to_s("%Y-%m")

      years_hash[year] ||= Hash(String, Array(Hash(String, String))).new
      years_hash[year][month] ||= [] of Hash(String, String)

      years_hash[year][month] << {
        "title" => post.title,
        "link"  => post.link,
        "date"  => post_date.to_s("%Y-%m-%d"),
      }
    end

    # Sort years in descending order (newest first)
    sorted_years = years_hash.keys.sort!.reverse!

    # Get the latest year for the default open state
    latest_year = sorted_years.first?.try(&.to_s) || ""

    # Build the data structure for the template
    years_data = sorted_years.map do |year|
      months = years_hash[year].keys.sort!.reverse!
      {
        "year"   => year.to_s,
        "months" => months.map do |month|
          {
            "name"  => month,
            "posts" => years_hash[year][month],
          }
        end,
      }
    end

    # Generate archive for each language
    Config.languages.keys.each do |lang|
      base_path = Path[Config.options(lang).output]
      output_path = (base_path / "archive" / "index.html").normalize.to_s

      Croupier::Task.new(
        id: "archive",
        output: output_path,
        inputs: dated_posts.flat_map(&.dependencies) + ["kv://templates/archive.tmpl", "kv://templates/page.tmpl"],
        mergeable: false
      ) do
        Log.info { "👉 #{output_path}" }

        # Render the archive template
        rendered = Templates.environment.get_template("templates/archive.tmpl").render({
          "years"       => years_data,
          "latest_year" => latest_year,
        })

        # Apply to page template
        html = Render.apply_template("templates/page.tmpl", {
          "content" => rendered,
          "title"   => "Archive",
        })

        # Process with HTML filters
        doc = Lexbor::Parser.new(html)
        doc = HtmlFilters.make_links_relative(doc, "/archive/")
        doc.to_html
      end
    end
  end
end
