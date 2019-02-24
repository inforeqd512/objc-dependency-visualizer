require 'helpers/logger'

class ObjcDependenciesGenerator

  attr_reader :dependency

  # http://www.thagomizer.com/blog/2016/05/06/algorithms-queues-and-stacks.html
  def generate_dependencies(object_files_dirs)

    Logger.log_message("-----object_files_dirs: #{object_files_dirs}----")
    @dependency = []
    dwarfdumpHierarchyCreator = DwarfdumpHierarchyCreator.new

    object_files_in_dir(object_files_dirs) do |filename|

      if filename.include?("Tests") == false and #exclude file paths to Tests in frameworks or subfolders
        filename.include?("RXPromise") == false and
        filename.include?("RXSettledResult") == false and
        filename.include?("RXTimer") == false and
        filename.include?("RCWS") == false and
        filename.include?("ANZSAL") == false and
        filename.include?("ANZRCWS") == false and
        filename.include?("sal_") == false and
        filename.include?("soap") == false and
        filename.include?("wsaapi") == false and
        filename.include?("OpenSSLThreading") == false and
        filename.include?("SALServiceSession") == false and
        filename.include?("NSDictionary+NameValuePair") == false
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
      Logger.log_message("find \"#{dir.chomp('')}\" -name \"*.o\"") #chomp to remove trailing newline \n

      IO.popen("find \"#{dir.chomp('')}\" -name \"*.o\"") { |f|
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

    #class, protocol, property, category, return type, method parameter type 
    dwarfdump_tags_in_file(filename) do |file_line|

      # Finding the name in types
      # AT_type( {0x00000456} ( objc_object ) )
      Logger.log_message(file_line)

      # same logic as swift files : keep track of only top level tags when creating hierarchy nodes, add dependencies to them only 
      second_level_tag_node_created = false
      if file_line.include? "TAG_"
        Logger.log_message("--------is_objc_tag-------------")
        tag_node = TagHierarchyNode.new (file_line)
        
        node_below_top_level = tag_stack.node_just_below_top_level
        if file_line.include?("TAG_compile_unit") #insert top_level_decl if the tag stack and pop existing nodes if any
          num_nodes_popped = update_tag_hierarchy(tag_node, tag_stack)
          Logger.log_message "-----TAG_compile_unit node created ---#{tag_node.tag_name}---\n\n"    
        else #insert tags at just below top_level_decl ie. import_decl, class_decl, struct_decl, proto_decl, ext_decl, enum_decl etc
          if node_below_top_level == nil  or #if a second level to top_level is NOT created yet then add
              (node_below_top_level != nil and tag_node.is_sibling_of(node_below_top_level)) #or if a second level to top_level is created and the node being inserted in it's sibling then add
            num_nodes_popped = update_tag_hierarchy(tag_node, tag_stack)
            second_level_tag_node_created = true 
            currently_seeing_tag = tag_node.tag_name   
            if node_below_top_level == nil
              Logger.log_message "-----second_level_tag_node_created: #{currently_seeing_tag}----#{tag_node.tag_name}-----#{tag_node.level_spaces_length}---------node_below_top_level is NIL------\n\n"   
            else
              Logger.log_message "-----second_level_tag_node_created: #{currently_seeing_tag}----#{tag_node.tag_name}-----#{tag_node.level_spaces_length}-----#{node_below_top_level.level_spaces_length}----#{node_below_top_level.tag_name}------\n\n"   
            end
          else
            num_nodes_popped = update_tag_hierarchy(tag_node, tag_stack) #insert if sibling/child and let the access logic below handle setting the accessor values
            Logger.log_message "-----sibling/child level created-----#{tag_node.tag_name}-----#{tag_node.level_spaces_length}-----------\n\n" 
          end  
        end
      end


      #create dependency for all second level _decl. ignore import_decl, top_level_decl
      if second_level_tag_node_created == true #create a dependency node for each top level tag node created
        if file_line.include?("TAG_structure_type")  #this check required only so that we ensure we HAVE a node created with TAG_structure_type for the subclass name check below
          current_node = DependencyHierarchyNode.new
          Logger.log_message "----new node created: #{current_node}------"
          dependency.push(current_node) #push the current_node into dependancy graph now, but with the later check for duplicate subclass, it will be popped if another node already exists for it
        end       
      end

      if current_node != nil # a file may contain several compile units, and those may contain no structures but only subprograms.. DECIDE WHAT TO DO FOR THESE, but ignore them for now
        
        current_node, subclass_name_found = subclass_name(file_line, tag_stack.currently_seeing_tag, current_node, dependency)

        #superclass or protocol name
        if subclass_name_found == false #if this file line has not already passed the above subclass check
          current_node, superclass_or_protocol_name_found = superclass_or_protocol_name(file_line, tag_stack.currently_seeing_tag, current_node)
          if superclass_or_protocol_name_found == false #if this file line has not already passed the above superclass_or_protocol_name check
            # if maybe_singleton.length == 0 #if not a two line singleton candidate
              #add other regular dependencies ie. all words starting with Capital letter
              if can_add_dependency(currently_seeing_tag, file_line, tag_stack)
                current_node = add_regular_dependencies(file_line, tag_stack.currently_seeing_tag, current_node)
                current_node = find_category_node(file_line, current_node, tag_stack.currently_seeing_tag, dependency)
              end
            # end
          end
        end

      end
    end

    return dependency
  end

  def find_category_node(file_line, current_node, currently_seeing_tag, dependency)

    at_name_subprogram_regex = /(?<=\[)(.*?)(?=\s)/
    at_name_subprogram_name_category_regex = /(.*?)(?=\()/

    if file_line.include? "AT_name" and currently_seeing_tag.include? "TAG_subprogram"
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

    return current_node

  end

  def add_regular_dependencies(file_line, currently_seeing_tag, current_node)

    property_name_regex = /(?<=}\s\(\s)(.*?)(?=\*)/  #from at_type_regex tag
    at_type_formal_parameter_regex = /(?<=\s\(\s)(.*?)(?=\*)/
    at_type_subprogram_regex = at_type_formal_parameter_regex

    if file_line.include? "AT_type" and currently_seeing_tag.include? "TAG_APPLE_Property"
      name_match = property_name_regex.match(file_line) #extract property name ending in *
      if name_match != nil # ignore  "id"
        name = name_match[0]
        current_node.add_dependency(name)
        Logger.log_message("---------dependency: #{name}-----TAG_APPLE_Property---AT_type-")
      end
    end

    if file_line.include? "AT_type" and currently_seeing_tag.include? "TAG_formal_parameter"
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

    if file_line.include? "AT_type" and currently_seeing_tag.include? "TAG_subprogram"
      name_match = at_type_subprogram_regex.match(file_line) #extract return type from method call
      if name_match != nil # ignore  "SEL"
        name = name_match[0]
        current_node.add_dependency(name)
        Logger.log_message("---------dependency: #{name}----TAG_subprogram---AT_type---")
      end
    end

    return current_node
  end

  def can_add_dependency(currently_seeing_tag, file_line, tag_stack)
    return true
  end

  def superclass_or_protocol_name(file_line, currently_seeing_tag, current_node)
    superclass_or_protocol_name_found = false
    if current_node.superclass_or_protocol.length == 0

      superclass_name_regex = /(?<=}\s\(\s)(.*?)(?=\s\))/ #from at_type_regex tag

      if file_line.include? "AT_type" and currently_seeing_tag.include? "TAG_inheritance" #only superclasses are reported, the protocols are not directly seen. the only way is tag_subprogram, protocol method nama
        name_match = superclass_name_regex.match(file_line) #extract inheritance name between brackets
        name = name_match[0]
        current_node.add_polymorphism(name)
        superclass_or_protocol_name_found = true
        Logger.log_message("---------superclass: #{name}-----TAG_inheritance---AT_type---")
      end
    end
    return current_node, superclass_or_protocol_name_found
  end

  def subclass_name(file_line, currently_seeing_tag, current_node, dependency)
    subclass_name_found = false
    if current_node.subclass.length == 0

      subclass_name_regex = /(?<=")(.*)(?=")/ #from at_name tag

      if file_line.include? "AT_name" and currently_seeing_tag.include? "TAG_structure_type"
        name_match = subclass_name_regex.match(file_line) #extract subclass name between apostrophe
        name = name_match[0]
        subclass_name_found = true

        # if name.include?("objc_selector") #ignore structure with objc_selector
        #   #when ignoring the structure with name, remove the current node created at structure node from dependency as we want to ignore it and so nil the current node 
        #   dependency.pop
        #   current_node = nil
        #   Logger.log_message("-----TAG_structure_type----AT_name----current_node = nil---")
        # else
          #find the node with the name and make it current
          existing_subclass_or_extension_node = find_node(name, dependency)
          if existing_subclass_or_extension_node == nil
            Logger.log_message("-----current_node: #{current_node}----subclass: #{name}----TAG_structure_type----AT_name---")
            current_node.subclass = name
          else
            dependency.pop #remove the node created at TAG_structure_type
            Logger.log_message("--------TAG_structure_type-current_node : #{current_node}------")
            current_node = existing_subclass_or_extension_node
            Logger.log_message("--------TAG_structure_type-found current_node : #{current_node.subclass}----#{current_node.dependency.count}--")
          end
        # end
      end
    end

    return current_node, subclass_name_found
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

  def is_sibling_of(node)
    if node != nil 
      return @level_spaces_length == node.level_spaces_length
    else
      return false
    end
  end

  def is_child_of(node)
    if node != nil
      return @level_spaces_length > node.level_spaces_length
    else
      return false
    end
  end

  def extract_tag_level (tag_line)
    level_space_regex = /(?<=:)(\s*)(?=TAG)/
    level_spaces_match = level_space_regex.match(tag_line)
    level_spaces = level_spaces_match[0]
    level_spaces_length = level_spaces.length
    return level_spaces_length
  end

end


