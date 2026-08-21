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
