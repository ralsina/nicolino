require "./spec_helper"

describe DateUtils do
  describe ".parse" do
    it "returns nil for nil input" do
      DateUtils.parse(nil).should be_nil
    end

    it "returns nil for empty strings" do
      DateUtils.parse("").should be_nil
    end

    it "parses ISO 8601 dates" do
      DateUtils.parse("2022-01-01T00:00:00Z").should eq(Time.utc(2022, 1, 1))
    end

    it "parses RFC 2822 dates" do
      parsed = DateUtils.parse("Wed, 02 Oct 2002 13:00:00 GMT")
      parsed.should_not be_nil
      parsed.try(&.to_utc).should eq(Time.utc(2002, 10, 2, 13, 0, 0))
    end

    it "parses Pocketbase-style dates" do
      parsed = DateUtils.parse("2026-01-29 11:57:28.164Z")
      parsed.should_not be_nil
      parsed.try(&.year).should eq(2026)
      parsed.try(&.month).should eq(1)
      parsed.try(&.day).should eq(29)
    end

    it "parses date-only strings as local midnight" do
      DateUtils.parse("2020-02-02").should eq(Time.local(2020, 2, 2))
    end

    it "parses date and time strings without a zone as local time" do
      DateUtils.parse("2020-02-02 10:30").should eq(Time.local(2020, 2, 2, 10, 30))
      DateUtils.parse("2020-02-02 10:30:15").should eq(Time.local(2020, 2, 2, 10, 30, 15))
      DateUtils.parse("2020-02-02T10:30:15").should eq(Time.local(2020, 2, 2, 10, 30, 15))
    end

    it "keeps the offset of zoned ISO 8601 strings" do
      parsed = DateUtils.parse("2024-07-23T15:00:00.000Z")
      parsed.should eq(Time.utc(2024, 7, 23, 15, 0, 0))
      parsed = DateUtils.parse("2020-02-02T10:30:00-03:00")
      parsed.try(&.to_utc).should eq(Time.utc(2020, 2, 2, 13, 30, 0))
    end

    it "parses the Time#to_s shapes the front matter loader produces" do
      DateUtils.parse(Time.utc(2020, 2, 2).to_s).should eq(Time.utc(2020, 2, 2))
      DateUtils.parse("2020-02-02 10:30:00 -03:00").try(&.to_utc).should eq(Time.utc(2020, 2, 2, 13, 30))
    end

    it "parses the common shapes without the natural language parser" do
      # 1000 strict parses must stay far below one Cronic parse (~2.5ms)
      start = Time.instant
      1000.times { DateUtils.parse("2020-02-02T10:30:15") }
      1000.times { DateUtils.parse("2020-02-02 00:00:00 UTC") }
      (Time.instant - start).should be < 50.milliseconds
    end

    it "parses natural language dates via Cronic" do
      parsed = DateUtils.parse("2 weeks ago")
      parsed.should_not be_nil
      two_weeks = Time.utc - 2.weeks
      (parsed - two_weeks).abs.should be < 1.day if parsed
    end

    it "returns nil for unparseable input" do
      DateUtils.parse("not a date at all 42 ??").should be_nil
    end
  end
end
