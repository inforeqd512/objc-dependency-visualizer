  #get the list of swift files 
  def swift_files_list (folder_paths)

    $stderr.puts "\n\n---------------swift_files_list---------------------"

    swift_files_list = []

    folder_paths.each { |path|
      $stderr.puts "-------#{path}-----"
      $stderr.puts "find #{path} -name *.swift"
      IO.popen("find #{path} -name *.swift") { |f|
        f.each do |line|
          swift_files_list << line
        end
      }
    }

    swift_files_list.each { |file|
      $stderr.puts "----file: #{file}"
    }
    $stderr.puts "\n\n\n\n"

    return swift_files_list
    
  end

  #get list of paths which should be used to find swift source files
  def swift_files_path_list (swift_files_path, swift_ignore_folders)
    
    $stderr.puts "\n\n----swift_files_path_list-----"

    paths = []
    $stderr.puts "find #{swift_files_path} -type d -depth 1"
    IO.popen("find #{swift_files_path} -type d -depth 1") { |f|
      f.each do |line|
        line.chomp!
        ignore_folder_match = false
        for ignore_folder in swift_ignore_folders do
          if line.include?(ignore_folder) or line.include?("xcodeproj") #also exclude the xcodeproj file by default
            ignore_folder_match = true
            break
          end
        end
        
        line_sub = line.gsub(/ /, '\ ')#global escape the spaces for folders that have several words

        if ignore_folder_match == false
          paths << line_sub
        end
      end
    }

    paths.each { |item|
      $stderr.puts "----#{item}"
    } 
    $stderr.puts "\n\n\n\n"

    return paths
  end