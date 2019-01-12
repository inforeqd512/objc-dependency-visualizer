class DependencyTreeSigmajs


  def initialize
    @nodes = {}
    @edges = []
    @id_generator = 0
  end
 
  #method to add source and dest details
  def add_sigmajs(source, dest)

    source_node = nil
    if @nodes[source] == nil
      node = TreeNode.new
      node.label = source
      @id_generator += 1
      node.id = @id_generator

      @nodes[source] = node
      source_node = node
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

    if source_node != nil and dest_node != nil
      edge = TreeEdge.new
      edge.source = source_node.id
      edge.target = dest_node.id
      @id_generator += 1
      edge.id = @id_generator

      @edges.push(edge)
      source_node.num_links += 1
    end
    
  end

  def nodes_array
    sorted_nodes = @nodes.values.sort_by { |obj| obj.num_links }

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