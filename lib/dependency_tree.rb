module DependencyItemType
  CLASS = 'class'.freeze
  STRUCTURE = 'struct'.freeze
  PROTOCOL = 'protocol'.freeze
  UNKNOWN = 'unknown'.freeze
end

module DependencyLinkType
  INHERITANCE = 'inheritance'.freeze
  IVAR = 'ivar'.freeze
  CALL = 'call'.freeze
  PARAMETER = 'parameter'.freeze
  UNKNOWN = 'unknown'.freeze
end

class DependencyTree

  attr_reader :links_count
  attr_reader :links

  def initialize
    @links_count = 0
    @links = []
    @registry = {}
    @types_registry = {}
    @links_registry = {}
    @nodes = {}
    @edges = []
    @id_generator = 0
  end




 
  #method to add source and dest details
  def add_new(source, dest, source_type = DependencyItemType::UNKNOWN, dest_type = DependencyItemType::UNKNOWN, link_type = DependencyItemType::UNKNOWN)

    source_node = nil
    if @nodes[source] == nil
      node = TreeNode.new
      node.label = source
      @id_generator += 1
      node.id = @id_generator

      @nodes[source] = node
      source_node = node
      source_node = @nodes[source]
    else
      source_node = @nodes[source]
    end

    dest_node = nil
    if @nodes[dest] == nil
      node = TreeNode.new
      node.label = dest
      @id_generator += 1
      node.id = @id_generator

      @nodes[dest] = node
      dest_node = node
    else
      dest_node = @nodes[dest]
    end

    register(source, source_type)
    register(dest, dest_type)
    register_link(source, dest, link_type)

    return if connected?(source, dest)

    if source_node != nil and dest_node != nil
      edge = TreeEdge.new
      edge.source = source_node.id
      edge.target = dest_node.id
      @id_generator += 1
      edge.id = @id_generator

      $stderr.puts "------edge source: #{source} --- dest: #{dest}"
      @edges.push(edge)
      source_node.num_links += 1
    end


    @links_count += 1
    @links += [{source: source, dest: dest}]
    
  end

  def connected?(source, dest)
    @links.any? {|item| item[:source] == source && item[:dest] == dest}
  end

  def nodes_array
    sorted_nodes = @nodes.values.sort_by { |obj| obj.num_links }.reverse

    total_cols = 50
    scale = 30

    total_nodes = sorted_nodes.count() 
    for i in 0..(total_nodes - 1)
      node = sorted_nodes[i]
      node.x = (i % total_cols) * scale
      node.y = ((i / total_cols).floor) * scale
    end

    sorted_nodes

  end

  def edges_array
    return @edges
  end

  def isEmpty?
    @links_count.zero?
  end

  def register(object, type = DependencyItemType::UNKNOWN)
    @registry[object] = true
    if @types_registry[object].nil? || @types_registry[object] == DependencyItemType::UNKNOWN
      @types_registry[object] = type
    end
  end

  def isRegistered?(object)
    !@registry[object].nil?
  end

  def type(object)
    @types_registry[object]
  end

  def objects
    @types_registry.keys
  end

  def link_type(source, dest)
    @links_registry[link_key(source, dest)] || DependencyLinkType::UNKNOWN
  end

  def links_with_types
    @links.map do |l|
      type = link_type(l[:source], l[:dest])
      l[:type] = type unless type == DependencyLinkType::UNKNOWN
      l
    end
  end

  def filter
    @types_registry.each { |item, type|
      next if yield item, type
      @types_registry.delete(item)
      @registry.delete(item)
      selected_links = @links.select { |link| link[:source] != item && link[:dest] != item }
      filtered_links = @links.select { |link| link[:source] == item || link[:dest] == item }
      filtered_links.each { |link| remove_link_type(link) }
      @links = selected_links
    }
  end

  def filter_links
    @links = @links.select { |link|
      yield link[:source], link[:dest], link_type(link[:source], link[:dest])
    }
  end  

  def remove_link_type(link)
    source, dest = link[:source], link[:dest]
    return unless source && dest
    @links_registry.delete(link_key(source, dest))
  end

  private

  def register_link(source, dest, type)
    return unless source && dest
    link_key = link_key(source, dest)
    registered_link = @links_registry[link_key]
    if registered_link.nil? || registered_link == DependencyLinkType::UNKNOWN
      @links_registry[link_key] = type
    end
  end

  def link_key(source, dest)
    source + '!<->!' + dest
  end

end


class TreeNode

  attr_accessor :label, :x, :y, :id, :color, :size, :num_links

  def initialize
    @label = ""
    @x = 0.0
    @y = 0.0
    @id = 0
    @color = '#36648B'
    @size = 10
    @num_links = 0
  end

  def as_json(options={})
    {
        label: @label,
        x: @x,
        y: @y,
        id: @id,
        color: @color,
        size: @size,
        num_links: @num_links

    }
  end

  def to_json(*options)
    as_json(*options).to_json(*options)
  end

end


class TreeEdge

  attr_accessor :source, :target, :id

  def initialize
    @source = 0
    @target = 0
    @id = 0
  end

  def as_json(options={})
    {
        source: @source,
        target: @target,
        id: @id
    }
  end

  def to_json(*options)
    as_json(*options).to_json(*options)
  end

end