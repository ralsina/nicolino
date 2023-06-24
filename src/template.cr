require "ecr"

module Templates

  class Tpl
    def initialize(@context : Hash(String, String))
    end
  end

    class TplPage < Tpl
        def initialize(@context : Hash(String,String))
        end

        ECR.def_to_s "templates/page.ecr"
    end
    class TplPost < Tpl
        def initialize(@context : Hash(String,String))
        end

        ECR.def_to_s "templates/post.ecr"
    end

    Template = {
    "templates/page.ecr" => TplPage,
    "templates/post.ecr" => TplPost,
    }
end
