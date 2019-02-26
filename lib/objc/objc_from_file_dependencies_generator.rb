require 'helpers/logger'

#since all info cannot be gained from dwarfdump file eg sharedInstance (Singleton), and static methods of other classes, other dependencies being referenced from inside a method eg view models 
#So looking at the .m files instead
class ObjcFromFileDependenciesGenerator

  attr_reader :dependency

  # http://www.thagomizer.com/blog/2016/05/06/algorithms-queues-and-stacks.html
  def generate_dependencies(implementation_file_paths)

    Logger.log_message("-----implementation_file_paths: #{implementation_file_paths}----")
    @dependency = []
    hierarchyCreator = ObjcFromFileHierarchyCreator.new

    implementation_file_paths.each {|filename| 
        Logger.log_message("\n\n----filename: #{filename}")
        dependency_hierarchy = hierarchyCreator.create_hierarchy(filename, @dependency)
        @dependency = dependency_hierarchy

        print_hierarchy(@dependency)
        #yield source and destination to create a tree
        pair_source_dest(@dependency) do  |source, source_type, dest, dest_type, link_type|
            yield source, source_type, dest, dest_type, link_type
        end
    }

  end
end

class ObjcFromFileHierarchyCreator

  def create_hierarchy filename, dependency

    tag_stack = Stack.new
    dependency = dependency.dup
    current_node = nil
    global_node = DependencyHierarchyNode.new
    multiline_comment_ignore = false

    implementation_file_lines(filename) do |file_line|
      Logger.log_message(file_line)
      #for static and global declarations, use the file name as default node
      #when see @interface then extract the protocols from it for the current node
      #when see @implementation then take the word after that as subclass
      #for each line tokenize and find dependency
      #till reach @end
      #repeat till end of file
      #for superclass, will have to see corresponding .h file - do we really need to know the superclass information? 

      #ignore comment lines - in between /* */ and //
      #One way to ignore enum values?
        #ignore         case AccountsServiceScopeBanking

      # currencyFormatter:ANZCurrencyFormatter.sharedInstance];
      # NSDictionary *outageDataDictionary = [ANZAggregateRemoteConfig sharedInstance].basicBankingConfig[kOutageMessageDataKey];
      # queue:[NSOperationQueue mainQueue]


      #when see @implementation then take the word after that as subclass
      if file_line.include?("@implementation")  
        current_node = DependencyHierarchyNode.new
        Logger.log_message "----new node created: #{current_node}------"
        dependency.push(current_node) 
        current_node, subclass_name_found = subclass_name(file_line, current_node, dependency)
      elsif current_node == nil  #means the statement was in GLOBAL scope of file
        #for static and global declarations, use the file name as default node
        #may not require to do anything as the logic to extract tokens will take care of ensuring it's captured where its used
        #only thing we will not know is if it;s define dna never used in the file 
      elsif single_line_singleton(file_line, current_node) == true #line added as dependency 
        #dont add it here as line already added
      elsif current_node != nil #means in local scope of the @implementation
        #for each line in scope of @implementation ... @end, tokenize and find dependency
        if can_add_dependency(file_line)
          current_node.add_dependency(file_line, true)
        end
      end

      #till reach @end
      if file_line.include?("@end")  
        current_node = nil
      end

    end

    return dependency
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
      return false
    end

    if file_line.include?("//")  #comment #TODO - this implementation is incomplete as when the comment is inline with the code line, the code line will be ignored 
      return false
    end

    if file_line.include?("\"") #if string contains a double quotes then it could be any of   NSAssert, ANZGeneralLogDebug
    #NSAssert
    #ANZGeneralLogDebug
    #@"
    #"
    #ANZLog
      return false
    end

    if file_line.include?("NRFeatureFlag") #if string contains NewRelic settings
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
      return true
    else
      return false
    end
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

  def subclass_name(file_line, current_node, dependency)
    subclass_name_found = false
    if current_node.subclass.length == 0

      category_name_regex =/@implementation (?<subclass_name>\w+) \((?<extension_name>\w+)\)/ #from @implementation line
      subclass_name_regex = /@implementation (?<subclass_name>\w+)/ #from @implementation line

      if file_line.include? "@implementation" 

        #TODO: ignoring categories for now as the dependencies is on the class itself, as in swift. Maybe we should just mark it as categories
        # name_match = category_name_regex.match(file_line) 
        # if name_match != nil
        #   name = name_match[:subclass_name]+"+"+name_match[:extension_name]
        #   subclass_name_found = true
        # else
          name_match = subclass_name_regex.match(file_line) 
          name = name_match[:subclass_name]
          subclass_name_found = true
        # end

        existing_subclass_or_extension_node = find_node(name, dependency)
        if existing_subclass_or_extension_node == nil
          Logger.log_message("-----current_node: #{current_node}----subclass: #{name}----@implementation------")
          current_node.subclass = name
        else
          dependency.pop #remove the node created at TAG_structure_type
          Logger.log_message("--------TAG_structure_type-current_node : #{current_node}------")
          current_node = existing_subclass_or_extension_node
          Logger.log_message("--------TAG_structure_type-found current_node : #{current_node.subclass}----#{current_node.dependency.count}--")
        end
      end
    end

    return current_node, subclass_name_found
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


