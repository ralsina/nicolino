require "./spec_helper"

require "lexbor"
require "../src/books"

private def entry(title, path = nil, number = [] of Int32, level = 0, children = [] of Books::ChapterEntry)
  chapter = Books::ChapterEntry.new(title, path, number, level)
  chapter.children = children
  chapter
end

private def sample_book
  part = entry("Part One")
  part.part = true
  deep = entry("Deep > nested", "a/b/deep.md", [1, 2, 1], 2)
  group = entry("Group", "a/group.md", [1, 2], 1, [deep])
  untitled = entry("No page", nil, [1, 3], 1, [entry("Leaf", "a/leaf.md", [1, 3, 1], 2)])
  chapters = [
    entry("Intro", "intro.md", [] of Int32, 0),
    part,
    entry("Chapter one", "one.md", [1], 0, [group, untitled, entry("Draft", nil, [1, 4], 1)]),
    entry("Two", "two.md", [2], 0),
  ]
  Books::Book.new("guide", "Guide", chapters)
end

private def flat(entries : Array(Books::ChapterEntry)) : Array(Books::ChapterEntry)
  entries.flat_map { |chapter| [chapter] + flat(chapter.children) }
end

describe Books do
  describe ".serialized_toc" do
    it "matches the TOC after the lexbor pass, for every chapter page" do
      book = sample_book
      Books.toc_spliceable?(book).should be_true
      flat(book.chapters).select(&.has_content?).each do |current|
        page_link = current.link(book.name)
        raw = Books.render_toc_html(book.chapters, current, book.name)
        doc = HtmlFilters.make_links_relative(Lexbor::Parser.new(raw), page_link)
        Books.serialized_toc(book, current, page_link).should eq(HtmlFilters.fragment_html(doc)), page_link
      end
    end
  end

  describe ".toc_spliceable?" do
    it "rejects titles lexbor would parse or decode" do
      ["A <b>bold</b> title", "Q&amp;A", %(The "quoted" one)].each do |title|
        book = Books::Book.new("guide", "Guide", [entry(title, "x.md")])
        Books.toc_spliceable?(book).should be_false, title
      end
    end

    it "rejects a book whose TOC is empty" do
      part = entry("Only a part")
      part.part = true
      Books.toc_spliceable?(Books::Book.new("guide", "Guide", [part])).should be_false
    end
  end
end
