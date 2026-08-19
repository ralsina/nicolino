require "crinja"

# Preprocesses Crinja templates at load time to cut per-page render
# cost:
#
# - Includes are inlined into the template source (recursively, with
#   cycle detection): every {% include %} costs a context creation
#   and template resolution on every render.
# - Subtrees that only reference build-constant site variables are
#   evaluated once against the constants and replaced by fixed text
#   ("folding"). Constants are per language (site title, nav items,
#   ...), so folded templates are cached per {env, template, lang}.
#
# Folding is deliberately conservative: only if-tags, for-tags whose
# collection and body are constant, print statements and fixed text
# fold; expressions are limited to literals, constant lookups, member
# and index access, operators and a whitelist of pure filters; and
# any evaluation error leaves the subtree dynamic. A Template is
# bound to the env that parsed it, so folded templates are cached
# per environment as well (the env pool is bounded by cpu_count).
module TemplatePreprocessor
  # Filters that are safe to evaluate at load time. Anything not
  # listed (in particular functions like shell) keeps its subtree
  # dynamic.
  PURE_FILTERS = Set{"upper", "lower", "title", "capitalize", "trim",
                     "length", "count", "join", "first", "last",
                     "default", "safe", "escape", "e", "int", "float",
                     "string", "list", "abs", "round", "reverse",
                     "sort", "unique", "min", "max", "sum"}

  # Tags whose rendering has no side effects on the context.
  FOLDABLE_TAGS = Set{"if", "for", "raw"}

  @@cache = Hash({UInt64, String, String}, Crinja::Template).new
  @@mutex = Mutex.new

  # The folded template for *name* in *lang*, loading the source
  # through the loader of *env*. The returned Template belongs to
  # *env*: render it via render_with, not Template#render.
  def self.get_template(env : Crinja, name : String, lang : String,
                        constants : Hash(String, Crinja::Value)) : Crinja::Template
    key = {env.object_id, name, lang}
    @@mutex.synchronize do
      @@cache[key] ||= begin
        source = inline_includes(env, name, Set{name})
        template = Crinja::Template.new(source, env, name)
        fold(template, constants)
        template
      end
    end
  end

  # Render a (possibly folded) template with the CURRENT fiber's
  # environment. Template#render would use the env that parsed the
  # template, which for pooled environments is another fiber's env.
  def self.render_with(env : Crinja, template : Crinja::Template,
                       bindings) : String
    env.with_scope(bindings) do
      String.build do |io|
        template.render(io, env)
      end
    end
  end

  # -- Source-level include inlining ------------------------------------

  # Load *name*'s source and replace plain {% include "..." %} with
  # the included template's source, recursively. Only the constant
  # string form is inlined; include expressions, `ignore missing`
  # and with-context modifiers are left dynamic, as are cycles and
  # unknown templates.
  private def self.inline_includes(env : Crinja, name : String, seen : Set(String)) : String
    source = env.loader.get_source(env, name)[0]
    return source unless source.includes?("include")

    source.gsub(/\{%-?\s*include\s+["']([^"']+)["'](?!\s+ignore)(?!\s+with)(?!\s+without)\s*-?%}/) do |match|
      included = $1
      if seen.includes?(included)
        match
      else
        begin
          inline_includes(env, included, seen + Set{included}).chomp
        rescue
          match
        end
      end
    end
  end

  # -- AST folding -------------------------------------------------------

  private def self.fold(template : Crinja::Template,
                        constants : Hash(String, Crinja::Value)) : Nil
    normalize_fixed_strings(template, template.nodes)
    template.nodes.children = fold_nodes(template, template.nodes.children, constants, Set(String).new)
  end

  # FixedStrings apply their trim flags at RENDER time, which would
  # make raw-string concatenation during folding lossy. Normalize
  # each one to its already-trimmed text with the flags cleared, so
  # the strings are exact and render unchanged.
  private def self.normalize_fixed_strings(template : Crinja::Template, list : Crinja::AST::NodeList) : Nil
    env = template.env
    trim_blocks = env.config.trim_blocks
    lstrip_blocks = env.config.lstrip_blocks
    normalize_list = ->(nodes : Array(Crinja::AST::TemplateNode)) do
      nodes.each do |node|
        if node.is_a?(Crinja::AST::FixedString)
          node.string = Crinja::Renderer.trim_text(node, trim_blocks, lstrip_blocks)
          node.trim_left = false
          node.trim_right = false
          node.left_is_block = false
          node.right_is_block = false
        elsif node.is_a?(Crinja::AST::TagNode) && node.block
          normalize_fixed_strings(template, node.block)
        end
      end
    end
    normalize_list.call(list.children)
  end

  private def self.fold_nodes(template : Crinja::Template,
                              nodes : Array(Crinja::AST::TemplateNode),
                              constants : Hash(String, Crinja::Value),
                              allowed : Set(String)) : Array(Crinja::AST::TemplateNode)
    folded = [] of Crinja::AST::TemplateNode
    nodes.each do |node|
      if replacement = fold_node(template, node, constants, allowed)
        folded << replacement
      else
        folded << node
      end
    end
    coalesce(folded)
  end

  # Returns a FixedString if *node* folds to constant text, the node
  # itself when it is trivially static, or nil to keep it dynamic
  # (possibly with folded children).
  private def self.fold_node(template : Crinja::Template, node : Crinja::AST::TemplateNode,
                             constants : Hash(String, Crinja::Value),
                             allowed : Set(String)) : Crinja::AST::TemplateNode?
    case node
    when Crinja::AST::FixedString, Crinja::AST::Note
      node
    when Crinja::AST::PrintStatement
      if expression_foldable?(node.expression, constants, allowed)
        fixed(template, node, constants)
      end
    when Crinja::AST::TagNode
      if FOLDABLE_TAGS.includes?(node.name) && foldable_children?(node.block.children, constants, allowed | (node.name == "for" ? for_targets(node) : Set(String).new))
        fixed(template, node, constants)
      elsif node.block
        node.block.children = fold_nodes(template, node.block.children, constants, allowed)
        nil
      else
        nil
      end
    else
      nil
    end
  end

  # Whether every child of a tag body folds (fixed text, notes,
  # foldable prints, or one level of foldable if-tags, which is all
  # the chrome templates use).
  private def self.foldable_children?(children : Array(Crinja::AST::TemplateNode),
                                      constants : Hash(String, Crinja::Value),
                                      allowed : Set(String)) : Bool
    children.all? do |child|
      case child
      when Crinja::AST::FixedString, Crinja::AST::Note
        true
      when Crinja::AST::PrintStatement
        expression_foldable?(child.expression, constants, allowed)
      when Crinja::AST::TagNode
        FOLDABLE_TAGS.includes?(child.name) &&
          child.name != "for" &&
          foldable_children?(child.block.children, constants, allowed)
      else
        false
      end
    end
  end

  # Evaluate a node against the constants only and return it as a
  # FixedString, or nil if evaluation fails.
  private def self.fixed(template : Crinja::Template, node : Crinja::AST::TemplateNode,
                         constants : Hash(String, Crinja::Value)) : Crinja::AST::TemplateNode?
    env = template.env
    # Parentless context: only the constants resolve; everything
    # else is undefined. Foldability was checked statically first;
    # this is the actual evaluation.
    context = Crinja::Context.new(nil, constants)
    text = env.with_scope(context) do
      renderer = Crinja::Renderer.new(template)
      renderer.render([node]).value
    end
    Crinja::AST::FixedString.new(text, false, false, false, false)
  rescue ex
    Log.debug { "Template fold failed for #{template.name}: #{ex.class}: #{ex.message}" }
    nil
  end

  # Merge adjacent FixedStrings into single nodes.
  private def self.coalesce(nodes : Array(Crinja::AST::TemplateNode)) : Array(Crinja::AST::TemplateNode)
    result = [] of Crinja::AST::TemplateNode
    nodes.each do |node|
      if node.is_a?(Crinja::AST::FixedString) && (result.last?.is_a?(Crinja::AST::FixedString))
        last = result.last.as(Crinja::AST::FixedString)
        last.string = last.string + node.string
      else
        result << node
      end
    end
    result
  end

  # -- Static foldability -------------------------------------------------

  # Whether every free identifier of *expression* resolves in the
  # constants (or is a loop variable of a folded enclosing for).
  private def self.expression_foldable?(expression : Crinja::AST::ExpressionNode,
                                        constants : Hash(String, Crinja::Value),
                                        allowed : Set(String)) : Bool
    ids = Set(String).new
    return false unless pure_walk(expression, ids)
    ids.all? { |name| constants.has_key?(name) || allowed.includes?(name) }
  end

  # Collect free identifiers; returns false when the expression uses
  # anything impure (function calls, non-whitelisted filters,
  # unknown node types).
  private def self.pure_walk(node : Crinja::AST::ExpressionNode, ids : Set(String)) : Bool # ameba:disable Metrics/CyclomaticComplexity
    case node
    when Crinja::AST::IdentifierLiteral
      ids << node.name
      true
    when Crinja::AST::StringLiteral, Crinja::AST::IntegerLiteral,
         Crinja::AST::FloatLiteral, Crinja::AST::BooleanLiteral,
         Crinja::AST::NullLiteral, Crinja::AST::Empty, Crinja::AST::ValuePlaceholder
      true
    when Crinja::AST::MemberExpression
      pure_walk(node.identifier, ids)
    when Crinja::AST::IndexExpression
      pure_walk(node.identifier, ids) && pure_walk(node.argument, ids)
    when Crinja::AST::BinaryExpression, Crinja::AST::ComparisonExpression
      pure_walk(node.left, ids) && pure_walk(node.right, ids)
    when Crinja::AST::UnaryExpression, Crinja::AST::SplashOperator
      pure_walk(node.right, ids)
    when Crinja::AST::FilterExpression
      pure_walk(node.target, ids) &&
        PURE_FILTERS.includes?(node.identifier.name) &&
        node.argumentlist.children.all? { |arg| pure_walk(arg, ids) } &&
        node.keyword_arguments.each_value.all? { |arg| pure_walk(arg, ids) }
    when Crinja::AST::TestExpression
      pure_walk(node.target, ids) &&
        node.argumentlist.children.all? { |arg| pure_walk(arg, ids) } &&
        node.keyword_arguments.each_value.all? { |arg| pure_walk(arg, ids) }
    when Crinja::AST::CallExpression
      # Functions can have side effects (shell!): never fold
      false
    when Crinja::AST::ExpressionList, Crinja::AST::Expressions,
         Crinja::AST::ArrayLiteral, Crinja::AST::TupleLiteral,
         Crinja::AST::IdentifierList
      node.children.all? { |child| pure_walk(child, ids) }
    when Crinja::AST::DictLiteral
      node.children.all? { |key, value| pure_walk(key, ids) && pure_walk(value, ids) }
    else
      false
    end
  end

  # The loop variable names a for-tag binds ("for x, y in ...").
  private def self.for_targets(tag : Crinja::AST::TagNode) : Set(String)
    targets = Set(String).new
    tag.arguments.each do |token|
      break if token.kind == Crinja::Parser::Token::Kind::IDENTIFIER && token.value == "in"
      targets << token.value if token.kind == Crinja::Parser::Token::Kind::IDENTIFIER
    end
    targets << "loop"
    targets
  end
end
