
require 'set'

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

class DependencyHierarchyNode
  attr_accessor :subclass, :superclass_or_protocol, :dependency

  def initialize
    @subclass = ""
    @superclass_or_protocol = Set.new #unique entries for super classes and protocols
    @dependency = Set.new #unique entries for dependent classes
  end

  def add_polymorphism (superclass_or_protocol_name_line)
    add_tokenized_dependency(superclass_or_protocol_name_line) { |token|
      @superclass_or_protocol.add(token)
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
    token_string = dependent_types_string.gsub(/[\(\)\-<>`\s@:_\."]/, ",")
    token_list = token_string.split(",") #blindly convert the pattern characters like () <> etc to commas and split this string into tokens with ',' delimiter
    token_list.each { |token| 
      if token.length > 1 #ignore any empty or Generic <T> etc types of tokens and add those directly as dependencies. keep track of exclusions in the swift primitives list
        if token =~ /^[A-Z]/ #if string starts with Capital letter then it's a Type eg String etc
          Logger.log_message("--------add_tokenized_dependency token: #{token}-------------")
          yield token
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

def print_hierarchy (dependency)
  $stderr.puts "\n\n\n\n\n\n\n\n\n\n\n\n--------------print_hierarchy--------------------------"
  dependency.each { |dependency_hierarchy_node|

    $stderr.puts "--------------#{dependency_hierarchy_node}-----------------"
    $stderr.puts "-----subclass: #{dependency_hierarchy_node.subclass}-----"
    dependency_hierarchy_node.superclass_or_protocol.each { |node|
      $stderr.puts "-----superclass_or_protocol: #{node}-----"
    }
    dependency_hierarchy_node.dependency.each { |node|
      $stderr.puts "-----dependency: #{node}-----"
    }
  }
end

def pair_source_dest (dependency)
  dependency.each { |dependency_hierarchy_node|
    if dependency_hierarchy_node.superclass_or_protocol.count > 0 #ignore Apple's classes  
      dependency_hierarchy_node.superclass_or_protocol.each { |name| #when no superclass means the Sublass is apples classes, ignore them
        yield name, dependency_hierarchy_node.subclass, DependencyItemType::CLASS, DependencyItemType::CLASS, DependencyLinkType::INHERITANCE
      }
    end
    dependency_hierarchy_node.dependency.each { |node|
      yield dependency_hierarchy_node.subclass, node, DependencyItemType::CLASS, DependencyItemType::CLASS, DependencyLinkType::CALL
    }
  }
end

class Logger
  def self.log_message (message)
    # $stderr.puts(message)
  end
end





