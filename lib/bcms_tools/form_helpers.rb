require 'ruby-debug'; debugger
module ActionView
  module Helpers
		module FormHelper

			def remove_check_box()
				"<br/><br/>#{check_box('_destroy')} Remove"
			end
		
			def thumbnail_upload(aOptions)
				aOptions[:label] += ' <div style="width: 64px; height: 64px; display: inline-block; background-color: red" />'
				cms_file_field(:attachment_file, aOptions)
			end

		end
	end	
end

