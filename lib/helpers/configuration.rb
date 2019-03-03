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
    'xcodeproj']).freeze
    
  def self.path_strings_to_ignore
    @@path_string_ignore
  end

end

def path_strings_to_ignore
    return Configuration.path_strings_to_ignore
end

def final_paths(paths)
    paths_to_ignore = path_strings_to_ignore()
    final_paths = paths.reject{|path| paths_to_ignore.any?{|word| path.include?(word)}}
    return final_paths
end
