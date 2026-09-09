require "./spec_helper"

require "../src/video"

describe Video do
  describe ".video?" do
    it "recognizes video extensions" do
      %w[clip.mp4 Clip.MOV v.webm x.mkv y.m4v z.AVI].each do |name|
        Video.video?(name).should be_true, "#{name} should be a video"
      end
    end

    it "rejects non-video extensions" do
      %w[photo.jpg photo.JPG clip.mp3 page.html video].each do |name|
        Video.video?(name).should be_false, "#{name} should not be a video"
      end
    end

    it "matches extension case-insensitively" do
      Video.video?("clip.Mp4").should be_true
    end
  end

  describe ".poster_name" do
    around_each do |example|
      tmp = Path["/tmp/opencode", "spec-#{Random::Secure.hex(6)}"]
      FileUtils.mkdir_p(tmp)
      File.write(tmp / "conf.yml", "content: content/\noutput: output/\n")
      Dir.cd(tmp) do
        Config.reload
        begin
          example.run
        ensure
          FileUtils.rm_rf(tmp)
        end
      end
    end

    it "uses the plain thumb name when no image shares the stem" do
      dir = Path["gallery"]
      FileUtils.mkdir_p(dir)
      File.write(dir / "clip.mp4", "fake")
      Video.poster_name(dir / "clip.mp4").should eq "clip.thumb.jpg"
    end

    it "avoids clashing with an image thumb sharing the stem" do
      dir = Path["gallery"]
      FileUtils.mkdir_p(dir)
      File.write(dir / "clip.mp4", "fake")
      File.write(dir / "clip.jpg", "fake")
      Video.poster_name(dir / "clip.mp4").should eq "clip.video.thumb.jpg"
    end

    it "is not fooled by a different-stemmed image" do
      dir = Path["gallery"]
      FileUtils.mkdir_p(dir)
      File.write(dir / "clip.mp4", "fake")
      File.write(dir / "other.jpg", "fake")
      Video.poster_name(dir / "clip.mp4").should eq "clip.thumb.jpg"
    end
  end
end
