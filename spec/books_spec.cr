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

  describe ".prints_toc_verbatim?" do
    it "accepts templates that only print or truth-test the TOC" do
      [
        %(<nav>{{ toc_html|safe }}</nav>{{- sidebar_content | safe -}}),
        %(<p>{{ chapter.content|safe }}</p>),
        %({# Variables: toc_html, chapter #}<nav>{{ toc_html|safe }}</nav>),
        %({% if sidebar_content %}<div>{{ sidebar_content }}</div>{% endif %}),
      ].each do |source|
        Books.prints_toc_verbatim?(source).should be_true, source
      end
    end

    it "rejects templates that do anything else with it" do
      [
        %({{ toc_html|replace("toc-link", "x")|safe }}),
        %({% if toc_html|length > 10 %}x{% endif %}),
        %({% set t = sidebar_content %}),
        %({% if not toc_html %}x{% endif %}),
      ].each do |source|
        Books.prints_toc_verbatim?(source).should be_false, source
      end
    end

    it "rejects plain prints when the template autoescapes" do
      Books.prints_toc_verbatim?(%({{ toc_html }}), autoescape: true).should be_false
      Books.prints_toc_verbatim?(%({{ toc_html|safe }}), autoescape: true).should be_true
    end
  end

  describe "Templates::DependencyVisitor#dynamic_references?" do
    it "is set only when an include can't be resolved statically" do
      static = Templates::DependencyVisitor.new("kv://t.tmpl")
      static.dependencies(%({% include "title.tmpl" %}))
      static.dynamic_references?.should be_false

      dynamic = Templates::DependencyVisitor.new("kv://t.tmpl")
      dynamic.dependencies(%({% include sidebar_template %}))
      dynamic.dynamic_references?.should be_true
    end
  end

  describe ".markers_survive?" do
    it "is true only when every marker parsed as a comment" do
      m = Books::TOC_MARKER
      {
        %(<nav>#{m}</nav>)                          => true,
        %(<nav>#{m}</nav><aside>#{m}</aside>)       => true,
        %(<p>no toc here</p>)                       => true,
        %(<textarea>#{m}</textarea>)                => false,
        %(<script>var t = "#{m}";</script>)         => false,
        %(<title>#{m}</title>)                      => false,
        %(<nav>#{m}</nav><textarea>#{m}</textarea>) => false,
      }.each do |html, expected|
        doc = Lexbor::Parser.new(html)
        Books.markers_survive?(doc, html).should eq(expected), html
        doc.free
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
