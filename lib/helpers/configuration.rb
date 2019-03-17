class Configuration
  @@path_string_ignore = #exclude file paths to Tests in frameworks or subfolders, and Demo app
    Set.new([
    'Content/',
    'Demo',
    'DerivedData',
    'Documentation',
    'fastlane',
    'scripts',
    'Specs',
    'Tests',
    'Tools',
    'UITests',
    'UITestsSIT',
    'UITestsSITEnergy',
    'vendor',
    'Pods', 
    'DemoSupport', 
    'DeveloperSupport', 
    'TestSupport', 
    'Foundation/',
    'Reachability',
    'Mock',
    'ANZAPIClients',
    'xcodeproj']).freeze

  @@path_string_include = #include some subpaths to the main path above
  Set.new([
  'Swaggers/Models']).freeze
    
  def self.path_strings_to_ignore
    @@path_string_ignore
  end

  def self.path_strings_to_include
    @@path_string_include
  end

end

def path_strings_to_ignore
    return Configuration.path_strings_to_ignore
end

def path_strings_to_include
  return Configuration.path_strings_to_include
end

def final_paths(paths)
  paths_to_ignore = path_strings_to_ignore()
  paths_to_include = path_strings_to_include()
  final_paths_after_rejection = paths.reject{|path| paths_to_ignore.any?{|word| path.include?(word)}}
  final_paths_after_inclusion = paths.select{|path| paths_to_include.any?{|word| path.include?(word)}}
  final_paths = final_paths_after_rejection + final_paths_after_inclusion
  return final_paths
end
