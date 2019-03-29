require 'helpers/logger'
require 'helpers/configuration'

def find_objc_files(project_root_folder_path)

    return nil unless project_root_folder_path

    paths = []

    IO.popen("find #{project_root_folder_path} -name \"*.m\" -o -name \"*.h\" ") { |f|
        f.each do |line|
        paths << line
        end
    }
    final_paths = final_paths(paths)
    Logger.log_message("-----------final_paths: #{final_paths}----------------------")
    Logger.log_message("\n\n\n\n")

    final_paths.sort! #to have .h and .m one after another
    return final_paths

end