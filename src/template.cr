require "ecr"
require "yaml"



module Templates
  class Tpl
    def initialize(@context : Hash(YAML::Any, Yaml::Any))
    end
  end

  Template = {"Tpl" => Tpl}
end
