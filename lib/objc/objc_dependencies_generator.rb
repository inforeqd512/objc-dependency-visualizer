require 'helpers/logger'

class ObjcDependenciesGenerator

  attr_reader :dependency

  # http://www.thagomizer.com/blog/2016/05/06/algorithms-queues-and-stacks.html
  def generate_dependencies(object_files_dirs)

    Logger.log_message("-----object_files_dirs: #{object_files_dirs}----")
    @dependency = []
    dwarfdumpHierarchyCreator = DwarfdumpHierarchyCreator.new

    object_files_in_dir(object_files_dirs) do |filename|

      if filename.include?("Tests") == false #exclude file paths to Tests in frameworks or subfolders
        Logger.log_message("\n\n----filename: #{filename}")
        object_file_dependency_hierarchy = dwarfdumpHierarchyCreator.create_hierarchy(filename, @dependency)
        @dependency = object_file_dependency_hierarchy

        print_hierarchy(@dependency)
        #yield source and destination to create a tree
        pair_source_dest(@dependency) do  |source, source_type, dest, dest_type, link_type|
          yield source, source_type, dest, dest_type, link_type
        end
      end
    end

  end

  def object_files_in_dir(object_files_dirs)
    dirs = Array(object_files_dirs)

    dirs.each do |dir|
      Logger.log_message("------------START FIND-----------")
      Logger.log_message("------object_files_in_dir dir: #{dir}--------")
      Logger.log_message("find \"#{dir.chop}\" -name \"*.o\"") #chop to remove \n

      IO.popen("find \"#{dir.chop}\" -name \"*.o\"") { |f|
        f.each { |line| yield line }
      }
    end  
  end

end

class DwarfdumpHierarchyCreator

  def create_hierarchy filename, dependency

    tag_stack = Stack.new
    dependency = dependency.dup
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
        Logger.log_message(file_line)

        if file_line.include? "TAG_"
          tag_node = TagHierarchyNode.new (file_line)
          num_nodes_popped = update_tag_hierarchy(tag_node, tag_stack)
          Logger.log_message("-----num_nodes_popped: #{num_nodes_popped}------")
        end

        if file_line.include? "TAG_structure_type" 
          current_node = DependencyHierarchyNode.new
          Logger.log_message("----new node created: #{current_node}----TAG_structure_type--")
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
              Logger.log_message("-----TAG_structure_type----AT_name----current_node = nil---")
            else
              #find the node with the name and make it current
              found_node = find_node(name, dependency)
              if found_node != nil
                dependency.pop #remove the node created at TAG_structure_type
                Logger.log_message("--------TAG_structure_type-current_node : #{current_node}------")
                current_node = found_node
                Logger.log_message("--------TAG_structure_type-found current_node : #{current_node.subclass}----#{current_node.dependency.count}--")
              else
                Logger.log_message("-----current_node: #{current_node}----subclass: #{name}----TAG_structure_type----AT_name---")
                current_node.subclass = name
              end
            end
          end

          if file_line.include? "AT_type" and tag_stack.currently_seeing_tag.include? "TAG_inheritance" #only superclasses are reported, the protocols are not directly seen. the only way is tag_subprogram, protocol method nama
            name_match = superclass_name_regex.match(file_line) #extract inheritance name between brackets
            name = name_match[0]
            current_node.add_polymorphism(name)
            Logger.log_message("---------superclass: #{name}-----TAG_inheritance---AT_type---")
          end

          if file_line.include? "AT_type" and tag_stack.currently_seeing_tag.include? "TAG_APPLE_Property"
            name_match = property_name_regex.match(file_line) #extract property name ending in *
            if name_match != nil # ignore  "id"
              name = name_match[0]
              current_node.add_dependency(name)
              Logger.log_message("---------dependency: #{name}-----TAG_APPLE_Property---AT_type-")
            end
          end

          if file_line.include? "AT_name" and tag_stack.currently_seeing_tag.include? "TAG_subprogram"
            name_match = at_name_subprogram_regex.match(file_line) #extract class name from method call
            if name_match != nil # ignore  "SEL"
              name = name_match[0]
              if name.include?("(") #this is a method in a category
                Logger.log_message("---------category name: #{name}-----TAG_subprogram---AT_name-")
                name_match = at_name_subprogram_name_category_regex.match(name) #extract class name from category name
                name = name_match[0]
                Logger.log_message("---------category for class name: #{name}-----TAG_subprogram---AT_name-")
              end
              #find the node with the name and make it current
              found_node = find_node(name, dependency)
              if found_node != nil
                Logger.log_message("---------current_node : #{current_node}------")
                current_node = found_node
                Logger.log_message("---------found current_node : #{current_node.subclass}----#{current_node.dependency.count}--")
              else
                Logger.log_message("---------THIS SHOULD NOT HAPPEN------") #check when this happens whether we need to tackle this
              end
            end
          end

          if file_line.include? "AT_type" and tag_stack.currently_seeing_tag.include? "TAG_subprogram"
            name_match = at_type_subprogram_regex.match(file_line) #extract return type from method call
            if name_match != nil # ignore  "SEL"
              name = name_match[0]
              current_node.add_dependency(name)
              Logger.log_message("---------dependency: #{name}----TAG_subprogram---AT_type---")
            end
          end

          if file_line.include? "AT_type" and tag_stack.currently_seeing_tag.include? "TAG_formal_parameter"
            name_match = at_type_formal_parameter_regex.match(file_line) #extract class name from method call
            if name_match != nil # ignore  "SEL"
              name = name_match[0]
              if name.include?("const ") or name.include?("SEL") or name.include?("char") or name.include?("block_literal") #ignore self (const ViewController*)
                #do nothing
              else
                Logger.log_message("---------dependency: #{name}----TAG_subprogram---AT_type---")
                current_node.add_dependency(name)
              end
            end
          end
        end
    end

    return dependency
  end


  def dwarfdump_tags_in_file(filename)
    #TODO - only do dwarfdump once
    #only do the below for objc files, ignore swift
    result = `dwarfdump #{filename.strip} | grep AT_language`
    match_language = /(?<=\(\s)(.*?)(?=\s\))/.match(result)
    # .debug_info contents:
    # < EMPTY >
    if match_language != nil
      name = match_language[0]
      if name.include?("DW_LANG_ObjC")
        IO.popen("dwarfdump \"#{filename.strip}\" ") { |fd|
          fd.each { |line| yield line }
        }
      end
    end
  end

end

class TagHierarchyNode
  attr_reader :level_spaces_length, :tag_name

  def initialize tag_line
    Logger.log_message(tag_line)
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


