class ObjcDependenciesGenerator

  attr_reader :dependency

  # http://www.thagomizer.com/blog/2016/05/06/algorithms-queues-and-stacks.html
  def generate_dependencies(object_files_dir, include_dwarf_info)

    return unless include_dwarf_info

    dwarfdumpHierarchyCreator = DwarfdumpHierarchyCreator.new

    object_files_in_dir(object_files_dir) do |filename|

      # Full output example https://gist.github.com/PaulTaykalo/62cd5d545301c8355cb5
      # With grep output example https://gist.github.com/PaulTaykalo/9d5ecbce8a30a412cdbe
      $stderr.puts "-----object_files_dir: #{object_files_dir}----filename: #{filename}"
      object_file_dependency_hierarchy = dwarfdumpHierarchyCreator.create_hierarchy(filename)
      
    end
  end

  def object_files_in_dir(object_files_dirs)
    dirs = Array(object_files_dirs)
    dirs.each do |dir|
      IO.popen("find \"#{dir}\" -name \"*.o\"") { |f|
        f.each { |line| yield line }
      }
    end  
  end

end

class DwarfdumpHierarchyCreator

  def create_hierarchy filename

    tag_stack = Stack.new
    dependency = []
    current_node = nil

    dwarfdump_tag_pointers_in_file(filename) do |dwarfdump_file_line|

        # Finding the name in types
        # AT_type( {0x00000456} ( objc_object ) )
        $stderr.puts dwarfdump_file_line

        if dwarfdump_file_line.include? "TAG_"
          tag_node = TagHierarchyNode.new (dwarfdump_file_line)
          num_nodes_popped = update_tag_hierarchy(tag_node, tag_stack)
          $stderr.puts "-----num_nodes_popped: #{num_nodes_popped}------"
          #create array from num_nodes_popped from the dependency and add it to dependencies of the node previous to these
        end

        if dwarfdump_file_line.include? "TAG_structure_type" and last_seen_tag(tag_stack).include? "TAG_compile_unit" #think of what to do for the previous node
          #if the structure does not already exist in the dependencies array else get that object
          current_node = DependencyHierarchyNode.new
          $stderr.puts "----new node created: #{current_node}----#{last_seen_tag(tag_stack)}--"
          dependency.push(current_node)
        end

        if dwarfdump_file_line.include? "AT_name" and currently_seeing_tag(tag_stack).include? "TAG_structure_type"
          name_match = /(?<=")(.*)(?=")/.match(dwarfdump_file_line) #extract subclass name between apostrophe
          name = name_match[0]
          $stderr.puts "-----current_node: #{current_node}----subclass: #{name}------"
          current_node.subclass = name
        end

        at_type_regex = /(?<=}\s\(\s)(.*?)(?=\s\))/
        if dwarfdump_file_line.include? "AT_type" and currently_seeing_tag(tag_stack).include? "TAG_inheritance"
          name_match = at_type_regex.match(dwarfdump_file_line) #extract inheritance name between brackets
          name = name_match[0]
          current_node.superclass = name
          $stderr.puts "---------superclass: #{name}------"
        end

        if dwarfdump_file_line.include? "AT_type" and currently_seeing_tag(tag_stack).include? "TAG_APPLE_Property"
          name_match = at_type_regex.match(dwarfdump_file_line) #extract property name
          name = name_match[0]
          current_node.dependency.push(name)
          $stderr.puts "---------dependency: #{name}------"
        end

        # tag_pointer_for_class = /.*?AT_type\(\s\{.*?\}.*\(\s((function|const)\s)?([A-Z][^\)]+?)\*?\s\).*/.match(tag_pointer_line)
        # next unless tag_pointer_for_class

        # dest = tag_pointer_for_class[3]

        # yield source, dest
      end

      return dependency
  end

  def currently_seeing_tag (tag_stack)
    return tag_stack.peek_last.tag_name
  end

  def last_seen_tag (tag_stack)
    return tag_stack.peek_tag_name(-2)
  end

  def dwarfdump_tag_pointers_in_file(filename)
    IO.popen("dwarfdump \"#{filename.strip}\" ") { |fd|
      fd.each { |line| yield line }
    }
  end

  def update_tag_hierarchy (tag_hierarchy_node, tag_stack)

    $stderr.puts "-----tag_stack: #{tag_stack}----"
    if tag_stack.peek_last == nil
      tag_stack.push tag_hierarchy_node
      $stderr.puts "----push---#{tag_hierarchy_node.level_spaces_length}"
    else
      if tag_stack.peek_last.level_spaces_length < tag_hierarchy_node.level_spaces_length
        tag_stack.push tag_hierarchy_node
        $stderr.puts "----push---#{tag_hierarchy_node.level_spaces_length}"
      else
        if tag_stack.peek_last.level_spaces_length == tag_hierarchy_node.level_spaces_length
          tag_stack.push tag_hierarchy_node
          $stderr.puts "----push---#{tag_hierarchy_node.level_spaces_length}"
        else
          num_nodes_popped = 0
          while tag_stack.peek_last.level_spaces_length > tag_hierarchy_node.level_spaces_length
            x = tag_stack.pop
            num_nodes_popped += 1
            $stderr.puts "--------pop---#{x.level_spaces_length}"
          end
          tag_stack.push tag_hierarchy_node
          $stderr.puts "----push---#{tag_hierarchy_node.level_spaces_length}"

          return num_nodes_popped
        end
      end
    end
    return 0

  end
end

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

class TagHierarchyNode
  attr_reader :level_spaces_length, :tag_name

  def initialize tag_line
    $stderr.puts tag_line
    @level_spaces_length = extract_tag_level (tag_line)
    @tag_name = /TAG.*?\s/.match(tag_line)[0]
  end

  def extract_tag_level (tag_line)
    level_space_regex = /(?<=:)(\s*)(?=TAG)/
    level_spaces_match = level_space_regex.match(tag_line)
    level_spaces = level_spaces_match[0]
    level_spaces_length = level_spaces.length
    return level_spaces_length
  end

end


class DependencyHierarchyNode
  attr_accessor :subclass, :superclass, :dependency

  def initialize
    @subclass = ""
    @superclass = ""
    @dependency = []
  end

  def add_dependency (dependent_node)
    @dependency.push dependent_node    
  end
end
