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
    '+gsoap',
    'ANZAPIClients',
    'xcodeproj']).freeze

  @@path_string_include = #include some subpaths to the main path above
  Set.new([
  'Swaggers/Models']).freeze
    
  #TODO: use this as exclusion prefix
  @@exclusion_prefixes = 
  Set.new([
  'NS|UI|CA|CG|CI|CF|CL|IB|SF|AV|CN|CT|EK|SCN|WC|PK|MK|OS']).freeze

  @@objc_project_nodes_all = 
  Set.new([
    'ANZ',
    'WK',
    'VFK',
    'ADB',
    'AF',
    'CAR',
    'Card',
    'CM',
    'ID',
    'JR',
    'JS',
    'MB',
    'NS',
    'RK',
    'BillPaymentValidatorResults',
    'HTTP',
    'RX',
    'TV',
    'NC',
    'OS',
    'PDF',
    'QL',
    'NC',
    'TTT',
    'Register',
    'Reach',
    'SecTrust',
    'Vessel',
    'Watch']).merge(@@exclusion_prefixes.first.split('|')).freeze

  def self.path_strings_to_ignore
    @@path_string_ignore
  end

  def self.path_strings_to_include
    @@path_string_include
  end

  def self.exclusion_prefixes
    @@exclusion_prefixes
  end

  def self.objc_project_nodes_all
    @@objc_project_nodes_all
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

def objc_project_nodes_all
  return Configuration.objc_project_nodes_all
end

def is_node_objc(node_name)
  node_is_objc = false 
  for prefix in objc_project_nodes_all
    if node_name.start_with?(prefix)
      node_is_objc = true
      break
    end
  end
  return node_is_objc
end
