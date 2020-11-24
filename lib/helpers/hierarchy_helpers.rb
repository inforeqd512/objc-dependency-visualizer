
require 'set'
require 'helpers/logger'

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

  def currently_seeing_tag
    last_element = peek_last
    if last_element != nil
      return last_element.tag_name
    else
      return nil
    end
  end

  def currently_seeing_node
    last_element = peek_last
    if last_element != nil
      return last_element
    else
      return nil
    end
  end

  def node_just_below_top_level
    if @data.length > 1 #if there are atleast 2 elements in the array
      return @data[1]
    else
      return nil
    end
  end

  def count
    return @data.count
  end
end

#class to hold all information that should go into the node
class NetworkGraphNode
  attr_accessor :language, :framework, :source, :source_type, :destination, :destination_type, :link_type

  def initialize
    @language = ""
    @framework = ""
    @source = ""
    @source_type = ""
    @destination = ""
    @destination_type = ""
    @link_type = ""
  end

end

class DependencyHierarchyNode
  attr_accessor :subclass, :subclass_type, :superclass, :protocols, :dependency, :framework, :language

  def initialize
    @subclass = "" #could be class or protocol 
    @subclass_type = ""
    @superclass = Set.new #unique entries for (objc superclasses) or (parent protocols or classes in swift)
    @protocols = Set.new #unique entries for protocols
    @dependency = Set.new #unique entries for dependent classes or structs etc
    @framework = ""
    @language = ""
  end

  def add_subclass_type (subclass_type)
    Logger.log_message("-------add_subclass_type:#{subclass_type}--------")
    @subclass_type = subclass_type
  end

  def add_framework_name (framework_name)
    Logger.log_message("-------add_framework_name:#{framework_name}--------")
    @framework = framework_name
  end

  def add_language (language)
    Logger.log_message("-------add_language:#{language}--------")
    @language = language
  end

  def add_protocols (protocol_name_line)
    add_tokenized_dependency(protocol_name_line) { |token|
    Logger.log_message("-------add_protocols:#{token}--------")
      @protocols.add(token)
    }      
  end

  def add_superclass (superclass_line)
    add_tokenized_dependency(superclass_line) { |token|
    Logger.log_message("-------add_superclass:#{token}--------")
      @superclass.add(token)
    }   
  end

  def add_dependency (dependent_types_string, is_token_string = false)
    if is_token_string
      add_tokenized_dependency(dependent_types_string) { |token|
        @dependency.add(token)
      }
    else
      @dependency.add(dependent_types_string)
    end
  end

  def add_tokenized_dependency (dependent_types_string)
    token_string_keeping_colon = dependent_types_string.gsub(/[\[\]\(\)\-<>`\s@_\.";\*]/, ",")
    token_string = token_string_keeping_colon.gsub(/[:]/, ":,") #ignore words with ObjC method names that end with : and hopefully those that have "With" in them as these are ObjC methods
    token_list = token_string.split(",") #blindly convert the pattern characters like () <> etc to commas and split this string into tokens with ',' delimiter
    token_list.each { |token| 
      token.strip! #remove leading and trailing spaces eg "struct ", or " " tokens
      if token.length > 1 #ignore any empty or Generic <T> etc types of tokens and add those directly as dependencies. keep track of exclusions in the swift primitives list
        if token =~ /^[A-Z]/ #if string starts with Capital letter then it's a Type eg String etc
          if token.end_with?("Block") == false 
            # and
            # token.start_with?("_") == false and #following are in minority, so no issuesif commented
            # token.start_with?("*") == false and
            # token.start_with?("/") == false and
            # token == " shared"
            if token.include?(":") == false #ignore ObjC method names
              if token != token.upcase #if the word is all upper case then it's some string or constant or switch case and we're not interested in it
                Logger.log_message("--------add_tokenized_dependency token: #{token}-------------")
                yield token
              end
            end
          end
        end    
      end
    }
  end
end

def update_tag_hierarchy (tag_hierarchy_node, tag_stack)
  # $stderr.puts "-----tag_stack: #{tag_stack}----"
  #insert the first node
  if tag_stack.peek_last == nil
    tag_stack.push tag_hierarchy_node
    # $stderr.puts "----push---#{tag_hierarchy_node.level_spaces_length}"
  else
    #insert the child tag 
    if tag_stack.peek_last.level_spaces_length < tag_hierarchy_node.level_spaces_length
      tag_stack.push tag_hierarchy_node
      # $stderr.puts "----push---#{tag_hierarchy_node.level_spaces_length}"
    else
      #insert sibling tag
      if tag_stack.peek_last.level_spaces_length == tag_hierarchy_node.level_spaces_length
        tag_stack.push tag_hierarchy_node
        # $stderr.puts "----push---#{tag_hierarchy_node.level_spaces_length}"
      else
        #when inserting a tag at level higher than the last tag in the list, then pop all the tags till you reach a sibling and then add the tag
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

def print_count (final_line_count)
  Logger.log_message("\n\n\n\n\n\n\n\n\n\n\n\n--------------final_line_count--------------------------")
  Logger.log_message("-----final_line_count: #{final_line_count}-----\n\n\n\n\n")
end

def print_hierarchy (dependency)

  Logger.log_message("\n\n\n\n\n\n\n\n\n\n\n\n--------------print_hierarchy--------------------------")
  dependency.each { |dependency_hierarchy_node|

    Logger.log_message("--------------#{dependency_hierarchy_node}-----------------")
    Logger.log_message("-----subclass: #{dependency_hierarchy_node.subclass}-----")
    Logger.log_message("-----subclass_type: #{dependency_hierarchy_node.subclass_type}-----")
    Logger.log_message("-----superclass: #{dependency_hierarchy_node.superclass}-----")
    dependency_hierarchy_node.protocols.each { |node|
      Logger.log_message("-----protocols: #{node}-----")
    }
    dependency_hierarchy_node.dependency.each { |node|
      Logger.log_message("-----dependency: #{node}-----")
    }
    Logger.log_message("-----framework: #{dependency_hierarchy_node.framework}-----")
    Logger.log_message("-----language: #{dependency_hierarchy_node.language}-----")
  }
end

def pair_source_dest (dependency)
  dependency.each { |dependency_hierarchy_node|
    if dependency_hierarchy_node.subclass.length > 0 #subclasses are nil for top level var_decl, const_decl

      #here we show information flow
      #in code when an object A is composed of B, that means information flows
      #from B to A. So a change in B will mean a change is required in A or A now
      #has access to more information than it did previouly
      #ie. dependency injection 
      #so information flows from superclass:subclass, dependency:subclass, 
      #protocol is a grey area.. since subclass uses protocol so maybe : subclass:protocol

      #NetworkGraphNode captures the details for the destination nodes 
      #when the source becomes the destination in another pass then those details will be captured for the source
      #superclass:subclass
      if dependency_hierarchy_node.superclass.count > 0 
        dependency_hierarchy_node.superclass.each { |superclass| 
          networkGraphNode = NetworkGraphNode.new
          networkGraphNode.language = dependency_hierarchy_node.language 
          networkGraphNode.framework = dependency_hierarchy_node.framework
          networkGraphNode.source = superclass
          networkGraphNode.destination = dependency_hierarchy_node.subclass
          networkGraphNode.source_type = "" #dont know the type of the superclass source
          networkGraphNode.destination_type = dependency_hierarchy_node.subclass_type
          networkGraphNode.link_type = DependencyLinkType::INHERITANCE
          yield networkGraphNode
        }
      elsif dependency_hierarchy_node.dependency.count > 0 
        #when no superclass means the Sublass is in foundation or the ignored folders
        #for that subclass, add a relationship as below to capture the framework and language for it
        #AppleNativeOrIgnored:subclass
        networkGraphNode = NetworkGraphNode.new
        networkGraphNode.language = dependency_hierarchy_node.language
        networkGraphNode.framework = dependency_hierarchy_node.framework
        networkGraphNode.source = "AppleNativeOrIgnored"
        networkGraphNode.destination = dependency_hierarchy_node.subclass
        networkGraphNode.source_type = DependencyItemType::CLASS
        networkGraphNode.destination_type = dependency_hierarchy_node.subclass_type
        networkGraphNode.link_type = DependencyLinkType::INHERITANCE
        yield networkGraphNode
      end

      #??ignore Apple's classes. some how even with this, the classes and structs declared in swift with no inheritance still come through
      #subclass:protocol
      if dependency_hierarchy_node.protocols.count > 0 
        dependency_hierarchy_node.protocols.each { |protocol| 
          networkGraphNode = NetworkGraphNode.new
          networkGraphNode.language = ""
          networkGraphNode.framework = ""
          networkGraphNode.source = dependency_hierarchy_node.subclass
          networkGraphNode.destination = protocol
          networkGraphNode.source_type = dependency_hierarchy_node.subclass_type
          networkGraphNode.destination_type = DependencyItemType::PROTOCOL
          networkGraphNode.link_type = DependencyLinkType::INHERITANCE
          yield networkGraphNode
        }
      end

      #for each dependency of the subclass capture the relationship, but cannot put language and framework 
      #as that dependency can be from a different one which will be captured by the above if when it appears in the file
      #subclass:dependency
      dependency_hierarchy_node.dependency.each { |dependency|
        networkGraphNode = NetworkGraphNode.new
        networkGraphNode.language = ""
        networkGraphNode.framework = ""
        networkGraphNode.source = dependency
        networkGraphNode.destination = dependency_hierarchy_node.subclass
        networkGraphNode.source_type = ""
        networkGraphNode.destination_type = dependency_hierarchy_node.subclass_type
        networkGraphNode.link_type = DependencyLinkType::CALL
        yield networkGraphNode
      }
    end
  }
end

def framework_name (filename)
  Logger.log_message("-------framework filename:#{filename}---------")
  framework_name = ""
  if filename.include?("Frameworks")
    framework_name_regex = /Frameworks\/(?<framework_name>\w+)/
    name_match = framework_name_regex.match(filename) #extract framework name 
    framework_name = name_match[:framework_name]
    Logger.log_message("------framework_name in func Frameworks: #{framework_name}--------")
  elsif filename.include?("ANZAppExtension")
    framework_name = "ANZAppExtension"
  elsif filename.include?("Application")
    framework_name = "Application"
  end

  Logger.log_message("------framework_name : #{framework_name}--------")
  return framework_name
end

def language (filename)
  Logger.log_message("-------language filename:#{filename}---------")
  language = ""
  if filename.include?(".m") or
    filename.include?(".h")
    language = "objc"
    Logger.log_message("------language in func .m/.h: #{language}--------")
  elsif filename.include?(".swift")
    language = "swift"
    Logger.log_message("------language in func swift: #{language}--------")
  end

  return language
end



