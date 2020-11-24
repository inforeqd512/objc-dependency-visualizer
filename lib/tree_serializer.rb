require 'csv'

class TreeSerializer
  attr_reader :dependency_tree

  # @param [DependencyTree] dependency_tree
  def initialize(dependency_tree)
    @dependency_tree = dependency_tree
  end

  def get_object_to_serialise()
    object_to_serialize = {}
    object_to_serialize[:links] = @dependency_tree.links_with_types
    object_to_serialize[:links_count] = @dependency_tree.links_count
    object_to_serialize[:objects] = Hash[
      @dependency_tree.objects.map do |o|
        [o, { type: @dependency_tree.type(o) }]
      end
    ]
    return object_to_serialize
  end

  # @return [String]
  def serialize(output_format)
    object_to_serialize = {}

    case output_format
    when 'csv'
      serialize_to_csv()
    when 'dot'
      object_to_serialize = get_object_to_serialise()
      serialize_to_dot(object_to_serialize)
    when 'json-pretty'
      object_to_serialize = get_object_to_serialise()
      serialize_to_json_pretty(object_to_serialize)
    when 'json'
      object_to_serialize = get_object_to_serialise()
      serialize_to_json(object_to_serialize)
    when 'json-var'
      object_to_serialize = get_object_to_serialise()
      serialize_to_json_var(object_to_serialize)
    when 'yaml'
      object_to_serialize = get_object_to_serialise()
      serialize_to_yaml(object_to_serialize)
    else
      raise
    end

  end

  def serialize_to_csv()
    node = @dependency_tree.node_csv_hash #{"name": {"id":1, "framework": "Banking", "language": "objc"}}
    edge = @dependency_tree.edge_csv_array #[{source ,target, type}]

    CSV.open("edge.csv", "wb") {|csv| 
      csv << ["Source", "Target", "Type"]
      edge.each {|hash| csv << [hash["source"], hash["target"], hash["type"]] } 
    }
    CSV.open("node.csv", "wb") {|csv| 
      csv << ["Id", "Label", "Framework", "Language", "Node_type"]
      node.each {|key, value| csv << [value["id"], key, value["framework"], value["language"], value["node_type"]] }
    }
  end

  def serialize_to_yaml(object_to_serialize)
    object_to_serialize.to_yaml
  end

  def serialize_to_json_var(object_to_serialize)
    'var dependencies = ' + object_to_serialize.to_json
  end

  def serialize_to_json(object_to_serialize)
    object_to_serialize.to_json
  end

  def serialize_to_json_pretty(object_to_serialize)
    JSON.pretty_generate(object_to_serialize)
  end

  def serialize_to_dot(object_to_serialize)
    indent = "\t"
    s = "digraph dependencies {\n#{indent}node [fontname=monospace, fontsize=9, shape=box, style=rounded]\n"
    object_to_serialize[:links].each do |link|
      s += "#{indent}\"#{link[:source]}\" -> \"#{link[:dest]}\"\n"
    end
    s += "}\n"
    s
  end

end
