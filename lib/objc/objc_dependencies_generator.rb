require 'set'

class ObjcDependenciesGenerator

  attr_reader :dependency

  # http://www.thagomizer.com/blog/2016/05/06/algorithms-queues-and-stacks.html
  def generate_dependencies(object_files_dir, include_dwarf_info)

    return unless include_dwarf_info

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

      #yeild source and destination to create a tree
      @dependency.each { |dependency_hierarchy_node|
        if dependency_hierarchy_node.superclass.length > 0 #ignore Apple's classes  
          yield dependency_hierarchy_node.superclass, dependency_hierarchy_node.subclass, DependencyItemType::CLASS, DependencyItemType::CLASS, DependencyLinkType::INHERITANCE
          dependency_hierarchy_node.dependency.each { |node|
            yield dependency_hierarchy_node.subclass, node, DependencyItemType::CLASS, DependencyItemType::CLASS, DependencyLinkType::CALL
          }
        end
      }

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

  def print_hierarchy (dependency)
    $stderr.puts "\n\n\n\n\n\n\n\n\n\n\n\n----------------------------------------"
    dependency.each { |dependency_hierarchy_node|

      $stderr.puts "--------------#{dependency_hierarchy_node}-----------------"
      $stderr.puts "-----subclass: #{dependency_hierarchy_node.subclass}-----"
      $stderr.puts "-----superclass: #{dependency_hierarchy_node.superclass}-----"
      dependency_hierarchy_node.dependency.each { |node|
        $stderr.puts "-----dependency: #{node}-----"
      }
    }
  end

end

class DwarfdumpHierarchyCreator

  def create_hierarchy filename

    tag_stack = Stack.new
    dependency = []
    current_node = nil

    dwarfdump_tags_in_file(filename) do |dwarfdump_file_line|

        # Finding the name in types
        # AT_type( {0x00000456} ( objc_object ) )
        $stderr.puts dwarfdump_file_line
        at_type_regex = /(?<=}\s\(\s)(.*?)(?=\s\))/
        at_type_property_regex = /(?<=}\s\(\s)(.*?)(?=\*)/
        at_type_formal_parameter_regex = /(?<=\s\(\s)(.*?)(?=\*)/
        at_type_subprogram_regex = at_type_formal_parameter_regex

        at_name_regex = /(?<=")(.*)(?=")/
        at_name_subprogram_regex = /(?<=\[)(.*?)(?=\s)/
        at_name_subprogram_name_category_regex = /(.*?)(?=\()/

        if dwarfdump_file_line.include? "TAG_"
          tag_node = TagHierarchyNode.new (dwarfdump_file_line)
          num_nodes_popped = update_tag_hierarchy(tag_node, tag_stack)
          # $stderr.puts "-----num_nodes_popped: #{num_nodes_popped}------"
          #create array from num_nodes_popped from the dependency and add it to dependencies of the node previous to these
        end

        if dwarfdump_file_line.include? "TAG_structure_type" 
          #if the structure does not already exist in the dependencies array else get that object
          current_node = DependencyHierarchyNode.new
          $stderr.puts "----new node created: #{current_node}----TAG_structure_type--"
          dependency.push(current_node)
        end

        if current_node != nil # a file may contain several compile units, and those may contain no structures but only subprograms.. DECIDE WHAT TO DO FOR THESE, but ignore them for now
            if dwarfdump_file_line.include? "AT_name" and currently_seeing_tag(tag_stack).include? "TAG_structure_type"
            name_match = at_name_regex.match(dwarfdump_file_line) #extract subclass name between apostrophe
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

          if dwarfdump_file_line.include? "AT_type" and currently_seeing_tag(tag_stack).include? "TAG_inheritance"
            name_match = at_type_regex.match(dwarfdump_file_line) #extract inheritance name between brackets
            name = name_match[0]
            current_node.superclass = name
            $stderr.puts "---------superclass: #{name}-----TAG_inheritance---AT_type---"
          end

          if dwarfdump_file_line.include? "AT_type" and currently_seeing_tag(tag_stack).include? "TAG_APPLE_Property"
            name_match = at_type_property_regex.match(dwarfdump_file_line) #extract property name ending in *
            if name_match != nil # ignore  "id"
              name = name_match[0]
              current_node.add_dependency(name)
              $stderr.puts "---------dependency: #{name}-----TAG_APPLE_Property---AT_type-"
            end
          end

          if dwarfdump_file_line.include? "AT_name" and currently_seeing_tag(tag_stack).include? "TAG_subprogram"
            name_match = at_name_subprogram_regex.match(dwarfdump_file_line) #extract class name from method call
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

          if dwarfdump_file_line.include? "AT_type" and currently_seeing_tag(tag_stack).include? "TAG_subprogram"
            name_match = at_type_subprogram_regex.match(dwarfdump_file_line) #extract return type from method call
            if name_match != nil # ignore  "SEL"
              name = name_match[0]
              current_node.add_dependency(name)
              $stderr.puts "---------dependency: #{name}----TAG_subprogram---AT_type---"
            end
          end

          if dwarfdump_file_line.include? "AT_type" and currently_seeing_tag(tag_stack).include? "TAG_formal_parameter"
            name_match = at_type_formal_parameter_regex.match(dwarfdump_file_line) #extract class name from method call
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

  def find_node (name, node_list)
    found_node = nil
    for node in node_list
      if node.subclass == name
        found_node = node
        break        
      end
    end
    return found_node
  end

  def currently_seeing_tag (tag_stack)
    return tag_stack.peek_last.tag_name
  end

  def last_seen_tag (tag_stack)
    return tag_stack.peek_tag_name(-2)
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

  def update_tag_hierarchy (tag_hierarchy_node, tag_stack)
    # $stderr.puts "-----tag_stack: #{tag_stack}----"
    if tag_stack.peek_last == nil
      tag_stack.push tag_hierarchy_node
      # $stderr.puts "----push---#{tag_hierarchy_node.level_spaces_length}"
    else
      if tag_stack.peek_last.level_spaces_length < tag_hierarchy_node.level_spaces_length
        tag_stack.push tag_hierarchy_node
        # $stderr.puts "----push---#{tag_hierarchy_node.level_spaces_length}"
      else
        if tag_stack.peek_last.level_spaces_length == tag_hierarchy_node.level_spaces_length
          tag_stack.push tag_hierarchy_node
          # $stderr.puts "----push---#{tag_hierarchy_node.level_spaces_length}"
        else
          num_nodes_popped = 0
          while tag_stack.peek_last.level_spaces_length > tag_hierarchy_node.level_spaces_length
            x = tag_stack.pop
            num_nodes_popped += 1
            # $stderr.puts "--------pop---#{x.level_spaces_length}"
          end
          tag_stack.push tag_hierarchy_node
          # $stderr.puts "----push---#{tag_hierarchy_node.level_spaces_length}"

          return num_nodes_popped
        end
      end
    end
    return 0
  end

end

class Stack
  def initialize
    @data = []
  end

  def push a
    @data.push a
  end

  def pop
    @data.pop
  end

  def empty?
    @data.empty?
  end

  def peek_last
    return @data.last
  end

  def peek_tag_name index
    if @data[index]
      return @data[index].tag_name      
    else
      return "No Tag" #should not happen
    end
  end

  def count
    return @data.count
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


class DependencyHierarchyNode
  attr_accessor :subclass, :superclass, :dependency

  def initialize
    @subclass = ""
    @superclass = ""
    @dependency = Set.new #unique entries for dependent classes
  end

  def add_dependency (dependent_node)
    @dependency.add dependent_node    
  end
end
