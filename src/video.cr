require "log"

# Create output for video files anywhere in content/
#
# Videos are copied verbatim to output/ (no transcoding) and a poster
# frame is extracted next to them with ffmpeg, so galleries can show a
# thumbnail the same way they do for images:
#
#   foo.mp4 => output/.../foo.mp4        (byte copy of the original)
#   foo.mp4 => output/.../foo.thumb.jpg  (poster frame, image_thumb wide)
#
# The ffmpeg dependency is only checked when video files exist, and is
# fatal when they do (like pandoc for non-markdown formats).
module Video
  # Extensions treated as video, matched case-insensitively
  VIDEO_EXTENSIONS = {".mp4", ".mov", ".webm", ".mkv", ".m4v", ".avi"}

  # Enable videos feature
  def self.enable(is_enabled : Bool, content_path : Path)
    return unless is_enabled

    videos = read_all(content_path)
    return if videos.empty?

    if Process.find_executable("ffmpeg").nil?
      # Library code raises instead of exiting (see src/config.cr);
      # the command layer maps the exception to an exit code.
      raise Config::ConfigError.new(
        "Video files found but ffmpeg is not installed, so poster frames can't be generated. " \
        "Please install ffmpeg or remove the videos from your content")
    end

    Log.info { "🎬 Processing videos..." }
    Log.info { "✓ Found #{videos.size} video#{videos.size == 1 ? "" : "s"}" }
    render(videos)
  end

  # Is this filename a video, by extension?
  def self.video?(path : String | Path) : Bool
    VIDEO_EXTENSIONS.includes?(File.extname(path.to_s).downcase)
  end

  # Name of the poster frame extracted for a video: foo.mp4 becomes
  # foo.thumb.jpg. When an image with the same stem lives in the same
  # folder, foo.video.thumb.jpg is used instead: the images feature's
  # own thumb task already owns the plain foo.thumb.jpg output, and
  # two tasks writing the same file would clobber each other.
  def self.poster_name(video : Path) : String
    stem = video.stem
    image_sibling = Dir.glob("#{video.parent}/*.{jpg,jpeg,png,webp,gif,JPG,JPEG,PNG,WEBP,GIF}").any? do |sibling|
      Path[sibling].stem == stem
    end
    stem + (image_sibling ? ".video.thumb.jpg" : ".thumb.jpg")
  end

  # Finds all videos in a path
  def self.read_all(path) : Array(Path)
    Log.debug { "Reading videos from #{path}" }
    videos = [] of Path
    Dir.glob("#{path}/**/*.{mp4,mov,webm,mkv,m4v,avi,MP4,MOV,WEBM,MKV,M4V,AVI}").each do |file|
      Log.debug { "👈 #{file}" }
      videos << Path[file]
    end
    videos
  end

  # Videos are copied verbatim and get a poster frame:
  # foo.mp4 => foo.mp4
  # foo.mp4 => foo.thumb.jpg
  def self.render(videos : Array(Path))
    videos.each do |video|
      src = video.to_s
      dest = Path[Config.options.output] / Path[video.parts[1..]]
      FeatureTask.new(
        feature_name: "videos",
        id: "video",
        output: dest.to_s,
        inputs: ["conf.yml", src],
        no_save: true,
        mergeable: true) do
        Log.info { "👉 #{dest}" }
        Dir.mkdir_p(File.dirname(dest))
        File.copy(src, dest)
        nil
      end

      poster = dest.parent / poster_name(video)
      FeatureTask.new(
        feature_name: "videos",
        id: "video_poster",
        output: poster.to_s,
        inputs: ["conf.yml", src],
        no_save: true,
        mergeable: true) do
        Log.info { "👉 #{poster}" }
        extract_poster(src, poster.to_s, Config.options.image_thumb)
        nil
      end
    end
  end

  # Extract a single frame scaled to `width` pixels wide (aspect kept)
  # with ffmpeg. Failures are logged by ffmpeg itself (-loglevel error
  # keeps it quiet otherwise) and leave the poster missing, which
  # templates handle by rendering the video without one.
  private def self.extract_poster(src : String, dest : String, width : Int32) : Nil
    status = Process.run("ffmpeg", [
      "-loglevel", "error",
      "-y",
      "-i", src,
      "-vframes", "1",
      "-vf", "scale=#{width}:-1",
      # ffmpeg 9+ refuses to overwrite a single image without this
      "-update", "1",
      dest,
    ])
    Log.warn { "Could not extract a poster frame from #{src}" } unless status.success?
  end
end
