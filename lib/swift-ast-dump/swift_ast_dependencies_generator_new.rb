require 'helpers/hierarchy_helpers'
require 'helpers/swift_hierarchy_helpers'

class SwiftAstDependenciesGeneratorNew

  attr_reader :dependency

  def initialize(swift_files_path, swift_ignore_folders, swift_ast_show_parsed_tree, verbose = false, sigmajs)
    @swift_files_path = swift_files_path
    @swift_ignore_folders = swift_ignore_folders
    @verbose = verbose
    @dump_parsed_tree = swift_ast_show_parsed_tree
    @sigmajs = sigmajs
  end

  def generate_dependencies

    @dependency = []
    astHierarchyCreator = ASTHierarchyCreator.new

    Logger.log_message("--------generate_dependencies----------")
    folder_paths = swift_files_path_list(@swift_files_path, @swift_ignore_folders)
    swift_files_list = swift_files_list(folder_paths)

    swift_files_list.each { |filename| 
      if filename.include?("Tests") == false #exclude file paths to Tests in frameworks or subfolders
        swift_file_dependency_hierarchy = astHierarchyCreator.create_hierarchy(filename, @dependency)
        @dependency = swift_file_dependency_hierarchy
      end
    }

    #yield source and destination to create a tree
    pair_source_dest(@dependency) do  |source, source_type, dest, dest_type, link_type|
      if @sigmajs
        yield source, dest
      else
        yield source, source_type, dest, dest_type, link_type
      end
    end

    print_hierarchy(@dependency)
  end
end

class ASTHierarchyCreator

  def create_hierarchy filename, dependency

    Logger.log_message("------ASTHierarchyCreator-filename: #{filename}-----")

    tag_stack = Stack.new
    dependency = dependency
    current_node = nil

    is_swift_tag = /<range:/ #if the 'range' word appears then its a swift tag line
    maybe_singleton = ""
    maybe_singleton_file_line = ""
    currently_seeing_tag = ""
    access_level_private = false
    modifiers_private = false

    #class, protocol, property, category, return type, method parameter type, enum, struct
    ast_tags_in_file(filename) do |file_line|

      Logger.log_message file_line

#basic logic - when you see top level tags usually _decl, then till the next top level is seen, every word that begins with Capital letter is a dependency. 
#               However, in the tag stack still keep track of all other child _decl so you can ignore ones having 'private' modifiers
      
      second_level_tag_node_created = false
      if is_swift_tag.match(file_line) != nil #when <range: is present (means its a tag)
        Logger.log_message("--------is_swift_tag-------------")
        tag_node = SwiftTagHierarchyNode.new (file_line)

        node_below_top_level = tag_stack.node_just_below_top_level
        if node_below_top_level == nil #insert top_level_decl
          num_nodes_popped = update_tag_hierarchy(tag_node, tag_stack)
          Logger.log_message "-----top_level_decl node created ---#{tag_node.tag_name}---\n\n"          
        else #insert tags at just below top_level_decl ie. import_decl, class_decl, struct_decl, proto_decl, ext_decl, enum_decl etc
          if tag_node.level_spaces_length == node_below_top_level.level_spaces_length #insert only if this tag is sibling of the tag just below top level 
            num_nodes_popped = update_tag_hierarchy(tag_node, tag_stack)
            second_level_tag_node_created = true 
            currently_seeing_tag = tag_node.tag_name   
            Logger.log_message "-----second_level_tag_node_created: #{currently_seeing_tag}----#{tag_node.tag_name}-----#{tag_node.level_spaces_length}-----#{node_below_top_level.level_spaces_length}----#{node_below_top_level.tag_name}------\n\n"   
            access_level_private = false #reset these values whenever a top level node is created as these will not be specified for all cases so cannot deterministically say when its value change
            modifiers_private = false
          else
            num_nodes_popped = update_tag_hierarchy(tag_node, tag_stack)
            Logger.log_message "-----child level created-----#{tag_node.tag_name}-----#{tag_node.level_spaces_length}-----#{node_below_top_level.level_spaces_length}----#{node_below_top_level.tag_name}------\n\n" 
          end  
        end
      end

      #create dependency for all second level _decl. ignore import_decl, top_level_decl
      if second_level_tag_node_created == true #create a dependency node for each top level tag node created
        if file_line.include?("_decl") and #this check required only so that we ensure we HAVE a node created with _decl for the subclass name check below
           file_line.include?("import_decl") == false   
          current_node = DependencyHierarchyNode.new
          Logger.log_message "----new node created: #{current_node}------"
          dependency.push(current_node) #push the current_node into dependancy graph now, but with the later check for duplicate subclass, it will be popped if another node already exists for it
        end       
      end

      if current_node != nil # swift file may have more than one top level nodes?

        #only map for when marked as 'public' as others are internal and of no concern.. right now only ignoring private, internal as the access_level and modifiers are not always defined
        access_level_private, modifiers_private = check_if_private_access(file_line, access_level_private, modifiers_private)

        #identify singletons and set them up as dependencies even if they are in types that are private
        maybe_singleton, maybe_singleton_file_line = two_line_singleton(maybe_singleton, maybe_singleton_file_line, file_line, current_node, access_level_private, modifiers_private, currently_seeing_tag, tag_stack)

        single_line_singleton(file_line, current_node)
      
        #subclass, protocol, extension name - this works as the subclass will be updated only if it was nil before.. 
        current_node, subclass_name_found = subclass_name(file_line, currently_seeing_tag, current_node, dependency)

        #superclass or protocol name
        if subclass_name_found == false
          current_node, superclass_or_protocol_name_found = superclass_or_protocol_name(file_line, currently_seeing_tag, current_node)
          if superclass_or_protocol_name_found == false 
            #add other regular dependencies ie. all words starting with Capital letter
            if can_add_dependency(access_level_private, modifiers_private, currently_seeing_tag, file_line, tag_stack)
              current_node = add_regular_dependencies(file_line, current_node)
            end
          end
        end

      end
    end

    return dependency

  end

  def add_regular_dependencies(file_line, current_node)
    #for all other types of decl or lines, check for words beginning with capital and those are all dependencies 
    #property in class 
    # var_decl <range: 16:5-16:42>
    #   pattern: statusDescription: Optional<String>
    #   pattern: accountNames: Optional<Array<AccountNames>>
    # iboutlet
    # var_decl <range: 39:5-39:60>
    #   attributes: `@IBOutlet`
    #   modifiers: public weak
    #   pattern: buttonBarView: ImplicitlyUnwrappedOptional<ButtonBarView>
    # var_decl <range: 35:5-35:73>
    #   modifiers: public
    #   pattern: buttonBarItemSpec: ImplicitlyUnwrappedOptional<ButtonBarItemSpec<ButtonBarCellType>>
    # const_decl <range: 31:5-31:50>
    #   modifiers: private
    #   pattern: scheduler: RateAndReviewScheduler
    # func_decl <range: 5-217:6>
    #   name: collectionView
    #   modifiers: open
    #   parameters:
    #   0: _ collectionView: UICollectionView
    #   1: layout collectionViewLayout: UICollectionViewLayout
    #   2: sizeForItemAtIndexPath indexPath: IndexPath
    #   return_type: `CGSize`
    #find all words starting with Capital letter and add it as dependency
    current_node.add_dependency(file_line, true)
    return current_node
  end

  def superclass_or_protocol_name(file_line, currently_seeing_tag, current_node)
    superclass_or_protocol_name_found = false
    if current_node.superclass_or_protocol.length == 0
      if file_line.include? "parent_types:" and currently_seeing_tag.include? "_decl" #check for _decl just to be safe
        current_node.add_polymorphism(file_line)
        superclass_or_protocol_name_found = true
      end
    end
    return current_node, superclass_or_protocol_name_found
  end

  def subclass_name(file_line, currently_seeing_tag, current_node, dependency)
    subclass_name_found = false
    if current_node.subclass.length == 0

      subclass_name_regex = /(?<=:\s)(.*)/ #in sentence with name:, get the subclass name from the : to end of sentence

      if (file_line.include? "name:" and currently_seeing_tag.include? "_decl") or
        (file_line.include? "type:" and currently_seeing_tag.include? "ext_decl")
        name_match = subclass_name_regex.match(file_line) #extract subclass name 
        name = name_match[0]
        subclass_name_found = true

        #find the node with the name and make it current, so that we avoid duplicates
        existing_subclass_or_extension_node = find_node(name, dependency)
        if existing_subclass_or_extension_node == nil
          current_node.subclass = name
          Logger.log_message "-----NO existing_subclass_or_extension_node : #{current_node}--AAAAA--subclass: #{current_node.subclass}----"
        else
          dependency.pop #remove the node created at _decl above
          current_node = existing_subclass_or_extension_node
          Logger.log_message "--------existing_subclass_or_extension_node : #{current_node.subclass}----dependency: #{current_node.dependency.count}--"
        end
      end
    end

    return current_node, subclass_name_found
  end

  def check_if_private_access(file_line, access_level_private, modifiers_private)
    if file_line.include? "access_level:"
      if file_line.include? "access_level: private" or
         file_line.include? "access_level: internal"
        Logger.log_message "-----access_level: private----"
        access_level_private = true
      else
        Logger.log_message "--NOT---access_level: private----"
        access_level_private = false
      end
    end

    if file_line.include? "modifiers:"
      if file_line.include? "modifiers: private" or
         file_line.include? "modifiers: internal"
        Logger.log_message "-----modifiers: private----"
        modifiers_private = true
      else
        Logger.log_message "--NOT---modifiers: private----"
        modifiers_private = false
      end
    end

    return access_level_private, modifiers_private
  end

  def single_line_singleton(file_line, current_node)
    #identify singletons and set them up as dependencies
    #Singletons appear in AST in two ways. This is the second way

    #    init_decl <range: xxx.swift>
    # 3: urlOpener: URLOpener = UIApplication.shared

    # func_decl <range: xxx.swift:14:5-17:6>
    # 0: for bundle: Bundle = Bundle.main

    # func_decl <range: /Users/mistrys/Documents/Development/-Next/mobile-ios-github/Frameworks/UIKit/Sources/CGFloat+.swift:9:5-11:6>
    # parameters:
    # 0: displayScale: CGFloat = UIScreen.main.scale
    definitely_singleton = ""
    if /[a-zA-Z]\.main/.match(file_line) != nil
      match_text = /(?<type_name>\w*.main)/.match(file_line)
      definitely_singleton = match_text[:type_name]

    elsif /[a-zA-Z]\.shared/.match(file_line) != nil
      match_text = /(?<type_name>\w*.shared)/.match(file_line)
      definitely_singleton = match_text[:type_name]
      Logger.log_message "-----definitely_singleton: #{definitely_singleton}----"

    end

    if definitely_singleton.length > 0
      #add the singleton if it was found
      Logger.log_message "-----definitely_singleton: #{definitely_singleton}-ADDED-SINGLE LINE SINGLETON--"
      current_node.add_dependency(definitely_singleton)
      definitely_singleton = ""
    end
  end

  def two_line_singleton(maybe_singleton, maybe_singleton_file_line, file_line, current_node, access_level_private, modifiers_private, currently_seeing_tag, tag_stack)
    #Singletons appear in AST in two ways. This is the first way

    #identify singletons and set them up as dependencies
    #Singletons appear in AST as the following lines. First line contains the class name. Second line contains the fact that singleton is used
    #   kind: `identifier`, identifier: `TouchIDManagerFactory`
    # identifier: `sharedInstance`

    definitely_singleton = ""
    singleton_not_identified = false
    if /identifier:\s`[A-Z].*`/.match(file_line) != nil
      match_text = /identifier:\s`(?<type_name>[A-Z].*)`/.match(file_line)
      maybe_singleton_file_line = file_line
      maybe_singleton = match_text[:type_name]

    elsif (/identifier: `shared`/.match(file_line) != nil) and 
          (maybe_singleton.length > 0)
      definitely_singleton = maybe_singleton + ".shared"

    elsif (/identifier: `main`/.match(file_line) != nil) and 
          (maybe_singleton.length > 0)
      definitely_singleton = maybe_singleton + ".main"
  
    else
      singleton_not_identified = true
    end

    if singleton_not_identified == true
      if can_add_dependency(access_level_private, modifiers_private, currently_seeing_tag, maybe_singleton_file_line, tag_stack)
        current_node.add_dependency(maybe_singleton_file_line, true)
      end
      maybe_singleton = ""
      maybe_singleton_file_line = ""

    elsif definitely_singleton.length > 0
      #add the singleton if it was found
      Logger.log_message "-----definitely_singleton: #{definitely_singleton}-ADDED TWO LINE SINGLETON---"
      current_node.add_dependency(definitely_singleton)
      maybe_singleton = ""
      maybe_singleton_file_line = ""
    end

    return maybe_singleton, maybe_singleton_file_line
  end

  def can_add_dependency(access_level_private, modifiers_private, currently_seeing_tag, file_line, tag_stack)
    if  /<range:/.match(file_line) != nil #We need to consider lines that are ONLY not _decl ones 
      return false
    end
    #only add dependency when non private access_level 
    if access_level_private == true
      return false
    end
    #if accesss level not private, only add dependency when  non private modifiers which are commonly found in child of access_level
    if modifiers_private == true
      return false
    end
    #ignore enum_decl even for current top level tag
    if currently_seeing_tag.include? "enum_decl"
      return false
    end
    #ignore tags where the word will begin with Capital letter but it does not mean its a dependency
    #              kind: `string`, raw_text: `"UserAgentAppName"`
    #ignore tags where you will definitely not find any dependencies eg literal:|method_name:|attributes:|
    #ignore tags where the place where the dependency would have started is a small case so it's not a dependency eg identifier: `[a-z]
    #ignore tags with singleton as it's already taken care of above eg identifier: `shared`|identifier: `main`/
    if file_line.match(/raw_text:|literal:|method_name:|attributes:|identifier: `[a-z]|name: `[a-z]/) != nil
      return false
    end
    #ignore enum_decl even for currently seeing child tag
    if tag_stack.currently_seeing_tag().include? "enum_decl"
      return false
    end
    return true
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
    @tag_name = /(\w*)(?=\s<)/.match(tag_line)[0] 
    # extracts "import_decl" from sentence like import_decl <range:
  end

  def extract_tag_level (tag_line)

    level_space_regex = /(\s*)(?=[a-z])/ # extracts spaces in the beginning of sentence like import_decl <range:
    level_spaces_match = level_space_regex.match(tag_line)
    level_spaces = level_spaces_match[0]
    level_spaces_length = level_spaces.length
    return level_spaces_length
  end
end
