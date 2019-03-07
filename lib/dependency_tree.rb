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

    #csv 
    @node_csv = {}
    @edge_csv = []
    @id_generator_csv = 0
    @links_registry_csv = {}

  end




 
  #method to add source and dest details

  def add(language, framework, source, dest, source_type = DependencyItemType::UNKNOWN, dest_type = DependencyItemType::UNKNOWN, link_type = DependencyItemType::UNKNOWN)

    csv_display(language, framework, source, dest, source_type, dest_type, link_type)
    
  end

  def add_d3js(source, dest, source_type = DependencyItemType::UNKNOWN, dest_type = DependencyItemType::UNKNOWN, link_type = DependencyItemType::UNKNOWN)

    d3js_display(source, dest, source_type, dest_type, link_type)
    
  end

  def add_sigmajs(source, dest, source_type = DependencyItemType::UNKNOWN, dest_type = DependencyItemType::UNKNOWN, link_type = DependencyItemType::UNKNOWN)

    sigmajs_display_data(source, dest)
    
  end

  #
  #
  #
  # => CSV display
  #
  #
  #
  def csv_display(target_language, target_framework, source, target, source_type, dest_type, link_type)
    link_key = link_key(source, target)
    if @links_registry_csv.key?(link_key)
      #link exists so dont add link
    else
      if !@node_csv.key?(source)
        @id_generator_csv = @id_generator_csv + 1
        @node_csv[source] = { "id" => @id_generator_csv } #{source_class_name => id, "framework" => UIKit}
      end
  
      if !@node_csv.key?(target)
        @id_generator_csv = @id_generator_csv + 1
        @node_csv[target] = { "id" => @id_generator_csv }
      end

      if target_framework.length > 0 #TODO: this check will happen for each of the dependency. Can we reduce it to only when it's for the subclass
        #TODO: for now only initialise if it doesn't contain any value. This will miss categorising those that have say ObjC subclasses, but have Swift categories/extensions.
        #Doing this so that once this value is set based on the fact that it's 
        if @node_csv[target]["framework"] == nil  
          @node_csv[target]["framework"] = target_framework #add the framework for the source (ie. subclass framework)
        end
      end

      if target_language.length > 0
        if @node_csv[target]["language"] == nil #TODO: for now only initialise if it doesn't contain any value. This will miss categorising those that have say ObjC subclasses, but have Swift categories/extensions
          @node_csv[target]["language"] = target_language #add the language for the target subclass only (ie. subclass language = objc/swift)
        end
      end

      #add link
      @links_registry_csv[link_key] = true
      source_id = @node_csv[source]["id"]
      target_id = @node_csv[target]["id"]
      type = "Directed"
  
      edge = { "source" => source_id, "target" => target_id,  "type" => "Directed"}
      @edge_csv.push(edge)
    end
  end

  def node_csv_array
    @node_csv
  end

  def edge_csv_array
    @edge_csv
  end

  def csv_filter (block = Proc.new)
    nodes_to_remove = @node_csv.select { |key, value| block.call(key, DependencyItemType::UNKNOWN) == false} 
    $stderr.puts "------------nodes_to_remove----------"
    $stderr.puts "#{nodes_to_remove}\n\n\n\n"
    nodes_to_remove.each { |key, value| @node_csv.delete(key) }
    nodes_to_remove.each { |key, value| @edge_csv.delete_if { |edge| edge["source"] == value["id"] || edge["target"] == value["id"] } }
    nodes_to_remove.each { |key, value| @links_registry_csv.delete_if { |link_key, value| link_key.include?(key) } }
    $stderr.puts "------------node_csv----------"
    $stderr.puts "#{@node_csv}\n\n\n\n"
    $stderr.puts "------------edge_csv----------"
    $stderr.puts "#{@edge_csv}\n\n\n\n"
    $stderr.puts "------------links_registry_csv----------"
    $stderr.puts "#{@links_registry_csv}\n\n\n\n"
  end


  #
  #
  #
  # => D3JS display
  #
  #
  #

  def d3js_display(source, dest, source_type, dest_type, link_type)
    register(source, source_type)
    register(dest, dest_type)
    register_link(source, dest, link_type)

    return if connected?(source, dest)

    @links_count += 1
    @links += [{source: source, dest: dest}]

  end

  def connected?(source, dest)
    @links.any? {|item| item[:source] == source && item[:dest] == dest}
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

  def filter (block = Proc.new)
    # @types_registry.each { |item, type|
    #   next if yield item, type
    #   @types_registry.delete(item)
    #   @registry.delete(item)
    #   selected_links = @links.select { |link| link[:source] != item && link[:dest] != item }
    #   filtered_links = @links.select { |link| link[:source] == item || link[:dest] == item }
    #   filtered_links.each { |link| remove_link_type(link) }
    #   @links = selected_links
    # }

    csv_filter(block)
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

#edges that only connect the included nodes
  def edges_array
    nodes = sorted_nodes()
    keep_num_links_more_than = 2
    $stderr.puts "------edges filtering to get edges having more links than: #{keep_num_links_more_than}---------"
    edges_for_nodes_being_displayed = filtered_edges_per_num_links(@edges, nodes, keep_num_links_more_than)

    edges_for_nodes_being_displayed
  end

  #filters out the edges that connect the excluded nodes
  def filtered_edges_per_num_links (edges, nodes, keep_num_links_more_than)
    removed_nodes_ids = nodes.select { |node| node.num_links <= keep_num_links_more_than }.map { |node| node.id }

    filtered_edges = edges.select { |edge| 
      removed_nodes_ids.include?(edge.source) == false and 
      removed_nodes_ids.include?(edge.target) == false
    }
    
    filtered_edges
  end

  #
  #
  #
  # => SIGMAJS display
  #
  #
  #
  #array of nodes sorted by number of links in reverse order of the links
  def sigmajs_display_data (source, dest)

    if is_valid_dest?(dest, 'NS|UI|CA|CG|CI|CF') == false ||
       is_valid_dest?(source, 'NS|UI|CA|CG|CI|CF') == false
       $stderr.puts "--------false: #{source}-------#{dest}-------"
      return
    end

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

    return if connected_sigmajs?(source_node.id, dest_node.id)

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

  end

  def connected_sigmajs?(source, dest)
    @edges.any? {|edge| edge.source == source and edge.target == dest}
  end

  def sorted_nodes 
    sorted_nodes = @nodes.values.sort_by { |obj| obj.num_links }.reverse
    sorted_nodes
  end

  #array of nodes with high connections, arranged in a grid required by sigmajs
  def nodes_array
    sorted_nodes = sorted_nodes()

    keep_num_links_more_than = 2
    $stderr.puts "------nodes filtering to get nodes having more links than: #{keep_num_links_more_than}---------"
    nodes_with_high_connections = filtered_nodes_per_num_links(sorted_nodes, keep_num_links_more_than)

    grid_arranged = arrange_in_grid(nodes_with_high_connections)

    grid_arranged
  end

  #array of nodes with high connections
  def filtered_nodes_per_num_links (nodes, keep_num_links_more_than)
    filtered_nodes = nodes.select { |node| node.num_links > keep_num_links_more_than }
    filtered_nodes
  end

  #arrane in grid of (0,0) in top left and increasing by scale 50px for each change in num-links and 30px across with nodes in the same num-links
  def arrange_in_grid (sorted_nodes)

    total_cols = 50
    current_col_count = 1

    scale = 50
    current_num_links = 0

    current_grid_x = 0
    current_grid_y = 0
    step_y = 2

    total_nodes = sorted_nodes.count() 
    for i in 0..(total_nodes - 1)
      node = sorted_nodes[i]

      if current_num_links == 0
        current_num_links = node.num_links
      end

      #move in the grid
      if current_col_count <= total_cols
        if current_num_links == node.num_links
          current_grid_x += 1
        else
          current_num_links = node.num_links
          current_grid_x = 1
          current_grid_y += step_y
          current_col_count = 1
        end
      else
        current_col_count = 1
        current_grid_x = 1
        current_grid_y += 1
      end

      node.x = current_grid_x * scale
      node.y = current_grid_y * scale
      current_col_count += 1

    end

    sorted_nodes
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