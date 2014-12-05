# As of BrowserCMS 3.0.6, on MySQL, tables created by BrowserCMS's custom methods eg. create_content_table
# default to MyISAM format (Rails defaults to InnoDB).

# The following makes InnoDB the default format for tables for browsercms methods
# that use create_table_from_definition eg. create_content_table and create_versioned_table
ActiveRecord::ConnectionAdapters::MysqlAdapter.class_eval do
	alias :orig_create_table_from_definition :create_table_from_definition
	def create_table_from_definition(table_name, options, table_definition)
		if !options || !options[:options] || !options[:options].index(/ENGINE/i)
			options ||= {}
			if options[:options]
				options[:options] = options[:options] + "\nENGINE = InnoDB"
			else
				options[:options] =  "ENGINE = InnoDB"
			end
		end
		orig_create_table_from_definition(table_name,options,table_definition)
	end
end

module ActiveRecord
  module ConnectionAdapters
    module SchemaStatements

			#The following methods and migration will convert all
			# MyISAM tables to InnoDB format.
			#
			# Also see https://browsermedia.lighthouseapp.com/projects/28481-browsercms-30/tickets/319-custom-migrations-methods-eg-create_content_table-result-in-myisam-tables
			#
			# example migration :
			#gem 'bcms_tools'; require 'bcms_tools'
			#
			#class ConvertAllToInnodb < ActiveRecord::Migration
			#  def self.up
			#		convert_database_to_innodb()
			#  end
			#
			#  def self.down
			#  end
			#end

			def get_isam_tables(aDatabase=nil)
				aDatabase ||= ActiveRecord::Base.connection.current_database
				isam_tables = []
				ActiveRecord::Base.connection.execute("SELECT table_name FROM information_schema.tables WHERE engine = 'MyISAM' and table_schema = '#{aDatabase}';").each {|s| isam_tables << s}
				isam_tables
			end

			def convert_tables_to_innodb(aTables,aDatabase=nil)
				aDatabase ||= ActiveRecord::Base.connection.current_database
				aTables.each {|t| ActiveRecord::Base.connection.execute("ALTER TABLE #{aDatabase}.#{t} engine=InnoDB;")}
			end

			# aDatabase may be nil to use the current database
			def convert_database_to_innodb(aDatabase=nil)
				convert_tables_to_innodb(get_isam_tables(aDatabase),aDatabase)
			end

		end
	end
end

