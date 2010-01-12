module BcmsTools
	module Thumbnails
	
		# for future bcms tools gem
		#http://snippets.dzone.com/posts/show/295
		#def close_tags(text)
		#	open_tags = []
		#	text.scan(/\<([^\>\s\/]+)[^\>\/]*?\>/).each { |t| open_tags.unshift(t) }
		#	text.scan(/\<\/([^\>\s\/]+)[^\>]*?\>/).each { |t| open_tags.slice!(open_tags.index(t)) }
		#	open_tags.each {|t| text += "</#{t}>" }
		#	text
		#end
		
		def self.thumbnail_name_from_attachment(aAttachment,aWidth,aHeight)
			extThumb = aAttachment.file_extension
			size = "#{aWidth}x#{aHeight}"
			return File.basename(aAttachment.file_location)+'-'+size+'.'+extThumb
		end
		
		def self.attachment_from_url(aUrl)
			if aUrl.begins_with?('/cms/attachments/')
				id,version = aUrl.scan(/\/cms\/attachments\/([0-9]+)\?version=([0-9]+)/).flatten.map {|i| i.to_i}
				att = Attachment.find_by_id_and_version(id,version)																												 
			else
				att = Attachment.find_live_by_file_path(aUrl)
			end
		end
		
		def self.image_location_from_url(aUrl)
			att = attachment_from_url(aUrl)
			return att && att.full_file_location
		end
		
		def self.scale_to_fit(aWidth,aHeight,aDestWidth,aDestHeight)
			wRatio = aDestWidth / aWidth
			hRatio = aDestHeight / aHeight
			ratio = (wRatio < hRatio ? wRatio : hRatio)
			return aWidth*ratio,aHeight*ratio
		end
		
	end
	
	module PageHelper

		def container_sized(aName,aWidth,aHeight)
			StringUtils.split3(container(aName),/<img.*?>/,-1) do |head,img,tail|
				src = XmlUtils.quick_att_from_tag(img,'src')
				if src.begins_with?('/images/cms/')					# a cms button
					img
				else
					thumberize_img(img,aWidth,aHeight)	# an image in the container
				end
			end
		end
		
		# with_images( container(:image_bar) ) do |img|
		#		thumberize_img(img,width,height)
		#	end	
		def with_images(aContainer)
			return nil if aContainer.nil?
			result = aContainer.clone
			offset = 0
			aContainer.scan_md(/<img.*?>/).each do |img_md|
				src = XmlUtils.quick_att_from_tag(img_md.to_s,'src')
				next if !src || src.begins_with?('/images/cms/')
				first,last = img_md.offset(0)
				output = yield(img_md.to_s)
				result[first+offset..last-1+offset] = output
				offset += output.length - (last-first)
			end
			result
		end
		
		def thumberize_img(img,aWidth,aHeight)
			begin
				urlImage = XmlUtils.quick_att_from_tag(img,'src')
			
				att = BcmsTools::Thumbnails::attachment_from_url(urlImage)
				pathImage = att && att.full_file_location
			
				throw RuntimeError.new("file doesn't exist #{pathImage}") unless File.exists? pathImage
				throw RuntimeError.new("could not get file geometry #{pathImage}") unless geomImage = Paperclip::Geometry.from_file(pathImage)
			
				aDestWidth,aDestHeight = BcmsTools::Thumbnails::scale_to_fit(geomImage.width,geomImage.height,aWidth,aHeight).map {|i| i.to_i}
			
				nameThumb = BcmsTools::Thumbnails::thumbnail_name_from_attachment(att,aWidth,aHeight)		
	
				pathThumb = File.join(APP_CONFIG[:thumbs_cache],nameThumb)
			
				if !File.exists?(pathThumb)
					# generate thumbnail at size to fit container
					throw RuntimeError.new("Failed reading image #{pathImage}") unless objThumb = Paperclip::Thumbnail.new(File.new(pathImage), "#{aDestWidth}x#{aDestHeight}")
					throw RuntimeError.new("Failed making thumbnail #{pathImage}") unless foThumb = objThumb.make
					FileUtils.cp(foThumb.path,pathThumb,:force => true)
					FileUtils.rm(foThumb.path)
					#POpen4::shell_out("sudo -u tca chgrp www-data	#{pathThumb}; sudo -u tca chmod 644 #{pathThumb}")
				end
			
				img = XmlUtils.quick_set_att(img,'src',File.join(APP_CONFIG[:thumbs_url],nameThumb))
				return HtmlUtils.fixed_frame_image(img,aWidth,aHeight,aDestWidth,aDestHeight)
			rescue Exception => e
				RAILS_DEFAULT_LOGGER.warn "thumberize_img error: #{e.inspect}"
				RAILS_DEFAULT_LOGGER.debug e.backtrace      
				return img
			end
		end
		
		def attachment_cropped_src(aAttachment,aWidth,aHeight)
			begin	
				pathImage = aAttachment.full_file_location
				throw RuntimeError.new("file doesn't exist #{pathImage}") unless File.exists? pathImage
				nameThumb = BcmsTools::Thumbnails::thumbnail_name_from_attachment(aAttachment,aWidth,aHeight)		
				pathThumb = File.join(APP_CONFIG[:thumbs_cache],nameThumb)
				if !File.exists?(pathThumb)
					# generate thumbnail at size to fit container
					throw RuntimeError.new("Failed reading image #{pathImage}") unless objThumb = Paperclip::Thumbnail.new(File.new(pathImage), "#{aWidth}x#{aHeight}#")
					throw RuntimeError.new("Failed making thumbnail #{pathImage}") unless foThumb = objThumb.make
					FileUtils.cp(foThumb.path,pathThumb,:force => true)
					FileUtils.rm(foThumb.path)
				end
				return File.join(APP_CONFIG[:thumbs_url],nameThumb)
			rescue Exception => e
				RAILS_DEFAULT_LOGGER.warn "thumberize_img error: #{e.inspect}"
				RAILS_DEFAULT_LOGGER.debug e.backtrace      
				return ''
			end
		end
		
		def framed_attachment_img(aAttachment,aWidth,aHeight)
			begin
				pathImage = aAttachment.full_file_location
			
				throw RuntimeError.new("file doesn't exist #{pathImage}") unless File.exists? pathImage
				throw RuntimeError.new("could not get file geometry #{pathImage}") unless geomImage = Paperclip::Geometry.from_file(pathImage)
			
				aDestWidth,aDestHeight = BcmsTools::Thumbnails::scale_to_fit(geomImage.width,geomImage.height,aWidth,aHeight).map {|i| i.to_i}
			
				nameThumb = BcmsTools::Thumbnails::thumbnail_name_from_attachment(aAttachment,aWidth,aHeight)		
	
				pathThumb = File.join(APP_CONFIG[:thumbs_cache],nameThumb)
			
				if !File.exists?(pathThumb)
					throw RuntimeError.new("Failed reading image #{pathImage}") unless objThumb = Paperclip::Thumbnail.new(File.new(pathImage), "#{aDestWidth}x#{aDestHeight}")
					throw RuntimeError.new("Failed making thumbnail #{pathImage}") unless foThumb = objThumb.make
					FileUtils.cp(foThumb.path,pathThumb,:force => true)
					FileUtils.rm(foThumb.path)
				end
				
				img = "<img src=\"#{File.join(APP_CONFIG[:thumbs_url],nameThumb)}\" width=\"#{aDestWidth}\" height=\"#{aDestHeight}\" />"
				return HtmlUtils.fixed_frame_image(img,aWidth,aHeight,aDestWidth,aDestHeight)
			rescue Exception => e
				RAILS_DEFAULT_LOGGER.warn "thumberize_img error: #{e.inspect}"
				RAILS_DEFAULT_LOGGER.debug e.backtrace      
				return ''
			end
		end

	end
end
