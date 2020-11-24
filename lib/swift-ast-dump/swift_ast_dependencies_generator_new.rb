require 'helpers/hierarchy_helpers'
require 'swift-ast-dump/swift_hierarchy_helpers'

class SwiftAstDependenciesGeneratorNew

  attr_reader :dependency

  def initialize(project_root_folder_path, swift_ast_show_parsed_tree, verbose = false)
    @project_root_folder_path = project_root_folder_path
    @verbose = verbose
    @dump_parsed_tree = swift_ast_show_parsed_tree
  end

  def generate_dependencies

    Logger.log_message("-----project_root_folder_path: #{@project_root_folder_path}----")
    @dependency = []
    astHierarchyCreator = ASTHierarchyCreator.new
    final_line_count = 0

    Logger.log_message("--------generate_dependencies----------")
    swift_files_list = find_swift_files(@project_root_folder_path)

    swift_files_list.each { |filename| 
      Logger.log_message("\n\n----filename: #{filename}")
      swift_file_dependency_hierarchy, line_count = astHierarchyCreator.create_hierarchy(filename, @dependency)
      @dependency = swift_file_dependency_hierarchy
      final_line_count = final_line_count + line_count
    }

    #yield source and destination to create a tree
    pair_source_dest(@dependency) do  
           |networkGraphNode|
      yield networkGraphNode
    end

    print_hierarchy(@dependency)
    print_count (final_line_count)

  end
end

class ASTHierarchyCreator

  def create_hierarchy filename, dependency

    #only read the swift code file to get the line count.. The AST file below will be used to create the dependency tree
    line_count = 0
    swift_file_lines(filename) do |file_line|
      line_count = line_count + 1
    end

    Logger.log_message("------ASTHierarchyCreator-filename: #{filename}-----")

    tag_stack = Stack.new
    dependency = dependency
    current_node = nil

    is_swift_tag = /<range:/ #if the 'range' word appears then its a swift tag line
    maybe_singleton = ""
    maybe_singleton_file_line = ""
    currently_seeing_tag = ""
    subclass_name_for_global_decl = filename #for var_decl, const_decl in the global scope in .swift file, link it to just the file name for now #TODO - a better way to manage this

    framework_name = framework_name(filename)
    language = language(filename)

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
        if file_line.include?("top_level_decl") #insert top_level_decl in the tag stack and pop existing nodes under prev top_level_decl if any
          num_nodes_popped = update_tag_hierarchy(tag_node, tag_stack)
          Logger.log_message "-----top_level_decl node created ---#{tag_node.tag_name}---\n\n"          
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
        if file_line.include?("_decl") and #this check required only so that we ensure we HAVE a node created with _decl for the subclass name check below
           file_line.include?("import_decl") == false   
          current_node = DependencyHierarchyNode.new
          Logger.log_message "----new node created: #{current_node}------"
          dependency.push(current_node) #push the current_node into dependancy graph now, but with the later check for duplicate subclass, it will be popped if another node already exists for it
        end       
      end

      if current_node != nil # swift file may have more than one top level nodes?


      
        #subclass, protocol, extension name - this works as the subclass will be updated only if it was nil before.. 
        #check this first as it has side effect of popping the current_node if the subclass already exists. 
        # add all dependencies later so it's added to the correct node instance
        current_node, subclass_name_found = subclass_name(file_line, currently_seeing_tag, current_node, dependency)
        current_node.add_framework_name(framework_name)
        current_node.add_language(language)

        #identify singletons and set them up as dependencies even if they are in types that are private
        maybe_singleton, maybe_singleton_file_line = two_line_singleton(maybe_singleton, maybe_singleton_file_line, file_line, current_node, currently_seeing_tag, tag_stack)

        single_line_singleton(file_line, current_node)

        #superclass or protocol name
        if subclass_name_found == false #if this file line has not already passed the above subclass check
          current_node, superclass_or_protocol_name_found = superclass_or_protocol_name(file_line, currently_seeing_tag, current_node)
          if superclass_or_protocol_name_found == false #if this file line has not already passed the above superclass_or_protocol_name check
            if maybe_singleton.length == 0 #if not a two line singleton candidate
              #add other regular dependencies ie. all words starting with Capital letter
              if can_add_dependency(currently_seeing_tag, file_line, tag_stack)
                current_node = add_regular_dependencies(file_line, current_node)
                #if by the time the first regular dependency is added, the subclass name is not present, then most likely its because it is second level var_decl, const_dect, typealias_decl
                #so to capture the dependency of the type this var,const or alias refers to, capture it atleast at .swift file name level till 
                #TODO find a better way to link to proper parent Type that uses the const or var
                subclass_name_default_if_empty(current_node, subclass_name_for_global_decl, currently_seeing_tag)
              end
            end
          end
        end

      end
    end

    return dependency, line_count

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
    # if current_node.protocols.count == 0 #seems like this check is not required as parent_types check will suffice?
      if file_line.include? "parent_types:" and currently_seeing_tag.include? "_decl" #check for _decl just to be safe
        current_node.add_superclass(file_line)
        superclass_or_protocol_name_found = true
      end
    # end
    return current_node, superclass_or_protocol_name_found
  end

  def subclass_name_default_if_empty(current_node, filename, currently_seeing_tag)
    if current_node.subclass.length == 0
      current_node.subclass = filename
      current_node.add_subclass_type(currently_seeing_tag)
    end
  end


  #TODO:     const_decl <range: /Users/mistrys/Documents/Development/ANZ-Next/mobile-ios-github/Frameworks/ANZIdentitySupport/Sources/IdentityManager.swift:39:5-39:51>
  #      pattern: analyticsHandler: AnalyticsHandler
  def subclass_name(file_line, currently_seeing_tag, current_node, dependency)
    subclass_name_found = false
    if current_node.subclass.length == 0

      subclass_name_regex = /(?<=:\s)(.*)/ #in sentence with name:, get the subclass name from the : to end of sentence

      if (file_line.include? "name:" and currently_seeing_tag.include? "_decl") or
        (file_line.include? "type:" and currently_seeing_tag.include? "ext_decl")
        name_match = subclass_name_regex.match(file_line) #extract subclass name 
        name = name_match[0].split(".")[0] #take only the first name from say for eg SpendTrackerState.Mood extension names
        subclass_name_found = true

        #find the node with the name and make it current, so that we avoid duplicates
        existing_subclass_or_extension_node = find_node(name, dependency)
        if existing_subclass_or_extension_node == nil
          current_node.subclass = name
          current_node.subclass_type = currently_seeing_tag
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

  def two_line_singleton(maybe_singleton, maybe_singleton_file_line, file_line, current_node, currently_seeing_tag, tag_stack)
    #Singletons appear in AST in two ways. This is the first way

    #identify singletons and set them up as dependencies
    #Singletons appear in AST as the following lines. First line contains the class name. Second line contains the fact that singleton is used
    #   kind: `identifier`, identifier: `TouchIDManagerFactory`
    # identifier: `sharedInstance`

    definitely_singleton = ""
    is_not_a_two_line_singleton = false
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
  
    elsif maybe_singleton.length > 0  and 
      definitely_singleton.length == 0 #if a candidate singleton line was seen before bur was not followed by one with a definite singleton
      is_not_a_two_line_singleton = true
    end

    if is_not_a_two_line_singleton == true
      if can_add_dependency(currently_seeing_tag, maybe_singleton_file_line, tag_stack)
        Logger.log_message "-----is_not_a_two_line_singleton add maybe_singleton_file_line---"
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

  def can_add_dependency(currently_seeing_tag, file_line, tag_stack)
    if  /<range:/.match(file_line) != nil #We need to consider lines that are ONLY not _decl ones 
      return false
    end
    #ignore enum_decl even for current top level tag
    if currently_seeing_tag.include? "enum_decl"
      return false
    end
    #ignore tags where the word will begin with Capital letter but it does not mean its a dependency
    #              kind: `string`, raw_text: `"UserAgentAppName"`
    #ignore tags where you will definitely not find any dependencies eg literal:|method_name:|
    #ignore tags where the regex capture for dependency would have passed but the word is a small case so it's not a dependency eg identifier: `[a-z]
    #ignore tags with singleton as it's already taken care of above eg identifier: `shared`|identifier: `main`/
    #uses attributes: tag for information like: 
    # @objc(XXXModalAction)
    # public final class ModalAction: NSObject, Performable {
    if file_line.match(/raw_text:|literal:|method_name:|identifier: `[a-z]|name: `[a-z]/) != nil
      return false
    end
    #ignore enum_decl even for currently seeing child tag
    if tag_stack.currently_seeing_tag().include? "enum_decl"
      return false
    end
    return true
  end

  def ast_tags_in_file(filename)   
    filename.gsub!(' ', '\ ')
    Logger.log_message("--------ast_tags_in_file: #{filename}-------------")
    IO.popen("/Users/mistrys/Documents/Development/swift-ast-fork/.build/release/swift-ast -dump-ast #{filename}") { |fd|
      fd.each { |line| yield line }
    }
  end

  #TODO - perhaps move this to helper so common between objc and swift
  def swift_file_lines(file_path)

    p file_path
    file_path.strip!
    File.open(file_path).each do |line|
      yield line
    end
    # File is closed automatically at end of block
  end

end

class SwiftTagHierarchyNode
  attr_reader :level_spaces_length, :tag_name

  def initialize tag_line
    @level_spaces_length = extract_tag_level (tag_line)
    # extracts "import_decl" from sentence like import_decl <range:
    @tag_name = /(\w*)(?=\s<)/.match(tag_line)[0] 
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
    # extracts spaces in the beginning of sentence like import_decl <range:
    #        2: binary_op_expr <range: xxx.swift:63:13-63:58>
    #      name: journal
    level_space_regex = /(\s*)(?=[a-z0-9])/ 
    level_spaces_match = level_space_regex.match(tag_line)
    level_spaces = level_spaces_match[0]
    level_spaces_length = level_spaces.length
    return level_spaces_length
  end
end
