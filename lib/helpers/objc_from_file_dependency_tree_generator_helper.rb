require 'set'
require 'helpers/logger'

def find_objc_implementation_files(project_root_folder_path)

    return nil unless project_root_folder_path

    paths = []

    IO.popen("find #{project_root_folder_path} -name \"*.m\" -o -name \"*.h\" ") { |f|
        f.each do |line|
        paths << line
        end
    }

    paths_to_ignore = 
    ["Content",
    "Demo",
    "DerivedData",
    "Documentation",
    "fastlane",
    "scripts",
    "Specs",
    "Tests",
    "Tools",
    "UITests",
    "UITestsSIT",
    "UITestsSITEnergy",
    "vendor",
    "Pods", 
    "DemoSupport", 
    "DeveloperSupport", 
    "TestSupport", 
    "Foundation/",
    "Reachability"]
    final_paths = paths.reject{|path| paths_to_ignore.any?{|word| path.include?(word)}}
    Logger.log_message("-----------final_paths: #{final_paths}----------------------")

    final_paths.sort! #to have .h and .m one after another
    return final_paths

end