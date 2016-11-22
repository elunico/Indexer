require './Indexing'

def main(args)
  if args.nil?
    puts 'Usage: indexing.rb [-h] dir [-s --sorted]'
    return
  end

  if args[0] == '-h'
    puts 'indexing.rb
================================================================================
Optional Arguments:
  -h          Print this help message and quit the program

  -s          Sort tags and filenames before printing them to the screen. Since
  --sorted    this program is meant to be used on directories with many files
              and potentially many tags, this sorting can get expensive. Only
              use when necessary for interfacing

Required Arguments:
  dir         The absolute path at which you wish to interface with the index.
              If no index exists at this place you will have to manually build
              it. Building does not have to go to completion nor does it have
              to be completed in one go as it may be resumed at anytime. The
              index requires at least one indexed file for all functionality
              and some functionality requires at least two or more indexed
              files.
'
    return
  end
  if args[0].nil?
    puts "No directory argument provided! Enter one now: "
    args[0] = gets.chomp!
  end
  ib = IndexBuilder.new atDir=args[0], withSort=(args[1] == '-s' or args[1] == '--sorted')
  ib.begin_interface

end

if __FILE__ == $0
  main ARGV
end
