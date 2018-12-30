# encoding: UTF-8

require 'optparse'
require 'yaml'
require 'json'
require 'helpers/objc_dependency_tree_generator_helper'
require 'swift/swift_dependencies_generator'
require 'objc/objc_dependencies_generator'
require 'sourcekitten/sourcekitten_dependencies_generator'
require 'dependency_tree'
require 'tree_serializer'

class DependencyTreeGenerator
  def initialize(options)
    @options = options
    @options[:derived_data_project_pattern] = '*-*' unless @options[:derived_data_project_pattern]

    @exclusion_prefixes = @options[:exclusion_prefixes] ? @options[:exclusion_prefixes] : 'NS|UI|CA|CG|CI|CF'
    @object_files_directories = @options[:search_directories]
  end

  def self.parse_command_line_options
    options = {}

    # Defaults
    options[:derived_data_paths] = ['~/Library/Developer/Xcode/DerivedData', '~/Library/Caches/appCode*/DerivedData']
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
      o.on('--swift-files SWIFT_FILES_PATH', "Path to swift files") do |swift_files_path|
           $stderr.puts "------#{swift_files_path}-----"
        options[:swift_files_path] = swift_files_path
      end
      o.on('--swift-ignore SWIFT_IGNORE_FOLDERS', Array, "Folders to ignore when searching for swift files eg x,y,z") do |swift_ignore_folders|
        options[:swift_ignore_folders] = swift_ignore_folders
      end
      o.on('-k FILENAME', 'Generate dependencies from source kitten output (json)') do |v|
        options[:sourcekitten_dependencies_file] = v
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
    tree = generate_depdendency_tree
    tree.filter { |item, _| is_valid_dest?(item, @exclusion_prefixes) } if @options[:ignore_primitive_types]
    tree.filter_links { |_ , _ , type | type == DependencyLinkType::INHERITANCE } if @options[:show_inheritance_only]
    tree
  end

  def generate_depdendency_tree
    return build_sourcekitten_dependency_tree if @options[:sourcekitten_dependencies_file]
    return build_ast_dependency_tree if @options[:swift_files_path]
    return tree_from_object_files_directory
  end

  def tree_from_object_files_directory
    tree = DependencyTree.new

    return tree if !@options || @options.empty?


    update_tree_block = lambda { |source, target| tree.add(source, target) } 
    update_objc_tree_block = lambda { |source, source_type, dest, dest_type, link_type| tree.add_new(source, source_type, dest, dest_type, link_type) } 

    if @options[:derived_data_paths]
      @object_files_directories ||= find_object_files_directories
      return tree unless @object_files_directories
      ObjcDependenciesGenerator.new.generate_dependencies(@object_files_directories, &update_objc_tree_block)
    end

    if @options[:swift_files_path]
      SwiftDependenciesGenerator.new.generate_dependencies(@object_files_directories, &update_tree_block)
    end

    tree
  end  

  def build_ast_dependency_tree
    $stderr.puts "\n\n--------------build_ast_dependency_tree--------------"
    require_relative 'swift-ast-dump/swift_ast_dependencies_generator'
    generator = SwiftAstDependenciesGenerator.new(
      @options[:swift_files_path],
      @options[:swift_ignore_folders],
      @options[:swift_ast_show_parsed_tree]
    )
    generator.generate_dependencies
  end

  def build_sourcekitten_dependency_tree
    generator = SourcekittenDependenciesGenerator.new(
      @options[:sourcekitten_dependencies_file]
    )
    generator.generate_dependencies
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
