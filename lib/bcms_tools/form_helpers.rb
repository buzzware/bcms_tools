Cms::FormBuilder.class_eval do

	attr_reader :template

	# ensure the related css is included
	def ensure_css
		template.content_for :html_head do
			template.stylesheet_link_tag("for_bcms_tools.css")
		end	
	end

	def remove_check_box()
		"#{check_box('_destroy')} Remove ?"
	end

	def jquery_escape(aString)
		# from http://samuelsjoberg.com/archive/2009/09/escape-jquery-selectors
    #	return str.replace(/([#;&,\.\+\*\~':"\!\^$\[\]\(\)=>\|])/g, "\\$1");
		aString.gsub(/([#;&,\.\+\*\~':"\!\^$\[\]\(\)=>\|])/) {|c| '\\\\'+c}
	end

	# standard original file upload
	#
	#//<![CDATA[
	#
	#    jQuery(function($) {
	#      $('#mock_stock_image_attachment_file')									// <input type="text" 
	#        .focus(function() {this.blur()})
	#        .mousedown(function() {this.blur()})
	#      $('#stock_image_attachment_file').change(function() {	// <input type="file" 
	#          $('#mock_stock_image_attachment_file')							// <input type="text" 
	#            .attr('value', $(this).attr('value'))
	#      })
	#    })
	#
	#//]]>
	#
	#<div class="fields file_fields">
	#
	#    <label for="stock_image_attachment_file">File</label>
	#
	#  <div class="file_inputs" id="stock_image_attachment_file_div">
	#    <input type="file" tabindex="3" size="1" name="stock_image[attachment_file]" id="stock_image_attachment_file" class="file">
	#    <div class="fakefile">
	#        <input type="text" id="mock_stock_image_attachment_file" class="mock" name="temp">
	#        <img src="/images/cms/browse.gif?1261031544" alt="Browse">
	#    </div>
	#  </div>
	#
	#</div>

	def thumbnail_upload_field(aOptions)
		ensure_css
		aOptions[:label] ||= "Upload Image"
		result = cms_file_field(:attachment_file, aOptions) + '<br clear="all" />'
		method = 'attachment_file'
		
		underscore_id = object_name+'_'+options[:index].to_s+'_'+method
		underscore_id_esc = jquery_escape(underscore_id)
		underscore_id_nobrac = underscore_id.gsub('[','_').gsub(']','')

		template.content_for :html_head do
			template.javascript_tag do
				<<-EOS
				jQuery(function($) {
					$('input#mock_#{underscore_id_esc}')									// <input type="text"
						.focus(function() {this.blur()})
						.mousedown(function() {this.blur()})
					$('input##{underscore_id_nobrac}').change(function() {	// <input type="file"
							$('input#mock_#{underscore_id_esc}')							// <input type="text"
								.attr('value', $(this).attr('value'))
					})
				})
				EOS
			end
		end
				
		thumbnail = if object.attachment
			"<img class=\"thumbnail\" src=\"#{Cms::PageHelper.attachment_cropped_src(object.attachment,64,64)}\" width=\"64\" height=\"64\"/>"
		else
			'<div style="width: 64px; height: 64px; position:static; display: block; float: left; border-style: solid; border-width: 1px; border-color: gray"></div>'
		end
		result = result.sub('</label>','</label>'+thumbnail)
		result = result.gsub(object_name+'_'+method,underscore_id)
		result = StringUtils.split3(result,/<div class="fields file_fields.*?>/) {|h,m,t| XmlUtils.quick_join_att(m,'class','thumbnail_upload',' ') }  
		result = '<div style="display: block; float: right; width: auto; height: auto;">'+remove_check_box()+'</div>' + result unless aOptions[:remove_check_box]==false || object.new_record?
		return result
	end

	# surround child fields with an appropriate div
	# usage :
	#<% f.child_fields do %>
	#	<% f.fields_for( :stock_images_attributes, img, :index => i ) do |image_form| %>
	#		<%= image_form.cms_text_field :name, :label => "name (short)" %>
	#		<%= image_form.cms_text_field :caption, :label => 'caption' %>
	#	<% end %>
	#<% end %>	
	def child_fields(aClass='child_fields', &block)
		content = template.capture(&block)
		template.concat("<div class=\"#{aClass}\">")
		template.concat(content)
		template.concat("</div>")
	end

end


