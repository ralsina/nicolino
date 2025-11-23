require "../src/gallery"
require "../src/config"
require "file_utils"
require "tempfile"

describe Gallery do
  describe Gallery::Gallery do
    describe "#initialize" do
      it "creates a gallery with basic properties" do
        sources = ["test.md"]
        base = Path["/test/gallery/index.md"]
        images = ["image1.jpg", "image2.png"]
        sub_galleries = [] of Gallery::Gallery

        gallery = Gallery::Gallery.new(sources, base, images, sub_galleries)

        gallery.image_list.should eq(images)
        gallery.sub_galleries.should eq(sub_galleries)
        gallery.parent_gallery.should be_nil
      end

      it "sets parent relationships for sub-galleries" do
        sources = ["test.md"]
        base = Path["/test/gallery/index.md"]
        images = [] of String

        sub_gallery1 = Gallery::Gallery.new(["sub1.md"], Path["/test/gallery/sub1/index.md"], [] of String)
        sub_gallery2 = Gallery::Gallery.new(["sub2.md"], Path["/test/gallery/sub2/index.md"], [] of String)

        gallery = Gallery::Gallery.new(sources, base, images, [sub_gallery1, sub_gallery2])

        sub_gallery1.parent_gallery.should eq(gallery)
        sub_gallery2.parent_gallery.should eq(gallery)
      end
    end

    describe "helper methods" do
      it "detects when gallery has sub-galleries" do
        sub_gallery = Gallery::Gallery.new(["sub.md"], Path["/test/sub/index.md"], [] of String)
        gallery = Gallery::Gallery.new(["main.md"], Path["/test/main/index.md"], [] of String, [sub_gallery])

        gallery.has_sub_galleries?.should be_true
        sub_gallery.has_sub_galleries?.should be_false
      end

      it "detects when gallery has images" do
        gallery_with_images = Gallery::Gallery.new(["main.md"], Path["/test/main/index.md"], ["img1.jpg"])
        gallery_without_images = Gallery::Gallery.new(["main.md"], Path["/test/main/index.md"], [] of String)

        gallery_with_images.has_images?.should be_true
        gallery_without_images.has_images?.should be_false
      end

      it "calculates gallery depth correctly" do
        root_gallery = Gallery::Gallery.new(["root.md"], Path["/test/root/index.md"], [] of String)
        sub_gallery = Gallery::Gallery.new(["sub.md"], Path["/test/sub/index.md"], [] of String)
        sub_sub_gallery = Gallery::Gallery.new(["subsub.md"], Path["/test/subsub/index.md"], [] of String)

        sub_gallery.parent_gallery = root_gallery
        sub_sub_gallery.parent_gallery = sub_gallery

        root_gallery.depth.should eq(0)
        sub_gallery.depth.should eq(1)
        sub_sub_gallery.depth.should eq(2)
      end
    end

    describe "#breadcrumbs" do
      it "generates breadcrumbs for root gallery" do
        # Mock the necessary config and utilities
        gallery = Gallery::Gallery.new(["test.md"], Path["/galleries/test/index.md"], [] of String)

        # This test would need more mocking of Config and Utils
        # For now, we test that the method exists and returns an array
        breadcrumbs = gallery.breadcrumbs
        breadcrumbs.should be_a(Array(NamedTuple(name: String, link: String)))
      end
    end

    describe "#value" do
      it "includes gallery-specific data in template values" do
        images = ["img1.jpg", "img2.png"]
        gallery = Gallery::Gallery.new(["test.md"], Path["/test/gallery/index.md"], images)

        value = gallery.value

        value.should have_key("image_list")
        value.should have_key("sub_galleries")
        value.should have_key("breadcrumbs")
        value["image_list"].should eq(images)
        value["sub_galleries"].should be_a(Array)
      end
    end
  end

  describe Gallery do
    describe "#read_all" do
      it "handles empty directory gracefully" do
        # Create a temporary directory for testing
        temp_dir = Dir.tempdir + "/empty_galleries"
        FileUtils.mkdir_p(temp_dir)

        begin
          galleries = Gallery.read_all(temp_dir)
          galleries.should be_empty
        ensure
          FileUtils.rm_rf(temp_dir)
        end
      end

      it "finds galleries in nested directory structure" do
        # Create a temporary directory structure
        temp_dir = Dir.tempdir + "/nested_galleries"
        FileUtils.mkdir_p("#{temp_dir}/parent/child")

        # Create gallery index files
        File.write("#{temp_dir}/parent/index.md", "# Parent Gallery")
        File.write("#{temp_dir}/parent/child/index.md", "# Child Gallery")

        # Create some test images
        File.write("#{temp_dir}/parent/img1.jpg", "fake image content")
        File.write("#{temp_dir}/parent/child/img2.jpg", "fake image content")

        begin
          galleries = Gallery.read_all(temp_dir)

          # Should find root-level galleries
          galleries.size.should eq(1)

          parent_gallery = galleries.first
          parent_gallery.base.to_s.should contain("parent/index.md")
          parent_gallery.sub_galleries.size.should eq(1)

          child_gallery = parent_gallery.sub_galleries.first
          child_gallery.base.to_s.should contain("child/index.md")
          child_gallery.parent_gallery.should eq(parent_gallery)
        ensure
          FileUtils.rm_rf(temp_dir)
        end
      end
    end

    describe "#collect_all_galleries" do
      it "collects all galleries recursively" do
        root_gallery = Gallery::Gallery.new(["root.md"], Path["/root/index.md"], [] of String)
        child1 = Gallery::Gallery.new(["child1.md"], Path["/child1/index.md"], [] of String)
        child2 = Gallery::Gallery.new(["child2.md"], Path["/child2/index.md"], [] of String)
        grandchild = Gallery::Gallery.new(["grandchild.md"], Path["/grandchild/index.md"], [] of String)

        root_gallery.sub_galleries = [child1, child2]
        child1.sub_galleries = [grandchild]

        all_galleries = Gallery.collect_all_galleries([root_gallery])
        all_galleries.size.should eq(4)
        all_galleries.should contain(root_gallery)
        all_galleries.should contain(child1)
        all_galleries.should contain(child2)
        all_galleries.should contain(grandchild)
      end
    end
  end
end
