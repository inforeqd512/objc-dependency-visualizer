
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

  def peek_tag_name index
    if @data[index]
      return @data[index].tag_name      
    else
      return "No Tag" #should not happen
    end
  end

  def count
    return @data.count
  end
end

class DependencyHierarchyNode
  attr_accessor :subclass, :superclass, :dependency

  def initialize
    @subclass = ""
    @superclass = ""
    @dependency = Set.new #unique entries for dependent classes
  end

  def add_dependency (dependent_node)
    @dependency.add dependent_node    
  end
end