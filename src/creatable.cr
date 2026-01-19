# Registry for content types that can be created with `nicolino new`

module Creatable
  # Type of content that can be created
  struct ContentType
    property name : String
    property directory : String
    property description : String
    property creator : Path -> Nil

    def initialize(@name, @directory, @description, &@creator : Path -> Nil)
    end
  end

  @@creatables = [] of ContentType

  # Register a content type that can be created
  def self.register(name : String, directory : String, description : String, &creator : Path -> Nil)
    @@creatables << ContentType.new(name, directory, description, &creator)
  end

  # Get all registered content types
  def self.all : Array(ContentType)
    @@creatables
  end

  # Find a content type by directory path
  def self.find_by_directory(dir : String) : ContentType?
    @@creatables.find { |content_type| content_type.directory == dir }
  end

  # Check if any content type is registered
  def self.any? : Bool
    !@@creatables.empty?
  end
end
