#!/usr/bin/env crystal

require "json"
require "file_utils"

struct DocType
  include JSON::Serializable

  property name : String
  property kind : String
  property full_name : String?
  property doc : String?
  property summary : String?
  @[JSON::Field(key: "html_id")]
  property html_id : String?
  property abstract : Bool?
  property locations : Array(Location)?
  property types : Array(DocType)?
  property constants : Array(Constant)?
  property constructors : Array(Method)?
  property class_methods : Array(Method)?
  property instance_methods : Array(Method)?
  property macros : Array(Method)?

  struct Location
    include JSON::Serializable
    property filename : String
    property line_number : Int32
  end

  struct Constant
    include JSON::Serializable
    property name : String
    property value : String?
    property doc : String?
  end

  struct Method
    include JSON::Serializable
    property name : String
    property doc : String?
    property summary : String?
    property abstract : Bool?
    property args_string : String?
    property args_html : String?
    property location : Location?
    @[JSON::Field(key: "def")]
    property definition : MethodDef?

    struct MethodDef
      include JSON::Serializable
      property name : String
      property args : Array(Arg)?
      property return_type : String?
      property visibility : String?
      property body : String?

      struct Arg
        include JSON::Serializable
        property name : String
        property external_name : String?
        property restriction : String?
        property default_value : String?
      end
    end
  end
end

struct DocRoot
  include JSON::Serializable
  property repository_name : String
  property body : String?
  property program : DocType
end

class APIDocGenerator
  DOCS_DIR = "docs/api"

  EXCLUDED_TYPES = ["Macros", "PatternMatcher", "Utils"]

  TYPE_ORDER = {
    "module"     => 0,
    "class"      => 1,
    "struct"     => 2,
    "enum"       => 3,
    "annotation" => 4,
    "alias"      => 5,
  }

  def initialize(@root : DocRoot)
  end

  def generate
    FileUtils.mkdir_p(DOCS_DIR)

    ralph_module = @root.program.types.try(&.find { |t| t.name == "Ralph" })
    return puts "Error: Ralph module not found" unless ralph_module

    types = collect_types(ralph_module)

    types.each do |type|
      generate_type_page(type)
    end

    generate_index(types)

    puts "Generated #{types.size} API documentation pages in #{DOCS_DIR}/"
  end

  private def collect_types(mod : DocType, prefix = "") : Array(DocType)
    types = [] of DocType

    mod.types.try(&.each do |type|
      next if EXCLUDED_TYPES.includes?(type.name)
      next if type.doc.nil? || type.doc.try(&.empty?)

      types << type

      if nested = type.types
        nested.each do |nested_type|
          next if nested_type.doc.nil? || nested_type.doc.try(&.empty?)
          types << nested_type
        end
      end
    end)

    types.sort_by! { |t| {TYPE_ORDER[t.kind]? || 99, t.name} }
    types
  end

  private def generate_type_page(type : DocType)
    filename = type_filename(type)
    File.write(File.join(DOCS_DIR, filename), render_type(type))
  end

  private def type_filename(type : DocType) : String
    name = type.full_name || type.name
    name.gsub("::", "-").downcase + ".md"
  end

  private def render_type(type : DocType) : String
    String.build do |io|
      io << "# " << type.name << "\n\n"

      io << "`" << type.kind << "`"
      if type.abstract
        io << " `abstract`"
      end
      io << "\n\n"

      if loc = type.locations.try(&.first?)
        io << "*Defined in [" << loc.filename << ":" << loc.line_number << "]"
        io << "(https://github.com/watzon/ralph/blob/main/" << loc.filename << "#L" << loc.line_number << ")*\n\n"
      end

      if doc = type.doc
        io << doc << "\n\n"
      end

      if constants = type.constants
        non_empty = constants.reject { |c| c.doc.nil? && c.value.nil? }
        unless non_empty.empty?
          io << "## Constants\n\n"
          non_empty.each do |constant|
            io << "### `" << constant.name << "`\n\n"
            if val = constant.value
              io << "```crystal\n" << constant.name << " = " << val << "\n```\n\n"
            end
            if doc = constant.doc
              io << doc << "\n\n"
            end
          end
        end
      end

      if constructors = type.constructors
        unless constructors.empty?
          io << "## Constructors\n\n"
          constructors.each do |method|
            render_method(io, method, ".")
          end
        end
      end

      if class_methods = type.class_methods
        non_empty = class_methods.reject { |m| m.doc.nil? || m.doc.try(&.empty?) }
        unless non_empty.empty?
          io << "## Class Methods\n\n"
          non_empty.each do |method|
            render_method(io, method, ".")
          end
        end
      end

      if instance_methods = type.instance_methods
        documented = instance_methods.reject do |m|
          m.doc.nil? || m.doc.try(&.empty?) || m.name.ends_with?("=")
        end
        unless documented.empty?
          io << "## Instance Methods\n\n"
          documented.each do |method|
            render_method(io, method, "#")
          end
        end
      end

      if macros = type.macros
        non_empty = macros.reject { |m| m.doc.nil? || m.doc.try(&.empty?) }
        unless non_empty.empty?
          io << "## Macros\n\n"
          non_empty.each do |method|
            render_method(io, method, ".")
          end
        end
      end

      if nested = type.types
        documented = nested.reject { |t| t.doc.nil? || t.doc.try(&.empty?) || EXCLUDED_TYPES.includes?(t.name) }
        unless documented.empty?
          io << "## Nested Types\n\n"
          documented.each do |nested_type|
            io << "- [`" << nested_type.name << "`](" << type_filename(nested_type) << ") - "
            if summary = nested_type.summary
              io << summary.gsub("\n", " ")
            elsif doc = nested_type.doc
              first_sentence = doc.split(/\.\s|\n\n/).first? || doc[0..100]
              io << first_sentence.gsub("\n", " ")
            end
            io << "\n"
          end
          io << "\n"
        end
      end
    end
  end

  private def render_method(io : IO, method : DocType::Method, separator : String)
    io << "### `" << separator << method.name
    if args = method.args_string
      io << args
    end
    io << "`\n\n"

    if loc = method.location
      io << "*[View source](https://github.com/watzon/ralph/blob/main/"
      io << loc.filename << "#L" << loc.line_number << ")*\n\n"
    end

    if doc = method.doc
      io << doc << "\n\n"
    end

    io << "---\n\n"
  end

  private def generate_index(types : Array(DocType))
    content = String.build do |io|
      io << "# API Reference\n\n"
      io << "Complete API documentation for Ralph, auto-generated from source code.\n\n"

      grouped = types.group_by(&.kind)

      if modules = grouped["module"]?
        io << "## Modules\n\n"
        modules.each { |t| render_index_entry(io, t) }
        io << "\n"
      end

      if classes = grouped["class"]?
        io << "## Classes\n\n"
        classes.each { |t| render_index_entry(io, t) }
        io << "\n"
      end

      if structs = grouped["struct"]?
        io << "## Structs\n\n"
        structs.each { |t| render_index_entry(io, t) }
        io << "\n"
      end

      if enums = grouped["enum"]?
        io << "## Enums\n\n"
        enums.each { |t| render_index_entry(io, t) }
        io << "\n"
      end

      if annotations = grouped["annotation"]?
        io << "## Annotations\n\n"
        annotations.each { |t| render_index_entry(io, t) }
        io << "\n"
      end
    end

    File.write(File.join(DOCS_DIR, "index.md"), content)
  end

  private def render_index_entry(io : IO, type : DocType)
    io << "- [`" << type.name << "`](" << type_filename(type) << ")"
    if type.abstract
      io << " *(abstract)*"
    end
    io << " - "
    if summary = type.summary
      io << summary.gsub("\n", " ")
    elsif doc = type.doc
      first_sentence = doc.split(/\.\s|\n\n/).first? || doc[0..100]
      io << first_sentence.gsub("\n", " ")
    end
    io << "\n"
  end
end

puts "Generating Crystal documentation JSON..."
json_output = `crystal doc -f json 2>/dev/null`

if json_output.empty?
  STDERR.puts "Error: Failed to generate documentation"
  exit 1
end

puts "Parsing documentation..."
root = DocRoot.from_json(json_output)

puts "Generating markdown files..."
generator = APIDocGenerator.new(root)
generator.generate

puts "Done!"
