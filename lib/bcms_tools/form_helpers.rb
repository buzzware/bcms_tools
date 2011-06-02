Cms::FormBuilder.class_eval do

	attr_reader :template

	# ensure the related css is included
	def ensure_css
		template.content_for :html_head do
			template.stylesheet_link_tag("bcms_tools.css")
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
		method = (aOptions.delete(:method) || :attachment)
		method_file = (method.to_s + '_file').to_sym
		_attachment = object.send(method)
		result = cms_file_field(method_file.to_sym, aOptions)
		
		underscore_id = object_name
		underscore_id += '_'+options[:index].to_s if options[:index]
		underscore_id += '_'+method_file.to_s
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
				
		thumbnail = if _attachment
			"<img class=\"thumbnail\" src=\"#{BcmsTools::PageHelper.attachment_cropped_src(_attachment,64,64)}\" width=\"64\" height=\"64\"/>"
		else
			'<div style="width: 64px; height: 64px; position:static; display: block; float: left; border-style: solid; border-width: 1px; border-color: gray"></div>'
		end
		result = result.sub('</label>','</label>'+thumbnail)
		result = result.gsub(object_name+'_'+method_file.to_s,underscore_id)
		result = StringUtils.split3(result,/<div class="fields file_fields.*?>/) {|h,m,t| XmlUtils.quick_join_att(m,'class','thumbnail_upload',' ') }  
		unless aOptions[:remove_check_box]==false || object.new_record?
			checkbox = '<div style="display: block; float: right; width: auto; height: auto;">'+remove_check_box()+'</div>'
			result = StringUtils.split3(result,/<\/div>\Z/){|h,m,t| 
				checkbox+'<br clear="all" />'+m
			}
		end
		result = StringUtils.split3(result,/<div.*?>/){|h,m,t| m+'<br clear="all" />'}		
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

	def text_display_field(aField,aOptions={})
		template.concat("<br clear=\"all\" />") # Fixes issue with bad line wrapping
		template.concat('<div class="fields text_fields">')
		if aOptions[:label]
			label aField, aOptions[:label]
		else
			label aField
		end
		template.concat("<div id=\"artist_#{aField}\" class=\"text_display\">#{object.send(aField.to_sym)}</div>")
		
		template.concat("<div class=\"instructions\">#{aOptions[:instructions]}</div>") if aOptions[:instructions]
		template.concat("<br clear=\"all\" />") # Fixes issue with bad line wrapping
		template.concat("</div>")
	end
	
	def bcmstools_check_box(aField,aOptions={})
		result = "<br clear=\"all\" />" # Fixes issue with bad line wrapping
		result += '<div class="fields text_fields">'
		result += if aOptions[:label]
			label aField, aOptions[:label]
		else
			label aField
		end
		ins = aOptions.delete(:instructions)
		result += check_box(aField, aOptions)
		
		result += "<div class=\"instructions\">#{ins}</div>" if aOptions[:instructions]
		result += "<br clear=\"all\" />" # Fixes issue with bad line wrapping
		result += "</div>"
		result
	end

end


