require "ecr"

module Meta
  class Template
    @templates : Array(String)

    def initialize(@templates : Array(String))
    end

    ECR.def_to_s "src/meta_template.ecr"
  end

  def generate
    Template.new(Dir.glob("templates/*.ecr").map(&.split("/")[1].split(".")[0])).to_s
  end
end
