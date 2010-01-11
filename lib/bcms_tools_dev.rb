# when you want to load the live version of bcms_tools, not the gem :
# require File.join(File.dirname(__FILE__),'../../../../../bcms_tools/lib/bcms_tools_dev.rb');
require File.join(File.dirname(__FILE__),'bcms_tools/require_paths')	# load require_paths early for next line
require_paths_first '.'
require 'bcms_tools'

