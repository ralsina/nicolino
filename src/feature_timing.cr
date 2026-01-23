require "log"
require "croupier/src/task"

module FeatureTiming
  # Store timing data per feature
  @@enable_timings = Hash(String, Time::Span).new
  @@task_timings = Hash(String, Time::Span).new
  @@task_counts = Hash(String, Int32).new

  # Record time spent in a feature's enable() method
  def self.record_enable(feature_name : String, duration : Time::Span)
    @@enable_timings[feature_name] ||= Time::Span.zero
    @@enable_timings[feature_name] += duration
  end

  # Record time spent executing a task for a feature
  def self.record_task(feature_name : String, duration : Time::Span)
    @@task_timings[feature_name] ||= Time::Span.zero
    @@task_timings[feature_name] += duration
    @@task_counts[feature_name] ||= 0
    @@task_counts[feature_name] += 1
  end

  # Get total time for a feature (enable + tasks)
  def self.total_for(feature_name : String) : Time::Span
    enable_time = @@enable_timings[feature_name]? || Time::Span.zero
    task_time = @@task_timings[feature_name]? || Time::Span.zero
    enable_time + task_time
  end

  # Generate timing report as a table
  def self.report
    return if @@enable_timings.empty? && @@task_timings.empty?

    # Build feature data and sort by total time (descending)
    feature_data = (@@enable_timings.keys + @@task_timings.keys).uniq.map do |feature|
      enable_time = @@enable_timings[feature]? || Time::Span.zero
      task_time = @@task_timings[feature]? || Time::Span.zero
      task_count = @@task_counts[feature]? || 0
      feature_total = enable_time + task_time
      avg_time = task_count > 0 ? task_time / task_count : Time::Span.zero

      {
        name:   feature,
        total:  feature_total,
        enable: enable_time,
        tasks:  task_time,
        count:  task_count,
        avg:    avg_time,
      }
    end

    # Sort by total time descending
    feature_data.sort_by! { |feature_data_item| -feature_data_item[:total].total_milliseconds }

    total_time = Time::Span.zero
    total_tasks = 0

    # Build table data with header
    table_data = [["Feature", "Total", "Enable", "Tasks", "Count", "Avg"]]

    feature_data.each do |data|
      total_time += data[:total]
      total_tasks += data[:count]

      table_data << [
        data[:name],
        format_ms(data[:total]),
        format_ms(data[:enable]),
        format_ms(data[:tasks]),
        data[:count].to_s,
        format_ms(data[:avg]),
      ]
    end

    # Add total row
    table_data << ["Total", format_ms(total_time), "", "", total_tasks.to_s, ""]

    Log.info { "" }
    Log.info { "Feature Timing Breakdown:" }
    Log.info { "" }

    # Calculate column widths
    col_widths = [20, 12, 12, 12, 8, 12]

    # Output table with box drawing characters
    border_top = "┌" + col_widths.map { |width| "─" * width }.join("┬") + "┐"
    border_header = "├" + col_widths.map { |width| "─" * width }.join("┼") + "┤"
    border_bottom = "└" + col_widths.map { |width| "─" * width }.join("┴") + "┘"

    Log.info { border_top }

    table_data.each_with_index do |row, idx|
      if idx == 0
        # Header row
        formatted = row.each_with_index.map { |cell, i| cell.to_s.ljust(col_widths[i]) }.join("│")
        Log.info { "│#{formatted}│" }
        Log.info { border_header }
      elsif row[0] == "Total"
        # Total row separator
        Log.info { border_header }
        formatted = row.each_with_index.map { |cell, i| cell.to_s.ljust(col_widths[i]) }.join("│")
        Log.info { "│#{formatted}│" }
        Log.info { border_bottom }
      else
        # Data row - right-align numeric columns
        formatted = [
          row[0].to_s.ljust(col_widths[0]),
          row[1].to_s.rjust(col_widths[1]),
          row[2].to_s.rjust(col_widths[2]),
          row[3].to_s.rjust(col_widths[3]),
          row[4].to_s.rjust(col_widths[4]),
          row[5].to_s.rjust(col_widths[5]),
        ].join("│")
        Log.info { "│#{formatted}│" }
      end
    end

    Log.info { "" }
  end

  private def self.format_ms(span : Time::Span) : String
    ms = span.total_milliseconds
    if ms >= 1000
      "#{(ms / 1000).to_f.round(2)}s"
    else
      "#{ms.to_i}ms"
    end
  end
end

# A Croupier::Task subclass that automatically tracks timing per feature
class FeatureTask < Croupier::Task
  getter feature_name : String

  # Constructor matching Croupier::Task's output (singular) signature
  def initialize(
    @feature_name : String,
    output : String | Nil = nil,
    inputs : Array(String) = [] of String,
    no_save : Bool = false,
    id : String | Nil = nil,
    always_run : Bool = false,
    mergeable : Bool = true,
    &block : Croupier::TaskProc
  )
    # Wrap the block to track timing
    wrapped_block = -> do
      start_time = Time.instant
      result = block.call
      elapsed = Time.instant - start_time

      # Record timing for this feature
      FeatureTiming.record_task(@feature_name, elapsed)
      result
    end

    super(output: output, inputs: inputs, no_save: no_save, id: id, always_run: always_run, mergeable: mergeable, &wrapped_block)
  end
end
