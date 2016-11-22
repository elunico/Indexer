require 'json'
require 'pathname'

def escape_bash(name)
  name = name.gsub(' ', '\ ')
  name = name.gsub('(', '\(')
  name = name.gsub(')', '\)')
  name = name.gsub('"', '\"')
  name = name.gsub("'", "\\\\'")
  name = name.gsub(',', '\,')
  name
end

def unescape_bash(name)
  name = name.gsub('\ ', ' ')
  name = name.gsub('\(', '(')
  name = name.gsub('\)', ')')
  name = name.gsub('\"', '"')
  name = name.gsub("\\'", "'")
  name = name.gsub('\,', ',')
  name
end

class IndexBuilder
  def initialize(atDir, withSort=false)
    @allTags = []
    @index = {}
    @filename = 'index.json'
    @indexfile = nil
    @withSort = withSort
    @dir = Pathname.new atDir
    @dir = @dir.realpath
    unless @dir.directory?
      raise Errno::ENOENT "No such dir: #{@dir}"
    end
    Dir.chdir(@dir)

    @workingindex = {}
    @originalindex = {}
  end

  def update_with_other_index_at(dir)
    unless Pathname.directory? dir
      puts "No such directory #{dir}"
      return 1
    end
    unless File.exist? "#{dir}/#{@filename}"
      puts 'No index at this location. '
      return 1
    end
    newindexfile = File.new (dir + '/index.json')
    newindex = JSON.parse(newindexfile.read)
    newindex.each do |k, v|
      if @workingindex.has_key? k
        print("#{k} already exists in this dir. Update the original values (#{@workingindex[k].join(', ')}) with these new index values of #{@newindex[k].join(", ")} (y/n)? ")
        choice = STDIN.gets.chomp
        if choice == 'y'
          @workingindex[k] = v
        else
          next
        end
      end
    end
  end

  def open_index_file(mode='r+')
    @indexfile = File.new(@filename, mode)
  end

  def manually_build_index(directory)
    listdir = `ls #{directory}`.split "\n"
    listdir.each do |i|
      begin
        puts "Tags: #{@allTags.join(', ')}"
        print "Enter comma separated tags for #{i}: "
        userTags = STDIN.gets.chomp.downcase.split ", "
        @index[i] = userTags.uniq
        @allTags.push(*userTags)
        @allTags.uniq!
      rescue Interrupt
        unfin = File.new('.unfinished.tindex', "w")
        unfin.close
        return @index
      end
    end
    return @index
  end

  def first_run()
    choice = '1'
    while choice != '2'
      puts "NO INDEX FOUND! CHECKED ./index.json"
      puts "Choose an option: "
      puts "(1) Build Index"
      puts "(2) Quit"
      choice = STDIN.gets.chomp.downcase
      if choice == '1'
        self.write_index(self.manually_build_index(@dir))
        puts 'Index written! Rerun program to access new options'
        return 1
      elsif choice == '2'
        return 2
      end
    end
  end


  def find_similar_files()
    puts "Files in index: #{@workingindex.keys}"
    print "Enter the filename (inc'l extension) that you want to add: "
    filename = STDIN.gets.chomp
    unless @workingindex.has_key? filename
      puts "That file was not found in the index. Try again\n"
      return nil, nil
    end
    filename, filetags = self.get_item_from_index filename
    similars = self.find_similar filename
    return similars, filetags
  end

  def find_similar(toFile)
    similars = []
    tags = @workingindex[toFile]
    @workingindex.each do |k, v|
      compound = tags + v
      unless compound.uniq!.nil?
        similars.push k
      end
    end
    return similars
  end

  def write_index(index)
    Dir.chdir @dir
    self.open_index_file mode="w"

    jsonobject = JSON.pretty_generate(@index)

    @indexfile.write(jsonobject)
    File.truncate(@filename, jsonobject.length)
    @indexfile.close

  end

  def restart_build()
    print("There seems to be an indexing attempt that was halted by the user. Would you like to (c)ontinue or (r)estart or go to the (m)enu? ")
    choice = STDIN.gets.chomp.downcase
    File.delete ".unfinished.tindex"
    if ["r", "restart"].any? { |resp| resp == choice } then
      self.write_index(self.manually_build_index @dir)
      puts "Index written! Rerun program to access new options"
      return
    else
      puts "You can use the verify option to determine which things need to be put back in the index"
    end
  end

  def update_from_index()
    puts "Current tags: #{@allTags.sort.join(', ')}"
    print "Enter the filename (inc'l extension) that needs updating: "
    filename = STDIN.gets.chomp
    unless @workingindex.has_key? filename
      puts "That value was not found in index. Try again\n "
      return
    end

    puts "File has tags #{@workingindex[filename].sort.join(', ')}"
    print "Enter the tags to *ADD* to the files tags separated by commas"
    tags = STDIN.gets.chomp
    if tags.empty?
      return
    end

    # maybe check before adding tags instead of using .uniq!
    userTags = tags.downcase.split(/, /)
    @workingindex[filename].push(*userTags)
    @allTags.push(*userTags)
    @workingindex[filename].uniq!
    @allTags.uniq!

  end

  def clean_update_from_index()
    puts "Current tags: #{@allTags.sort.join(', ')}"
    print "Enter the filename (inc'l extension that needs updating: "
    filename = STDIN.gets.chomp
    unless @workingindex.has_key? filename then
      puts "That value was not found in the index, try again\n"
      return
    end
    puts "This file HAD tags: #{@workingindex[filename].sort.join(', ')}"
    print "Enter the NEW tags of this file separated by comma-space: "
    tags = STDIN.gets.chomp
    if tags.empty?
      return
    end
    userTags = tags.downcase.split(/, /)
    @workingindex[filename] = userTags
    @allTags.push(*userTags)
    @workingindex[filename].uniq!
    @allTags.uniq!
  end

  def add_new_to_index(filename=nil)
    if filename.nil?
      print "Enter the filename (inc'l extension) to be added to the index: "
      filename = STDIN.gets.chomp
      if filename.empty?
        puts "No file name"
        return
      end
    end
    puts "Current tags: #{@allTags.sort.join(', ')}"
    begin
      print "Enter new tags for #{filename} separated by a comma-space: "
      tags = STDIN.gets.chomp.downcase
    rescue Interrupt
      print "Cancelled! Do you want to save your progress? (y/n) "
      choice = STDIN.gets.chomp.downcase
      if ["yes", "ye", "y"].any? { |i| i == choice }
        print "Do you want to quit? (y/n) "
        news = STDIN.gets.chomp.downcase
        if ["yes", "ye", "y"].any? { |i| i == news }
          self.save_changes cont=true
          return 1
        else
          self.save_changes cont=true
          return
        end
      else
        self.revert_changes
        return 1
      end
    end
    userTags = tags.split(/, /).uniq
    @workingindex[filename] = userTags
    @allTags.push(*userTags)
    @allTags.uniq!
  end

  def get_item_from_index(filename=nil)
    if filename.nil?
      print "Enter the filename (inc'l extension) that you want to get: "
      filename = STDIN.gets.chomp
    end
    unless @workingindex.has_key? filename
      print "That value was not found in the index. Try again\n "
      return nil, nil
    end
    return filename, @workingindex[filename]
  end

  def delete_item_from_index(filename=nil)
    if filename.nil?
      print "Enter the filename (inc'l extension) that you want to get: "
      filename = STDIN.gets.chomp
    end
    unless @workingindex.has_key? filename
      print "That value was not found in the index. Try again\n "
      return
    end
    @workingindex.delete filename
  end

  def list_files_with_tag(tag)
    results = []
    @workingindex.each do |k, v|
      if v.include? tag
        results.push k
      end
    end
    return results
  end

  def save_changes(cont=true)
    if cont
      @indexfile.seek 0, IO::SEEK_SET
      File.truncate(@filename, 0)
      @indexfile.write(JSON.pretty_generate(@workingindex))
      @indexfile.flush
    else
      @indexfile.seek 0, IO::SEEK_SET
      File.truncate(@filename, 0)
      @indexfile.write(JSON.pretty_generate(@workingindex))
      @indexfile.close
      exit 0
    end
  end

  def revert_changes(cont=true)
    if cont
      @indexfile.seek 0, IO::SEEK_SET
      File.truncate(@filename, 0)
      @indexfile.write(JSON.pretty_generate(@originalindex))
      @indexfile.flush
    else
      @indexfile.seek 0, IO::SEEK_SET
      File.truncate(@filename, 0)
      @indexfile.write(JSON.pretty_generate(@originalindex))
      @indexfile.close
      exit 0
    end
  end

  def find_files_with_all_tags()
    files = Hash.new
    andFiles = Array.new
    puts "The following tags exist in this dir: #{@allTags.sort.join(', ')}"
    print "Enter 2 or more comma-space separated tags\nto find all files with those tags: "
    tags = STDIN.gets.chomp.downcase.split(/, /)
    while tags.length < 2 do
      begin
        puts "INVALID! Use ctrl-c to return to the menu. Use find files with tag option to find files with only 1 tag"
        print "You must enter 2 or more comma-space separated tags such as \"tag1, tag2\" (DO not USE QUOTES)"
        tags = STDIN.gets.chomp.downcase.split(", ")
      rescue Interrupt
        return
      end
    end
    tags.each do |i|
      files[i] = self.list_files_with_tag(i).uniq
    end

    finallist = files.values[0]

    files.each do |k, v|
      finallist = finallist & v
    end

    if finallist.count > 0
      puts "\nFound the following #{finallist.count} files: "
      (0...finallist.count).each do |i|
        puts "#{i+1}) #{finallist[i]}"
      end
      print "Choose a fileno to open (0 for none, all for all): "
      opener = STDIN.gets.chomp.downcase
      if opener == "all"
        finallist.each do |i|
          `open #{escape_bash(i)}`
        end
      elsif opener == "0"
        return
      else
        opener = opener.split ", "
        opener.each do |i|
          `open #{escape_bash(finallist[i.to_i]-1)}`
        end
      end
    else
      puts "\nFound no files\n"
    end
  end

  def find_files_with_tags()
    files = Array.new
    puts "The following tags exist in this dir: #{@allTags.sort.join(', ')}"
    print "Enter a tag or many comma-space separated tags to find files with ANY of those tags: "
    tags = STDIN.gets.chomp.downcase.split ", "
    tags.each do |i|
      files.push(*self.list_files_with_tag(i))
    end
    if files.count > 0
      puts "\nFound the following #{files.count} files: "
      ((0...files.count).each).each do |i|
        puts "#{i+1}) #{files[i]}"
      end
      print "Choose a fileno to open (0 for none, all for all): "
      opener = STDIN.gets.chomp.downcase
      if opener == "all"
        files.each do |i|
          `open #{escape_bash(i)}`
        end
      elsif opener == "0"
        return
      else
        opener = opener.split ", "
        opener.each do |i|
          `open #{escape_bash(files[i.to_i-1])}`
        end
      end
    else
      puts "\nFound no files\n"
    end
  end

  def find_files_similar_to_file()
    similars, filetags = self.find_similar_files
    if similars.nil? and filetags.nil?
      return
    end
    puts "\nYour file has tags #{filetags.join(', ')}"
    if similars.count > 0
      puts "The following #{similars.count} files are similar to your file"
      (0...similars.count).each do |i|
        puts "#{i+1}) #{similars[i]}"
      end
      print 'Choose a fileno to open (0 for none, all for all): '
      opener = STDIN.gets.chomp.downcase
      if opener == "all"
        similars.each do |i|
          `open #{escape_bash(i)}`
        end
      elsif opener == "0"
        return
      else
        opener = opener.split ', '
        opener.each do |i|
          `open #{escape_bash(similars[i.to_i-1])}`
        end
      end
    else
      puts 'No files found'
    end
  end

  def replace_all_instances_of_tag()
    puts "These are the tags currently in the directory: #{@allTags.sort.join(', ')}"
    print 'Enter the tag you want to replace: '
    oldtag = STDIN.gets.chomp
    until @allTags.include? oldtag
      print "That is not in the directory. \nEnter the tag you want to replace: "
      oldtag = STDIN.gets.chomp
    end

    print 'Enter the text you want to replace this tag: '
    newtag = STDIN.gets.chomp

    puts 'Working....'

    @workingindex.each do |k, v|
      if v.include? oldtag
        v.delete oldtag
        v.push newtag unless v.include? newtag
      end
    end
    @allTags.delete oldtag
    puts 'Done!'
  end

  def begin_interface()
    puts "Welcome you are at dir #{@dir}"
    if not File.exists? @filename
      self.first_run
      return
    else
      if File.exists? '.unfinished.tindex'
        self.restart_build
      end
      self.open_index_file
      @workingindex = JSON.parse @indexfile.read
      @originalindex = Marshal.load(Marshal.dump(@workingindex))
      if @allTags.empty?
        @workingindex.each do |k, v|
          @allTags.push(*v)
        end
        @allTags.uniq!
      end
    end
    choice = '1'
    while choice != '14' and choice != '15!'
      begin
        puts "\nChoose an option: "
        puts '(1)  Rebuild Index'
        puts '(2)  Update from Index'
        puts '(3)  Clean update from Index'
        puts '(4)  Add new to Index'
        puts '(5)  Remove from Index'
        puts '(6)  Look up in Index'
        puts '(7)  Replace all instances of a tag'
        puts '(8)  Find files with tag'
        puts '(9)  Find files with all (several) tags'
        puts '(10) Verify complete index'
        puts '(11) Find files similiar to file'
        puts '(12) Update index from other directory'
        puts '(13) Save'
        puts '(14) Save & Quit'
        puts '(15!) Discard All Changed & Quit'
        choice = STDIN.gets.chomp
        case choice
          when "1"
            puts 'Are you sure, this will remove your current index (maybe back it up first?)? '
            newchoice = STDIN.gets.chomp
            if ['y', 'yes', 'i\'m sure', 'sure'].any? { |i| i == newchoice}
              self.write_index(self.manually_build_index(@dir))
              print('index written! Restart for options')
              return
            end
          when "2"
            self.update_from_index
          when "3"
            self.clean_update_from_index
          when "4"
            self.add_new_to_index
          when "5"
            self.delete_item_from_index
          when "6"
            filename, item_tags = self.get_item_from_index
            if filename.nil? and item_tags.nil?
              next
            end
            puts "Item: [#{filename}] has tags: #{item_tags.sort.join(', ')}"
          when "7"
            self.replace_all_instances_of_tag
          when "8"
            self.find_files_with_tags
          when "9"
            self.find_files_with_all_tags
          when "10"
            missing_files = Array.new
            ls = `ls #{@dir}`.split(/\n/)
            ls.delete "index.json"
            ls.each do |i|
              if not @workingindex.has_key? i
                missing_files.push i
              end
            end
            if @withSort then missing_files.sort! end
            if missing_files.count > 0
              puts "The following files exist in #{@dir} but not in the index: "
              (0...missing_files.count).each do |i|
                puts "#{i+1} #{missing_files[i]}"
              end


              puts "Choose a fileno to add to the index (0 for none, all for all): "
              opener = STDIN.gets.chomp.downcase
              res = 0
              if opener == 'all'
                (0...missing_files.count).each do |x|
                  res = self.add_new_to_index missing_files[x.to_i - 1]
                  if res == 1
                    break
                  end
                end
                if res == 1 then break end
              elsif opener == '0'
                next
              else
                opener = opener.split ', '
                opener.each do |i|
                  res = self.add_new_to_index(missing_files[i.to_i-1])
                  if res == 1 then break end
                end
                if res == 1 then break end
              end
            else
              puts "No missing files found"
            end

            extra_files = Array.new
            ls = `ls #{@dir}`.split(/\n/)
            ls.delete "index.json"
            @workingindex.keys.each do |i|
              if not ls.include? i
                extra_files.push i
              end
            end

            if @withSort then extra_files.sort! end
            if extra_files.count > 0
              puts "The following files exist in the index but not in #{@dir}: "
              (0...extra_files.count).each do |i|
                puts "#{i+1} #{extra_files[i]}"
              end


              puts "Choose a fileno to remove from the index (0 for none, all for all): "
              opener = STDIN.gets.chomp.downcase
              if opener == 'all'
                (0...extra_files.count).each do |x|
                  @workingindex[extra_files[i]].each do |j|
                    @allTags.delete j
                  end
                  @workingindex.delete extra_files[x]
                end
              elsif opener == '0'
                next
              else
                opener = opener.split ', '
                opener.each do |i|
                  j = i.to_i
                  @workingindex[extra_files[j]].each do |x|
                    @allTags.delete x
                  end
                  @workingindex.delete extra_files[j]
                end
              end
            else
              puts "No missing files found"
            end

          when "11"
            self.find_files_similar_to_file
          when "12"
            print "Enter the ABSOLUTE path to the directory: "
            newdir = STDIN.gets.chomp
            self.update_with_other_index_at newdir
          when "13"
            self.save_changes cont=true
          when "14"
            self.save_changes cont=false
            break
          when "15!"
            self.revert_changes cont=false
            break
          else
            redo
            # type code here
        end

      rescue Interrupt
        puts "STOP! Do you want to save changes (y/n) "
        choice = STDIN.gets.chomp.downcase
        if ['y', 'yes', 'ye', 'yy'].any? { |x| x == choice }
          puts "Do you want to quit? (y/n) "
          choice = STDIN.gets.chomp.downcase
          if ['y', 'yes', 'ye', 'yy'].any? { |x| x == choice }
            self.save_changes(cont=false)
            return
          else
            self.save_changes(cont=true)
          end
        else
          self.revert_changes(cont=false)
        end
      end
    end
    unless @indexfile.closed?
      @indexfile.close
    end
  end
end