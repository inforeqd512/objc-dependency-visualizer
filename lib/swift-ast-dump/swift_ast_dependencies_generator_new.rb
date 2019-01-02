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
      @dependency.push(swift_file_dependency_hierarchy)
      @dependency = @dependency.flatten()

      print_hierarchy(@dependency)
      #yield source and destination to create a tree
      pair_source_dest(@dependency) do  |source, source_type, dest, dest_type, link_type|
        yield source, source_type, dest, dest_type, link_type
      end

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
    subclass_name_regex = /(?<=:\s)(.*)/ #in sentence with name:, get the subclass name from the : to end of sentence
    superclass_name_regex = subclass_name_regex
    property_name_regex = /(?<=identifier:\s`)(\w*)/ #property name from identifier: string
    extension_subclass_name_regex = subclass_name_regex
    function_formal_parameter_type_name_regex = /(?<=:\s)(\w*)(?=\n)/ # exgracts prrrr1 from     0: formalParamOne: prrrr1\n

    #class, protocol, property, category, return type, method parameter type, enum, struct
    ast_tags_in_file(filename) do |file_line|

      $stderr.puts file_line

      if is_swift_tag.match(file_line) != nil
        $stderr.puts("--------is_swift_tag-------------")
        tag_node = SwiftTagHierarchyNode.new (file_line)
        num_nodes_popped = update_tag_hierarchy(tag_node, tag_stack)
        $stderr.puts "-----num_nodes_popped: #{num_nodes_popped}------\n\n"
      end

      if file_line.include? "class_decl" 
        #if the structure does not already exist in the dependencies array else get that object
        current_node = DependencyHierarchyNode.new
        $stderr.puts "----new node created: #{current_node}----class_decl--"
        dependency.push(current_node)
      end

      if current_node != nil # swift file may have more than one top level nodes?
        if file_line.include? "name:" and tag_stack.currently_seeing_tag.include? "class_decl"
          name_match = subclass_name_regex.match(file_line) #extract subclass name 
          name = name_match[0]
          $stderr.puts "-----current_node: #{current_node}----subclass: #{name}----class_decl----name:---"
          current_node.subclass = name
        end

        if file_line.include? "parent_types:" and tag_stack.currently_seeing_tag.include? "class_decl"
          name_match = superclass_name_regex.match(file_line) #extract super class name and protocol name
          name = name_match[0]
          name.split(/\W\s/).each { |word|        
            current_node.add_polymorphism(word)
          }
          $stderr.puts "---------superclass: #{name}-------parent_types:---"
        end

        #property in class and return type in function or extension method
        if file_line.include? "identifier:" and tag_stack.currently_seeing_tag.include? "identifier_expr"
          name_match = property_name_regex.match(file_line) #extract property name ending in *
          if name_match != nil 
            name = name_match[0]
            current_node.add_dependency(name)
            $stderr.puts "---------dependency: #{name}------identifier:-"
          end
        end

        #class for which this is extension declarqtion
        if file_line.include? "type:" and tag_stack.currently_seeing_tag.include? "ext_decl"
          name_match = extension_subclass_name_regex.match(file_line) #extract class name for which this is an extension
          name = name_match[0]

          found_node = find_node(name, dependency)
          if found_node != nil
            $stderr.puts "---------current_node : #{@current_node}------"
            @current_node = found_node #make the found node as current node so that when the next identifier: sentence is found, then the name is added to dependent_node
            $stderr.puts "---------found current_node : #{@current_node}------"
          else
            $stderr.puts "---------THIS SHOULD NOT HAPPEN------" #check when this happens whether we need to tackle this
          end
        end

        #formal parameters in function
        if file_line.scan(/:/).count == 2 and tag_stack.currently_seeing_tag.include? "func_decl" # if the line contains 2 colons then it's a parameter decl
          name_match = function_formal_parameter_type_name_regex.match(file_line) 
          name = name_match[0]
          $stderr.puts "-----current_node: #{current_node}----formal parameters: #{name}----func_decl----0:<formal parameter name>:<formal parameter type>---"
          current_node.add_dependency(name)
        end
      end
    end

    return dependency

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

    level_space_regex = /(\s*)(?=[a-z])/ # extracts spaces in the beginning of sentence like import_decl <range:
    level_spaces_match = level_space_regex.match(tag_line)
    level_spaces = level_spaces_match[0]
    level_spaces_length = level_spaces.length
    $stderr.puts("--------level_spaces_length: #{level_spaces_length}-------")

    return level_spaces_length
  end

end
