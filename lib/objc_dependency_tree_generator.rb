# encoding: UTF-8

require 'optparse'
require 'yaml'
require 'json'
require 'objc/objc_from_file_dependency_tree_generator_helper'
require 'swift-ast-dump/swift_ast_dependencies_generator_new'
require 'objc/objc_from_file_dependencies_generator'
require 'dependency_tree'
require 'tree_serializer'
require 'helpers/logger'
require 'helpers/valid_destination'

class DependencyTreeGenerator
  def initialize(options)
    @options = options
    @options[:derived_data_project_pattern] = '*-*' unless @options[:derived_data_project_pattern]

    @exclusion_prefixes = @options[:exclusion_prefixes] ? @options[:exclusion_prefixes] : 'NS|UI|CA|CG|CI|CF|CL|IB|SF'
    @object_files_directories = @options[:search_directories]
  end

  def self.parse_command_line_options
    options = {}

    # Defaults
    options[:project_name] = ''
    options[:output_format] = 'json'
    options[:verbose] = true
    options[:swift_ast_show_parsed_tree] = false
    options[:ignore_primitive_types] = true
    options[:show_inheritance_only] = false

    OptionParser.new do |o|
      o.separator 'General options:'
      o.on('-p PATH', '--path', 'Path to directory where are your .o files were placed by the compiler', Array) do |directory|
        options[:search_directories] = Array(options[:search_directories]) | Array(directory)
      end
      o.on('-R PROJECT_ROOT_PATH', 'Path to project root directory') do |project_root_path|
        options[:project_root_path] = project_root_path
      end
      o.on('-D DERIVED_DATA', 'Path to directory where DerivedData is') do |derived_data|
        options[:derived_data_paths] = [derived_data]
        options[:derived_data_project_pattern] = '*'
      end
      o.on('-s PROJECT_NAME', 'Search project .o files by specified project name') do |project_name|
        options[:project_name] = project_name
      end
      o.on('-t TARGET_NAME', '--target', 'Target of project', Array) do |target_name|
        options[:target_names] = Array(options[:target_names]) | Array(target_name)
      end
      o.on('-e PREFIXES', "Prefixes of classes those will be exсluded from visualization. \n\t\t\t\t\tNS|UI\n\t\t\t\t\tUI|CA|MF") do |exclusion_prefixes|
        options[:exclusion_prefixes] = exclusion_prefixes
      end

      # o.on('--ast-file FILENAME', 'Generate dependencies from the swift ast dump output (ast)') do |v|
      #   options[:swift_ast_dump_file] = v
      # end

      o.on('--ast-show-parsed-tree', 'Show ast parsing info (for swift ast parser only)') do |_v|
        options[:swift_ast_show_parsed_tree] = true
      end

      o.on('--inheritance-only', 'Show only inheritance dependencies') do
        options[:show_inheritance_only] = true
      end  

      o.on('-f FORMAT', 'Output format. json by default. Possible values are [dot|json-pretty|json|json-var|yaml]') do |f|
        options[:output_format] = f
      end
      o.on('-o OUTPUT_FILE', '--output', 'target of output') do |f|
        options[:target_file_name] = f
      end

      o.separator 'Common options:'
      o.on_tail('-h', 'Prints this help') do
        puts o
        exit
      end
      o.parse!
    end

    options
  end

  def find_object_files_directories
    find_project_output_directory(
      @options[:derived_data_paths],
      @options[:project_name],
      @options[:derived_data_project_pattern],
      @options[:target_names],
      @options[:verbose]
      )
  end

  def build_dependency_tree
    tree = generate_dependency_tree
    tree.filter { |item, _| is_valid_dest?(item, @exclusion_prefixes) } if @options[:ignore_primitive_types]
    # TODO the below
    # tree.filter_links { |_ , _ , type | type == DependencyLinkType::INHERITANCE } if @options[:show_inheritance_only]
    tree
  end

  def generate_dependency_tree
    return tree_for_objc_swift
  end

  def tree_for_objc_swift

    tree = DependencyTree.new

    return tree if !@options || @options.empty?

    update_tree_block = lambda { |language, framework, source, source_type, dest, dest_type, link_type| tree.add(language, framework, source, source_type, dest, dest_type, link_type) } 

    if @options[:project_root_path]
      $stderr.puts "\n\n--------------objc implementation file enter--------------"
      file_paths = find_objc_files(@options[:project_root_path])
      return tree unless file_paths
      ObjcFromFileDependenciesGenerator.new.generate_dependencies(file_paths, &update_tree_block)

      $stderr.puts "\n\n--------------swift file enter--------------"
      generator = SwiftAstDependenciesGeneratorNew.new(
        @options[:project_root_path],
        @options[:swift_ast_show_parsed_tree]
      )
      $stderr.puts "\n\n--------------swift .swift file list enter--------------"
      generator.generate_dependencies(&update_tree_block)

    end

    if @options[:derived_data_paths]
      $stderr.puts "\n\n--------------objc enter--------------"
      @object_files_directories ||= find_object_files_directories
      return tree unless @object_files_directories
      ObjcDependenciesGenerator.new.generate_dependencies(@object_files_directories, &update_tree_block)
    end
  
    tree
  end  

  def dependencies_to_s
    tree = build_dependency_tree
    serializer = TreeSerializer.new(tree)
    output = serializer.serialize(@options[:output_format])

    if @options[:target_file_name]
      File.open(@options[:target_file_name], 'w').write(output.to_s)
    else
      output
    end
  end
end
