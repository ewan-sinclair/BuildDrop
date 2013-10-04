#!/usr/bin/ruby

# Puts the current binary in the designated project into the given folder
# It will be named XXXX-cccccc.apk, where:
# XXXX is the highest number prefix already in the dropbox directory
# cccccc is the current HEAD commit ID

require 'yaml'

@yaml_file=".builddrop_config.yaml"

#Grabs settings from YAML config file
def parse_settings()
  if File.file?(@yaml_file)
    yaml=YAML.load_file(@yaml_file)
    @check_debug=(yaml.has_key? "abort_debugwait") ? yaml["abort_debugwait"] : true
    @check_dirty=(yaml.has_key? "abort_dirty") ? yaml["abort_dirty"] : true
    @git_dir=(yaml.has_key? "git_dir") ? yaml["git_dir"] : "./"
    @drop_dir=yaml["drop_dir"]
    @project_name=yaml["project_name"]
    @roughcut_dir=yaml["roughcut_dir"]
    @commit_id=`git --git-dir="#{@git_dir}/.git" rev-parse HEAD | head -c 6`
  else
    puts "No config file detected, exiting"
    exit(1)
  end
end

# Drop a proper build
def drop_build()
  # The '\1' in the sed command is double escaped to work here. Beware!
  build_nums_str=%x[ /bin/ls "#{@drop_dir}" | sed -r "s/^([0-9]{4}).*/\\1/g" ]
  build_nums_str = "0" if build_nums_str == ""

  new_build_num=build_nums_str.split("\n").map(&:to_i).sort{|x,y| x<=>y}.last+1
  newName="#{new_build_num.to_s.rjust(4, '0')}-#{@commit_id}.apk"
  
  %x[ cp "#{@git_dir}/bin/#{@project_name}.apk" "#{@drop_dir}/#{newName}" ]
  print "Dropped #{@drop_dir}/#{newName}\n"
end

# Drop a rough build
def drop_rough()
  build_nums_str=%x[ /bin/ls "#{@roughcut_dir}" | sed -r "s/^ROUGHCUT-([0-9]{4}).*/\\1/g" ]
  build_nums_str = "0" if build_nums_str == ""
  new_build_num=build_nums_str.split("\n").map(&:to_i).sort{|x,y| x<=>y}.last+1
  
  newName="ROUGHCUT-#{new_build_num.to_s.rjust(4, '0')}-#{@commit_id}.apk"
  %x[ cp "#{@git_dir}/bin/#{@project_name}.apk" "#{@roughcut_dir}/#{newName}" ]
  print "Dropped #{@roughcut_dir}/#{newName}\n"
end

# Delete the last dropped build
def delete_last()
  # TODO: delete last file dropped. Prompt for confirmation.
end

#Check to see if there are uncommented debugger connection statements
def has_debugger_statements()
  %x[ egrep -r "^[^/]*android.os.Debug.waitForDebugger\(\)" src/ ]
  has_statements = $?.exitstatus == 0 ? true : false
  puts "Uncommented debugger connections detected" if has_statements
  return has_statements
end

def branch_unclean()
  unclean = %x[ git status --porcelain ].length > 0
  puts "Git branch unclean" if unclean
  return unclean
end

def has_problems()
  problems=false
  problems = true if @check_debug && has_debugger_statements()
  problems = true if @check_unclean && branch_unclean()
  return problems
end

# Parse out and act on CLI options
def exec_input()
  if(ARGV.length >0)
    case ARGV[0].downcase
    when "rough"
      drop_rough()
    else
      puts "Invalid option: #{ARGV[0]}"
    end
  else
    drop_build()
  end
end

parse_settings()
if !has_problems
  exec_input()
else
  puts "Not dropping due to problems"
end