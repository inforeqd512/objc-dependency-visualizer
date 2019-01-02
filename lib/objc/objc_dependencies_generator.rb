require 'helpers/hierarchy_helpers'

class ObjcDependenciesGenerator

  attr_reader :dependency

  # http://www.thagomizer.com/blog/2016/05/06/algorithms-queues-and-stacks.html
  def generate_dependencies(object_files_dir)

    @dependency = []
    dwarfdumpHierarchyCreator = DwarfdumpHierarchyCreator.new

    object_files_in_dir(object_files_dir) do |filename|

      # Full output example https://gist.github.com/PaulTaykalo/62cd5d545301c8355cb5
      # With grep output example https://gist.github.com/PaulTaykalo/9d5ecbce8a30a412cdbe
      $stderr.puts "-----object_files_dir: #{object_files_dir}----filename: #{filename}"
      object_file_dependency_hierarchy = dwarfdumpHierarchyCreator.create_hierarchy(filename)
      @dependency.push(object_file_dependency_hierarchy)
      @dependency = @dependency.flatten()

      print_hierarchy(@dependency)
      #yield source and destination to create a tree
      pair_source_dest(@dependency) do  |source, source_type, dest, dest_type, link_type|
        yield source, source_type, dest, dest_type, link_type
      end

    end

  end

  def object_files_in_dir(object_files_dirs)
    dirs = Array(object_files_dirs)
    dirs.each do |dir|
      IO.popen("find \"#{dir}\" -name \"*.o\"") { |f|
        f.each { |line| yield line }
      }
    end  
  end

end

class DwarfdumpHierarchyCreator

  def create_hierarchy filename

    tag_stack = Stack.new
    dependency = []
    current_node = nil

    superclass_name_regex = /(?<=}\s\(\s)(.*?)(?=\s\))/ #from at_type_regex tag
    property_name_regex = /(?<=}\s\(\s)(.*?)(?=\*)/  #from at_type_regex tag
    at_type_formal_parameter_regex = /(?<=\s\(\s)(.*?)(?=\*)/
    at_type_subprogram_regex = at_type_formal_parameter_regex

    subclass_name_regex = /(?<=")(.*)(?=")/ #from at_name tag
    at_name_subprogram_regex = /(?<=\[)(.*?)(?=\s)/
    at_name_subprogram_name_category_regex = /(.*?)(?=\()/

    #class, protocol, property, category, return type, method parameter type 
    dwarfdump_tags_in_file(filename) do |file_line|

        # Finding the name in types
        # AT_type( {0x00000456} ( objc_object ) )
        $stderr.puts file_line

        if file_line.include? "TAG_"
          tag_node = TagHierarchyNode.new (file_line)
          num_nodes_popped = update_tag_hierarchy(tag_node, tag_stack)
          # $stderr.puts "-----num_nodes_popped: #{num_nodes_popped}------"
        end

        if file_line.include? "TAG_structure_type" 
          current_node = DependencyHierarchyNode.new
          $stderr.puts "----new node created: #{current_node}----TAG_structure_type--"
          dependency.push(current_node)
        end

        if current_node != nil # a file may contain several compile units, and those may contain no structures but only subprograms.. DECIDE WHAT TO DO FOR THESE, but ignore them for now
          if file_line.include? "AT_name" and tag_stack.currently_seeing_tag.include? "TAG_structure_type"
            name_match = subclass_name_regex.match(file_line) #extract subclass name between apostrophe
            name = name_match[0]
            if name.include?("objc_selector") #ignore structure with objc_selector
              #when ignoring the structure with name, remove the current node created at structure node from dependency as we want to ignore it and so nil the current node 
              dependency.pop
              current_node = nil
              $stderr.puts "-----TAG_structure_type----AT_name----current_node = nil---"
            else
              $stderr.puts "-----current_node: #{current_node}----subclass: #{name}----TAG_structure_type----AT_name---"
              current_node.subclass = name
            end
          end

          if file_line.include? "AT_type" and tag_stack.currently_seeing_tag.include? "TAG_inheritance" #only superclasses are reported, the protocols are not directly seen. the only way is tag_subprogram, protocol method nama
            name_match = superclass_name_regex.match(file_line) #extract inheritance name between brackets
            name = name_match[0]
            current_node.add_polymorphism(name)
            $stderr.puts "---------superclass: #{name}-----TAG_inheritance---AT_type---"
          end

          if file_line.include? "AT_type" and tag_stack.currently_seeing_tag.include? "TAG_APPLE_Property"
            name_match = property_name_regex.match(file_line) #extract property name ending in *
            if name_match != nil # ignore  "id"
              name = name_match[0]
              current_node.add_dependency(name)
              $stderr.puts "---------dependency: #{name}-----TAG_APPLE_Property---AT_type-"
            end
          end

          if file_line.include? "AT_name" and tag_stack.currently_seeing_tag.include? "TAG_subprogram"
            name_match = at_name_subprogram_regex.match(file_line) #extract class name from method call
            if name_match != nil # ignore  "SEL"
              name = name_match[0]
              if name.include?("(") #this is a method in a category
                name_match = at_name_subprogram_name_category_regex.match(name) #extract class name from category name
                name = name_match[0]
              end
              #find the node with the name and make it current
              found_node = find_node(name, dependency)
              if found_node != nil
                $stderr.puts "---------current_node : #{@current_node}------"
                @current_node = found_node
                $stderr.puts "---------found current_node : #{@current_node}------"
              else
                $stderr.puts "---------THIS SHOULD NOT HAPPEN------" #check when this happens whether we need to tackle this
              end
            end
          end

          if file_line.include? "AT_type" and tag_stack.currently_seeing_tag.include? "TAG_subprogram"
            name_match = at_type_subprogram_regex.match(file_line) #extract return type from method call
            if name_match != nil # ignore  "SEL"
              name = name_match[0]
              current_node.add_dependency(name)
              $stderr.puts "---------dependency: #{name}----TAG_subprogram---AT_type---"
            end
          end

          if file_line.include? "AT_type" and tag_stack.currently_seeing_tag.include? "TAG_formal_parameter"
            name_match = at_type_formal_parameter_regex.match(file_line) #extract class name from method call
            if name_match != nil # ignore  "SEL"
              name = name_match[0]
              if name.include?("const ") or name.include?("SEL") or name.include?("char") or name.include?("block_literal") #ignore self (const ViewController*)
                #do nothing
              else
                $stderr.puts "---------dependency: #{name}----TAG_subprogram---AT_type---"
                current_node.add_dependency(name)
              end
            end
          end
        end
    end

    return dependency
  end


  def dwarfdump_tags_in_file(filename)
    #only do the below for objc files, ignore swift
    result = `dwarfdump #{filename.strip} | grep AT_language`
    match_language = /(?<=\(\s)(.*?)(?=\s\))/.match(result)
    name = match_language[0]
    if name.include?("DW_LANG_ObjC")
      IO.popen("dwarfdump \"#{filename.strip}\" ") { |fd|
        fd.each { |line| yield line }
      }
    end
  end

end

class TagHierarchyNode
  attr_reader :level_spaces_length, :tag_name

  def initialize tag_line
    $stderr.puts tag_line
    @level_spaces_length = extract_tag_level (tag_line)
    @tag_name = /TAG.*?\s/.match(tag_line)[0]
  end

  def extract_tag_level (tag_line)
    level_space_regex = /(?<=:)(\s*)(?=TAG)/
    level_spaces_match = level_space_regex.match(tag_line)
    level_spaces = level_spaces_match[0]
    level_spaces_length = level_spaces.length
    return level_spaces_length
  end

end


