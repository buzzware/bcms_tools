Dir.chdir(File.dirname(__FILE__)) { Dir['bcms_tools/*'] }.each {|f| require f }

