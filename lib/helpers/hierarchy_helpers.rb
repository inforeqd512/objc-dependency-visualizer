
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
    return peek_last.tag_name
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

  def add_polymorphism (superclass_or_protocol_name)
    @superclass_or_protocol.add superclass_or_protocol_name    
  end

  def add_dependency (dependent_node)
    @dependency.add dependent_node    
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
      dependency_hierarchy_node.dependency.each { |node|
        yield dependency_hierarchy_node.subclass, node, DependencyItemType::CLASS, DependencyItemType::CLASS, DependencyLinkType::CALL
      }
    end
  }
end
