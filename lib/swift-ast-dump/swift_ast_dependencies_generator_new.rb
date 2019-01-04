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
      yield source, source_type, dest, dest_type, link_type
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
    subclass_name_regex = /(?<=:\s)(.*)/ #in sentence with name:, get the subclass name from the : to end of sentence

          
    #class, protocol, property, category, return type, method parameter type, enum, struct
    ast_tags_in_file(filename) do |file_line|

      Logger.log_message file_line

#basic logic - when you see top level tags usually _decl, then till the next top level is seen, every word that begins with Capital letter is a dependency
#modifiers - ignore import_decl, top_level_decl - done till here
#modifiers - only map for when marked as 'public' as others are internal and of no concern (this may take some work)
        #probably should consider only public interfaces as can we get important information from private ones?
#shared singletons will not be dependenchy injected as these following and above are

      tag_node_created = false
      if is_swift_tag.match(file_line) != nil #when <range: is present (means its a tag)
        Logger.log_message("--------is_swift_tag-------------")
        tag_node = SwiftTagHierarchyNode.new (file_line)
        node_below_top_level = tag_stack.node_just_below_top_level
        if node_below_top_level == nil #if there is no node below top hierarchy then create tag node
          num_nodes_popped = update_tag_hierarchy(tag_node, tag_stack)
          tag_node_created = true      
          Logger.log_message "-----tag_node_created------\n\n" #with the above basic logic, there should be no nodes popped          
        else
          if tag_node.level_spaces_length == node_below_top_level.level_spaces_length #if the new tag node is at same level as the second node from top level then create tag node
            num_nodes_popped = update_tag_hierarchy(tag_node, tag_stack)
            Logger.log_message "-----tag_node_created------\n\n" #with the above basic logic, there should be no nodes popped
            tag_node_created = true      
          end  
        end
      end

      if tag_node_created == true #create a dependency node for each top level tag node created
        if file_line.include?("_decl") and #this check required only so that we ensure we HAVE a node created with _decl for the subclass name check below
           file_line.include?("import_decl") == false and  
           file_line.include?("top_level_decl") == false   
          current_node = DependencyHierarchyNode.new
          Logger.log_message "----new node created: #{current_node}------"
          dependency.push(current_node)
        end       
      end

      if current_node != nil # swift file may have more than one top level nodes?

        # if (file_line.include? "access_level:" and tag_stack.currently_seeing_tag.include? "_decl") or
        #    (file_line.include? "modifiers:" and tag_stack.currently_seeing_tag.include? "_decl")

        # end

        #subclass, protocol, extension name - this works as the subclass will be updated only if it was nil before.. This is a little buggy as when the tags are not present in the file, the subclass will get its name from another sentence that has type: in it
        if (file_line.include? "name:" and tag_stack.currently_seeing_tag.include? "_decl") or
           (file_line.include? "type:" and tag_stack.currently_seeing_tag.include? "ext_decl")
          if current_node.subclass.length == 0
            name_match = subclass_name_regex.match(file_line) #extract subclass name 
            name = name_match[0]

            #find the node with the name and make it current, so that we avoid duplicates
            existing_subclass_or_extension_node = find_node(name, dependency)
            if existing_subclass_or_extension_node == nil
              current_node.subclass = name
              Logger.log_message "-----NO existing_subclass_or_extension_node : #{current_node}--AAAAA--subclass: #{current_node.subclass}----"
            else
              dependency.pop #remove the node created at TAG_structure_type
              current_node = existing_subclass_or_extension_node
              Logger.log_message "--------existing_subclass_or_extension_node : #{current_node.subclass}----dependency: #{current_node.dependency.count}--"
            end
          end
        else

        #superclass or protocol name
        if file_line.include? "parent_types:" and tag_stack.currently_seeing_tag.include? "_decl" #check for -decl just to be safe
          current_node.add_polymorphism(file_line)
        else

        #for all other types of decl or lines, check for words beginning with capital and those are all dependencies 
        #property in class 
        # var_decl <range: /Users/mistrys/Documents/Development/ANZ-Next/mobile-ios-github/Frameworks/ANZAPIClients/ANZBankAnywhereAPI/ANZBankAnywhereClient/Classes/Swaggers/Models/EnrolmentResult.swift:16:5-16:42>
        #   pattern: statusDescription: Optional<String>
        #   pattern: accountNames: Optional<Array<AccountNames>>
        # iboutlet
        # var_decl <range: /Users/mistrys/Documents/Development/ANZ-Next/mobile-ios-github/Frameworks/ANZInvestmentsJournal/Sources/BaseButtonBarPagerTabStripViewController.swift:39:5-39:60>
        #   attributes: `@IBOutlet`
        #   modifiers: public weak
        #   pattern: buttonBarView: ImplicitlyUnwrappedOptional<ButtonBarView>
        # var_decl <range: /Users/mistrys/Documents/Development/ANZ-Next/mobile-ios-github/Frameworks/ANZInvestmentsJournal/Sources/BaseButtonBarPagerTabStripViewController.swift:35:5-35:73>
        #   modifiers: public
        #   pattern: buttonBarItemSpec: ImplicitlyUnwrappedOptional<ButtonBarItemSpec<ButtonBarCellType>>
        # const_decl <range: /Users/mistrys/Documents/Development/ANZ-Next/mobile-ios-github/Frameworks/ANZApplicationSupport/Sources/RateAndReviewRouter.swift:31:5-31:50>
        #   modifiers: private
        #   pattern: scheduler: RateAndReviewScheduler
        # func_decl <range: /Users/mistrys/Documents/Development/ANZ-Next/mobile-ios-github/Frameworks/ANZInvestmentsJournal/Sources/BaseButtonBarPagerTabStripViewController.swift:212:5-217:6>
        #   name: collectionView
        #   modifiers: open
        #   parameters:
        #   0: _ collectionView: UICollectionView
        #   1: layout collectionViewLayout: UICollectionViewLayout
        #   2: sizeForItemAtIndexPath indexPath: IndexPath
        #   return_type: `CGSize`
        if is_swift_tag.match(file_line) == nil #when <range: is NOT present (means its NOT a tag)
          if file_line.match(/raw_text:|literal:|method_name:|identifier: `[a-z]|name: `[a-z]/) != nil
            #ignore
          else
            current_node.add_dependency(file_line, true)
          end
        end
        end
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
