require 'helpers/logger'
require 'helpers/configuration'

def find_swift_files(project_root_folder_path)

    return nil unless project_root_folder_path

    paths = []

    IO.popen("find #{project_root_folder_path} -name \"*.swift\" ") { |f|
        f.each do |line|
        paths << line
        end
    }
    final_paths = final_paths(paths)
    Logger.log_message("-----------final_paths: #{final_paths}----------------------")
    Logger.log_message("\n\n\n\n")

    final_paths.sort! #just to match the objc logic for now
    return final_paths

end