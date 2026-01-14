# Similarity module for finding related posts using MinHash + LSH
#
# This module provides a lightweight way to find similar posts by:
# 1. Generating MinHash signatures for each post (computed once at build time)
# 2. Storing signatures in the kv store for fast lookup
# 3. Using Jaccard similarity to find related posts
#
# MinHash reduces the similarity computation from O(n²) to O(n) by creating
# small signatures that estimate Jaccard similarity.

module Similarity
  # Enable similarity feature (actual work is done in Posts.create_tasks)
  def self.enable(is_enabled : Bool, posts : Array(Markdown::File))
    # Similarity tasks are created by Posts.enable() before rendering
    # This is a no-op for API consistency
  end

  # Configuration for MinHash generation
  class_property num_permutations : Int32 = 128
  class_property ngram_size : Int32 = 3

  # A MinHash signature for a document
  struct Signature
    property post_link : String
    property post_title : String
    property hash_values : Array(Int32)

    def initialize(@post_link : String, @post_title : String, @hash_values : Array(Int32))
    end

    def to_json(json : JSON::Builder)
      json.object do
        json.field "post_link", @post_link
        json.field "post_title", @post_title
        json.field "hash_values", @hash_values
      end
    end

    def self.from_json(json : JSON::PullParser) : self
      post_link = ""
      post_title = ""
      hash_values = [] of Int32

      json.on_key! "post_link" do
        post_link = json.read_string
      end
      json.on_key! "post_title" do
        post_title = json.read_string
      end
      json.on_key! "hash_values" do
        json.read_array do
          hash_values << json.read_int
        end
      end

      new(post_link, post_title, hash_values)
    end
  end

  # Calculate Jaccard similarity between two MinHash signatures
  #
  # Returns a value between 0.0 (no similarity) and 1.0 (identical)
  def self.jaccard_similarity(sig1 : Signature, sig2 : Signature) : Float64
    matches = 0
    sig1.hash_values.each_with_index do |hash_value, index|
      matches += 1 if hash_value == sig2.hash_values[index]?
    end
    matches.to_f / Similarity.num_permutations
  end

  # Tokenize text into words (lowercase, alphanumeric only)
  private def self.tokenize(text : String) : Array(String)
    text.downcase
      .gsub(/[^a-z0-9\s]/, "")
      .split
      .reject(&.blank?)
      .select { |word| word.size >= 3 } # Remove very short words
  end

  # Generate n-grams from tokens
  private def self.ngrams(tokens : Array(String), n : Int32) : Set(String)
    return Set(String).new if tokens.size < n

    grams = Set(String).new
    (0..tokens.size - n).each do |i|
      gram = tokens[i...(i + n)].join(" ")
      grams << gram
    end
    grams
  end

  # Generate a hash function for a specific permutation
  #
  # Uses a simple but effective hash combining two integers
  private def self.hash_function(a : Int32, b : Int32)
    ->(x : Int32) { (((a.to_i64 * x.to_i64 + b.to_i64) & 0x7FFFFFFF) % 1_000_003).to_i32 }
  end

  # Generate multiple hash functions for MinHash
  #
  # Creates 'num_permutations' different hash functions using
  # different coefficients (a, b pairs)
  private def self.generate_hash_functions
    # Use prime numbers for coefficients to ensure good distribution
    primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47,
              53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107,
              109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167,
              173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229]

    hash_fns = [] of Proc(Int32, Int32)
    Similarity.num_permutations.times do |i|
      a = primes[i % primes.size]
      b = primes[(i + 1) % primes.size]
      hash_fns << hash_function(a, b)
    end
    hash_fns
  end

  # Calculate MinHash signature for a given text
  #
  # The signature is an array of minimum hash values across all n-rams
  # in the document, one for each hash function
  def self.calculate_signature(text : String) : Array(Int32)
    tokens = tokenize(text)
    grams = ngrams(tokens, Similarity.ngram_size)

    return Array(Int32).new(Similarity.num_permutations, 0) if grams.empty?

    hash_fns = generate_hash_functions
    signature = [] of Int32

    hash_fns.each do |hash_fn|
      min_hash = Int32::MAX
      grams.each do |gram|
        # Use Crystal's built-in hash for simplicity
        h = gram.hash % 1_000_003
        hash_value = hash_fn.call(h.to_i32)
        min_hash = hash_value if hash_value < min_hash
      end
      signature << min_hash
    end

    signature
  end

  # Extract meaningful text from a post for similarity comparison
  #
  # Combines title and text, removing HTML tags
  private def self.extract_post_text(post : Markdown::File, lang : String) : String
    title = post.title(lang) || ""
    text = post.text(lang) || ""

    # Remove markdown syntax to get cleaner text
    clean_text = text
      .gsub(/#/, "")
      .gsub(/\*\*/, "")
      .gsub(/\*/, "")
      .gsub(/`/, "")
      .gsub(/\[([^\]]+)\]\([^)]+\)/, "\\1") # Replace [text](url) with text
      .gsub(/!\[([^\]]*)\]\([^)]+\)/, "")   # Remove images
      .gsub(/<!--.*-->/, "")                # Remove HTML comments

    "#{title} #{clean_text}"
  end

  # Create MinHash signature for a post
  def self.create_signature(post : Markdown::File, lang : String) : Signature
    text = extract_post_text(post, lang)
    hash_values = calculate_signature(text)

    Signature.new(
      post_link: post.link(lang),
      post_title: post.title(lang) || "",
      hash_values: hash_values
    )
  end

  # Store a post's signature in the kv store
  def self.store_signature(post : Markdown::File, lang : String) : Nil
    signature = create_signature(post, lang)
    # Use .json extension instead of .html to avoid Croupier trying to open it as a file
    safe_link = post.link(lang).gsub("/", "_")
    data = {
      "post_link"   => signature.post_link,
      "post_title"  => signature.post_title,
      "hash_values" => signature.hash_values,
    }
    Croupier::TaskManager.set("similarity/signatures/#{lang}/#{safe_link}.json", data.to_json)
  end

  # Retrieve a post's signature from the kv store
  def self.get_signature(post_link : String, lang : String) : Signature?
    safe_link = post_link.gsub("/", "_")
    key = "similarity/signatures/#{lang}/#{safe_link}.json"
    data = Croupier::TaskManager.get(key)
    return nil if data.nil?

    parsed = JSON.parse(data)
    Signature.new(
      post_link: parsed["post_link"].as_s,
      post_title: parsed["post_title"].as_s,
      hash_values: parsed["hash_values"].as_a.map(&.as_i.to_i32)
    )
  end

  # Get all signatures from the kv store
  def self.get_all_signatures(lang : String) : Array(Signature)
    signatures = [] of Signature

    # Iterate through all keys in the kv store
    # Note: This requires the kv store to support iteration
    # For now, we'll store an index of all post links
    index_key = "similarity/index/#{lang}"
    index_data = Croupier::TaskManager.get(index_key)
    return signatures if index_data.nil?

    post_links = JSON.parse(index_data).as_a.map(&.as_s)
    post_links.each do |link|
      sig = get_signature(link, lang)
      signatures << sig if sig
    end

    signatures
  end

  # Store the index of all post links
  def self.store_index(post_links : Array(String), lang : String) : Nil
    index_key = "similarity/index/#{lang}"
    Croupier::TaskManager.set(index_key, post_links.to_json)
  end

  # Find related posts for a given post
  #
  # Returns an array of tuples containing [post_link, post_title, similarity_score]
  # sorted by similarity score in descending order
  def self.find_related(post : Markdown::File, lang : String, limit : Int32 = 5) : Array(Hash(String, String | Float64))
    signature = get_signature(post.link(lang), lang)
    return [] of Hash(String, String | Float64) if signature.nil?

    all_signatures = get_all_signatures(lang)
    return [] of Hash(String, String | Float64) if all_signatures.empty?

    # Calculate similarities and filter out the post itself
    similarities = all_signatures.compact_map do |sig|
      next nil if sig.post_link == signature.post_link

      score = jaccard_similarity(signature, sig)
      {
        "link"  => sig.post_link,
        "title" => sig.post_title,
        "score" => score,
      }
    end

    # Sort by similarity score (descending) and take top N
    similarities.sort_by { |item| -item["score"].as(Float64) }[0...limit] || [] of Hash(String, String | Float64)
  end

  # Create tasks to calculate and store signatures for all posts
  def self.create_tasks(posts : Array(Markdown::File)) : Nil
    return if posts.empty?

    Config.languages.keys.each do |lang|
      posts.each do |post|
        safe_link = post.link(lang).gsub("/", "_")
        # Create a task to calculate and store the signature for this post
        Croupier::Task.new(
          id: "similarity/#{safe_link}",
          output: "kv://similarity/signatures/#{lang}/#{safe_link}.json",
          inputs: [post.source(lang)],
          no_save: true
        ) do
          Log.info { "🔢 Calculating MinHash signature for #{post.link(lang)}" }
          store_signature(post, lang)
          "" # Return empty string since we're storing directly via set()
        end
      end

      # Create a task to build the index of all signatures
      # This depends on all signature tasks
      signature_keys = posts.map { |post| "kv://similarity/signatures/#{lang}/#{post.link(lang).gsub("/", "_")}.json" }

      Croupier::Task.new(
        id: "similarity_index_#{lang}",
        output: "kv://similarity/index/#{lang}",
        inputs: signature_keys,
        no_save: true
      ) do
        Log.info { "🔢 Building similarity index for #{lang}" }
        post_links = posts.map(&.link(lang))
        store_index(post_links, lang)
        "" # Return empty string
      end
    end
  end
end
