require 'helpers/hierarchy_helpers'
require 'helpers/swift_hierarchy_helpers'

class SwiftAstDependenciesGeneratorNew

  attr_reader :dependency

  def initialize(swift_files_path, swift_ignore_folders, swift_ast_show_parsed_tree, verbose = false)
    @swift_files_path = swift_files_path
    @swift_ignore_folders = swift_ignore_folders
    @verbose = verbose
    @dump_parsed_tree = swift_ast_show_parsed_tree
  end

  # @return [DependencyTree]
  def generate_dependencies

    @dependency = []
    astHierarchyCreator = ASTHierarchyCreator.new

    $stderr.puts("--------generate_dependencies----------")
    folder_paths = swift_files_path_list(@swift_files_path, @swift_ignore_folders)
    swift_files_list = swift_files_list(folder_paths)

    swift_files_list.each { |swift_filename| 
      swift_file_dependency_hierarchy = astHierarchyCreator.create_hierarchy(swift_filename)

      # ast_tree = SwiftAST::Parser.new().parse_build_log_output(result)
      # $stderr.puts("---------ast_tree--------")
      # $stderr.puts(ast_tree)
    }
    # ast_tree = SwiftAST::Parser.new().parse_build_log_output(File.read("./output.ast"))
    # @ast_tree.dump if @dump_parsed_tree
    # scan_source_files

    # @tree
  end
end

class ASTHierarchyCreator

  def create_hierarchy filename

    tag_stack = Stack.new
    dependency = []
    current_node = nil

    is_swift_tag = /<range:/ #if the 'range' word appears then its a swift tag line


    ast_tags_in_file(filename) do |ast_file_line|

      $stderr.puts ast_file_line

      if is_swift_tag.match(ast_file_line) != nil
        $stderr.puts("--------is_swift_tag-------------")
        tag_node = SwiftTagHierarchyNode.new (ast_file_line)
        # num_nodes_popped = update_tag_hierarchy(tag_node, tag_stack)
        # $stderr.puts "-----num_nodes_popped: #{num_nodes_popped}------"
        #create array from num_nodes_popped from the dependency and add it to dependencies of the node previous to these
      end

    end
  end

  def ast_tags_in_file(filename)        
    $stderr.puts("--------ast_tags_in_file: #{filename}-------------")
    IO.popen("/Users/mistrys/Documents/Development/swift-ast-fork/.build/release/swift-ast -dump-ast #{filename}") { |fd|
      fd.each { |line| yield line }
    }
  end
end

class SwiftTagHierarchyNode
  attr_reader :level_spaces_length, :tag_name

  def initialize tag_line
    @level_spaces_length = extract_tag_level (tag_line)
    @tag_name = /(\w*)(?=\s<)/.match(tag_line)[0] # extracts "import_decl" from sentence like import_decl <range:
    $stderr.puts("-------tag_name: #{tag_name}----------")

  end

  def extract_tag_level (tag_line)
    $stderr.puts("--------extract_tag_level-------")

    level_space_regex = /(\s*)(?=[a-z])/ # extracts spaces in the beginning of sentence like import_decl <range:
    level_spaces_match = level_space_regex.match(tag_line)
    level_spaces = level_spaces_match[0]
    level_spaces_length = level_spaces.length
    $stderr.puts("--------level_spaces_length: #{level_spaces_length}-------")

    return level_spaces_length
  end

end
