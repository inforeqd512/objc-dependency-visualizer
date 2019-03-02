require 'helpers/logger'

#since all info cannot be gained from dwarfdump file eg sharedInstance (Singleton), and static methods of other classes, other dependencies being referenced from inside a method eg view models 
#So looking at the .m files instead
class ObjcFromFileDependenciesGenerator

  attr_reader :dependency

  # http://www.thagomizer.com/blog/2016/05/06/algorithms-queues-and-stacks.html
  def generate_dependencies(header_and_implementation_file_paths)

    Logger.log_message("-----header_and_implementation_file_paths: #{header_and_implementation_file_paths}----")
    @dependency = []
    hierarchyCreator = ObjcFromFileHierarchyCreator.new

    header_and_implementation_file_paths.each {|filename| 
        Logger.log_message("\n\n----filename: #{filename}")
        dependency_hierarchy = hierarchyCreator.create_hierarchy(filename, @dependency)
        @dependency = dependency_hierarchy
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

class ObjcFromFileHierarchyCreator

  def create_hierarchy filename, dependency

    tag_stack = Stack.new
    dependency = dependency
    current_node = nil
    global_node = DependencyHierarchyNode.new
    multiline_comment_ignore = false

    implementation_file_lines(filename) do |file_line|
      Logger.log_message(file_line)

      if file_line.include?("Users/")
        return false
      end

      #for static and global declarations, use the file name as default node
      #when see @interface then extract the protocols from it for the current node
      #when see @implementation then take the word after that as subclass
      #for each line tokenize and find dependency
      #till reach @end
      #repeat till end of file
      #for superclass, will have to see corresponding .h file - so that we see the linkage of several levels of inheritance
      #ignore @protocol for now

      #ignore comment lines - in between /* */ and //
      #One way to ignore enum values?
        #ignore         case AccountsServiceScopeBanking - lines containing 'case'

      # currencyFormatter:XXXCurrencyFormatter.sharedInstance];
      # NSDictionary *outageDataDictionary = [XXXAggregateRemoteConfig sharedInstance].basicBankingConfig[kOutageMessageDataKey];
      # queue:[NSOperationQueue mainQueue]

      #when see @implementation then take the word after that as subclass
      decl_start_line_found, current_node = update_subclass_superclass_protocol_names(file_line, current_node, dependency)

      if decl_start_line_found == true 
        # ignore as the above method has processed it 
      elsif current_node == nil  #means the statement was in GLOBAL scope of file
        #for static and global declarations, use the file name as default node
        #may not require to do anything as the logic to extract tokens will take care of ensuring it's captured where its used
        #only thing we will not know is if it;s define dna never used in the file 
      elsif single_line_singleton(file_line, current_node) == true #line added as dependency 
        #dont add it here as line already added
      elsif current_node != nil #means in local scope of the @implementation
        #for each line in scope of @implementation ... @end, tokenize and find dependency
        if can_add_dependency(file_line)
          if /\"/.match(file_line) != nil 
            # if it was false because of double quotes then modify the line and extract dependencies
            # NSString *htmlErrorContent = [XXXFileReader contentsForFile:@"error" type:@"html" inBundle:[NSBundle mainBundle]]; <-- identify te singleton
            everything_between_double_quotes = /(["'])(\\?.)*?\1/
            removed_double_quotes = file_line.gsub(everything_between_double_quotes, '')
            current_node.add_dependency(removed_double_quotes, true)          
          else
            current_node.add_dependency(file_line, true)
          end
        end
      end

      #till reach @end
      if file_line.include?("@end")  
        current_node = nil
      end

    end

    return dependency
  end

  def update_subclass_superclass_protocol_names(file_line, current_node, dependency)

    decl_start_line_found = false
    if file_line.include?("@interface") or
      file_line.include?("@implementation")
      decl_start_line_found = true
      subclass_name, super_class_name, protocol_list_string = subclass_superclass_protocol_name(file_line)

      if subclass_name.length > 0 
        Logger.log_message("---------subclass: #{subclass_name}--------")
        current_node = find_or_create_hierarchy_node_and_update_dependency(subclass_name, current_node, dependency)
        if current_node.subclass.length == 0 #when new node created
          current_node.subclass = subclass_name
        end

        if super_class_name.length > 0 #when the current node is found or created and the super class name is available
          Logger.log_message("---------superclass: #{super_class_name}--------")
          current_node.add_polymorphism(super_class_name)    
        end

        if protocol_list_string.length > 0
          Logger.log_message("---------protocols: #{protocol_list_string}--------")
          current_node.add_polymorphism(protocol_list_string) #add tokenised protocols
        end
      end
    end

    return decl_start_line_found, current_node
  end

  def can_add_dependency(file_line)
    #
    # Multiline - check for it before every other check so other checks do not bypass the setting of the multiline_comment_ignore variabel
    #
    if file_line.include?("/*")  #multiline comment  
      @multiline_comment_ignore = true
      return_value = false
      Logger.log_message("------multiline_comment_ignore: #{@multiline_comment_ignore}------")
      if file_line.include?("*/")  #multiline comment  
        @multiline_comment_ignore = false
        Logger.log_message("------multiline_comment_ignore: #{@multiline_comment_ignore}------")
        return_value = false
      end
      return return_value
    end

    if file_line.include?("*/")  #multiline comment  
      @multiline_comment_ignore = false
      Logger.log_message("------multiline_comment_ignore: #{@multiline_comment_ignore}------")
      return false
    end

    if @multiline_comment_ignore == true
      Logger.log_message("------multiline_comment_ignore: #{@multiline_comment_ignore}------")
      return false
    end

    #
    # Rest of the checks
    #
     #One way to ignore enum values?
        #ignore         case AccountsServiceScopeBanking
    if file_line.include?(" case ")  #enum case statement 
      Logger.log_message("------ignore: case------")
      return false
    end

    if file_line.include?("//")  #comment #TODO - this implementation is incomplete as when the comment at the end of line of code sentence, the code line will be ignored 
      Logger.log_message("------ignore: //------")
      return false
    end

    if file_line.include?("const ")  #comment
      Logger.log_message("------ignore: const ------")
      return false
    end

  
    #NSAssert
    #GeneralLogDebug
    #ANZLog

    if file_line.include?("NSAssert") or
      file_line.include?("Debug") or #will capture ANZGeneralLogDebug
      file_line.include?("OSLog") or
      file_line.include?("ANZLog") or
      file_line.include?("Log(")  #will capture NSLog(), VerboseLog()
      Logger.log_message("------ignore: Log------")
      return false
    end

    if file_line.include?("NRFeatureFlag") #if string contains NewRelic settings
      Logger.log_message("------ignore: NRFeatureFlag------")
      return false
    end
    return true
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
      definitely_singleton = match_text[:type_name].sub(/\s/,".") 

    elsif /[a-zA-Z]\.shared/.match(file_line) != nil
      match_text = /(?<type_name>\w*.shared)/.match(file_line) #this pattern will match AppSessionCoordinator shared and ANZAppSessionCoordinator.shared
      definitely_singleton = match_text[:type_name].sub(/\s/,".") 
      Logger.log_message "-----definitely_singleton: #{definitely_singleton}----"

    end

    if definitely_singleton.length > 0
      #add the singleton if it was found
      Logger.log_message "-----definitely_singleton: #{definitely_singleton}-ADDED-SINGLE LINE SINGLETON--"
      current_node.add_dependency(definitely_singleton)
      definitely_singleton = ""
      return true
    else
      return false
    end
  end

  def find_or_create_hierarchy_node_and_update_dependency(subclass_name, current_node, dependency)
    existing_node = find_node(subclass_name, dependency)
    if existing_node == nil
      current_node = DependencyHierarchyNode.new
      Logger.log_message "----new node created: #{current_node}------"
      dependency.push(current_node)
    else
      current_node = existing_node
      Logger.log_message("--------existing node found in dependency : #{current_node}------")
    end

    return current_node
  end

  def subclass_superclass_protocol_name(file_line)
    subclass_name = ""
    super_class_name = ""
    protocol_list_string = ""
    name_match = nil

    # @interface XXXASFetchBankingCMCInvestingAccountsTask : XXXTaskGroup <--will give  subclass and superclass name
    # @interface XXXASFetchBankingCMCInvestingAccountsTask: XXXTaskGroup
    # @interface XXXBBPaymentsPlaceholderView ()        <--in .m file, will give only subclass name
    # @interface XXXBBPayeesSearchDisplayController     <-- in .h file, will give only subclass name
    # @interface XXXBBPayeesSearchDisplayController : XXXTaskGroup <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UISearchControllerDelegate, UISearchResultsUpdating> <--will give subclass and superclass name and protocol string
    # @interface XXXBBPayeesSearchDisplayController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate, UISearchControllerDelegate, UISearchResultsUpdating> <--will give subclass  and protocol string

    if file_line.include? "@interface"
      subclass_superclass_name_regex = /@interface (?<subclass_name>\w*)\s*:*\s*(?<super_class_name>\w*)/ #from @interface tag in the .h file
      name_match = subclass_superclass_name_regex.match(file_line) 
      subclass_name = name_match[:subclass_name]
      super_class_name = name_match[:super_class_name]

    elsif file_line.include? "@implementation" 
      category_name_regex =/@implementation (?<subclass_name>\w+) \((?<extension_name>\w+)\)/ #from @implementation line
      subclass_name_regex = /@implementation (?<subclass_name>\w+)/ #from @implementation line
    
      #TODO: ignoring categories for now as the dependencies is on the class itself, as in swift. Maybe we should just mark it as categories
      # name_match = category_name_regex.match(file_line) 
      # if name_match != nil
      #   name = name_match[:subclass_name]+"+"+name_match[:extension_name]
      #   subclass_name_found = true
      # else
        name_match = subclass_name_regex.match(file_line) 
        subclass_name = name_match[:subclass_name]
      # end
    end

    if name_match != nil 
      #TODO: multiline protocol string will not be added to protocol list but to dependencies
      candidate_list = file_line.split("<")
      if candidate_list.count > 1 #means there was a protocol list
        protocol_list_string = candidate_list.last #split on the crocodile brace opening for prototocol and take the last item in that list
      end
    end

    return subclass_name, super_class_name, protocol_list_string
  end

  def implementation_file_lines(file_path)

    p file_path
    file_path.strip!
    File.open(file_path).each do |line|
      if line.include?("pragma")
        #ignore
      else
        yield line
      end 
    end
    # File is closed automatically at end of block
  end

end


