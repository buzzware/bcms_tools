# BEGIN Paperclip 2.3.1.1 fixes for funky filenames

Paperclip.class_eval do

	def self.run cmd, params = "", expected_outcodes = 0
		command = %Q[#{path_for_command(cmd)} #{params}]	#.gsub(/\s+/, " ")	# removed unnecessary(?) whitespace eating
		command = "#{command} 2>#{bit_bucket}" if Paperclip.options[:swallow_stderr]
		Paperclip.log(command) if Paperclip.options[:log_command]
		output = `#{command}`
		unless [expected_outcodes].flatten.include?($?.exitstatus)
			raise Paperclip::PaperclipCommandLineError, "Error while running #{cmd}"
		end
		output
	end

end

Paperclip::Geometry.class_eval do
	def self.from_file file
		file = file.path if file.respond_to? "path"
		geometry = begin
								 srcpath = file.gsub('$','\$')	# escaped $, other chars may need to be added here
								 Paperclip.run("identify", %Q[-format "%wx%h" "#{srcpath}"[0]])
							 rescue Paperclip::PaperclipCommandLineError
								 ""
							 end
		parse(geometry) ||
			raise(Paperclip::NotIdentifiedByImageMagickError.new("#{file} is not recognized by the 'identify' command."))
	end
end

Paperclip::Thumbnail.class_eval do

	attr_accessor :basename		# need access to basename so we can change it away from bizarre file names that cause problems. could auto generate better names here

	def make
		src = @file
		dst = Tempfile.new([@basename, @format].compact.join("."))
		dst.binmode

		# The original used the following string construction, then removed whitespace ignoring 
		# the fact that the whitespace may be in a path
		# Instead we now construct the string normally.
		#command = <<-end_command
		#	#{ source_file_options }
		#	"#{ File.expand_path(src.path) }[0]"
		#	#{ transformation_command }
		#	"#{ File.expand_path(dst.path) }"
		#end_command
		srcpath = File.expand_path(src.path).gsub('$','\$')	# escape $, more chars may need to be added
		command = "#{ source_file_options } \"#{ srcpath }[0]\" #{ transformation_command } \"#{ File.expand_path(dst.path) }\""

		begin
			success = Paperclip.run("convert", command)		#.gsub(/\s+/, " "))
		rescue Paperclip::PaperclipCommandLineError
			raise Paperclip::PaperclipError, "There was an error processing the thumbnail for #{@basename}" if @whiny
		end

		dst
	end

	# returns true if succesful or false
	def make_custom(aDestpath)
		src = @file
		srcpath = File.expand_path(src.path).gsub('$','\$')	# escape $, more chars may need to be added
		tcmd = transformation_command.sub('-resize','-strip -colorspace rgb -thumbnail')
		command = "#{ source_file_options } \"#{ srcpath }[0]\" #{ tcmd } \"#{ File.expand_path(aDestpath) }\""

		success = false
		begin
			success = (Paperclip.run("convert", command)=='')	# assuming output always mean failure
		rescue Paperclip::PaperclipCommandLineError
			raise Paperclip::PaperclipError, "There was an error processing the thumbnail for #{@basename}" if @whiny
		end
		success
	end

end

# END Paperclip 2.3.1.1 fixes for funky filenames

module Buzzcore
	module ImageUtils

		module_function # this makes these methods callable as BcmsTools::PageHelper.method

		def image_file_dimensions(aFilename)
			if geomImage = Paperclip::Geometry.from_file(aFilename)
				return geomImage.width,geomImage.height
			else
				return nil,nil
			end
		end

		#	see http://www.imagemagick.org/script/command-line-processing.php#geometry
		#
		#	scale%						Height and width both scaled by specified percentage.
		#	scale-x%xscale-y%	Height and width individually scaled by specified percentages. (Only one % symbol needed.)
		#	width							Width given, height automagically selected to preserve aspect ratio.
		#	xheight						Height given, width automagically selected to preserve aspect ratio.
		#	widthxheight				Maximum values of height and width given, aspect ratio preserved.
		#	widthxheight^			Minimum values of width and height given, aspect ratio preserved.
		#	widthxheight!			Width and height emphatically given, original aspect ratio ignored.
		#	widthxheight>			Change as per widthxheight but only if an image dimension exceeds a specified dimension.
		#	widthxheight<			Change dimensions only if both image dimensions exceed specified dimensions.
		#	area@							Resize image to have specified area in pixels. Aspect ratio is preserved.

		THUMBNAIL_NAMINGS = {}	# store naming methods eg :iarts => Proc {|aSource,aDestFolder,aBaseUrl,aWidth,aHeight,aOptions| ... } NYI

		# resizing :
		#		to_width,to_height	: 	supply aWidth or aHeight and leave other as nil	(width or xheight)
		#		no_change						:		aWidth and aHeight as nil (original WidthxHeight)
		#		fit									:		aOptions[:resize_mode] = :fit, maintain aspect, one axis short (default, no modifier)
		#		fit_padded					:		aOptions[:resize_mode] = :fit_padded, maintain aspect, fill missing area with aOptions[:background_color] (not yet supported)
		#		stretch							:		aOptions[:resize_mode] = :stretch, (! modifier)
		#		cropfill						:		aOptions[:resize_mode] = :cropfill (Paperclip adds # modifier)

		# naming options :
		# supply a block : return a name given the original parameters (possibly slightly modified)
		# aOptions[:name] is a string : just return this value
		# aOptions[:name] is a Proc : call this with the original parameters (possibly slightly modified)

		# aOptions :
		# 	:resize_mode 	:	see above
		#		:name					: see above
		#		:return_details		: returns details hash instead of url. :src contains value normally returned
		# returns the resulting url
		def render_thumbnail(
			aSource,			# source file
			aDestFolder,	# folder to put new file in
			aBaseUrl,			# equivalent URL for aDestFolder
			aWidth,				# width (nil means auto)
			aHeight,				# height (nil means auto)
			aOptions = nil
		)
			src = ''
			aOptions ||= {}
			if aOptions[:return_details]
				details = {
					:aSource => aSource,
					:aDestFolder => aDestFolder,
					:aBaseUrl => aBaseUrl,
					:aWidth => aWidth,
					:aHeight => aHeight,
					:aOptions => aOptions,
				}
			else
				details = {}
			end
			if aSource 
				begin
					RAILS_DEFAULT_LOGGER.debug 'render_thumbnail: aSource='+aSource
					aOptions ||= {}
					aOptions[:resize_mode] ||= :fit
					
					throw RuntimeError.new("file doesn't exist #{aSource}") unless File.exists? aSource
					extThumb = 'jpg'	#MiscUtils.file_extension(File.basename(aSource),false).downcase
					throw RuntimeError.new("could not get file geometry #{aSource}") unless geomImage = Paperclip::Geometry.from_file(aSource)
	
					if aWidth || aHeight
						w,h = aWidth,aHeight
					else
						w,h = geomImage.width,geomImage.height		# w,h will never be nil,nil
					end
	
					resize_spec = "#{w.to_s}#{h ? 'x'+h.to_s : ''}"
					resize_mod = ''	# aOptions[:resize_mode]==:fit
					resize_mod = '#' if aOptions[:resize_mode]==:cropfill
					resize_mod = '!' if aOptions[:resize_mode]==:stretch
					resize_char = case aOptions[:resize_mode]
						when :cropfill: 'C'
						when :stretch: 'S'
						else 'F'
					end
	
					if block_given?
						nameThumb = yield(aSource,aDestFolder,aBaseUrl,aWidth,aHeight,aOptions)
					elsif aOptions[:name].is_a?(String)
						nameThumb = aOptions[:name]
					elsif aOptions[:name].is_a?(Proc)
						nameThumb = aOptions[:name].call(aSource,aDestFolder,aBaseUrl,aWidth,aHeight,aOptions)
					else
						# default naming
						nameThumb = MiscUtils.file_no_extension(File.basename(aSource),false)
						nameThumb = nameThumb.urlize unless aOptions[:urlize]==false
						nameThumb += '-' unless nameThumb.ends_with?('-')
						nameThumb += resize_spec+resize_char+'.'+extThumb
					end
					pathThumb = File.join(aDestFolder,nameThumb)
	
					if !File.exists?(pathThumb)
						throw RuntimeError.new("Failed reading image #{aSource}") unless objThumb = Paperclip::Thumbnail.new(File.new(aSource), :geometry => resize_spec+resize_mod, :format => :jpg, :convert_options => '-quality 85')
						objThumb.basename = MiscUtils.file_no_extension(nameThumb)
						RAILS_DEFAULT_LOGGER.debug 'render_thumbnail: generating '+pathThumb
						
						throw RuntimeError.new("Failed making thumbnail #{aSource}") unless objThumb.make_custom(pathThumb)
						FileUtils.chmod(0644,pathThumb)
					else
						RAILS_DEFAULT_LOGGER.debug 'render_thumbnail: using cached '+pathThumb
					end
					src = File.join(aBaseUrl,nameThumb)
					details.merge!({
						:geomImage => geomImage,
						:w => w,
						:h => h,
						:nameThumb => nameThumb,
						:pathThumb => pathThumb,
						:objThumb => objThumb
					}) if aOptions[:return_details]
				rescue Exception => e
					RAILS_DEFAULT_LOGGER.warn "thumberize_img error: #{e.inspect}"
					RAILS_DEFAULT_LOGGER.debug e.backtrace
					src = ''
				end
			end
			details[:src] = src
			return aOptions[:return_details] ? details : src
		end

	end
end

module BcmsTools
	module Thumbnails
			
		def self.thumbnail_name_from_attachment(aAttachment,aWidth,aHeight)
			extThumb = 'jpg' #aAttachment.file_extension
			size = "#{aWidth.to_s}x#{aHeight.to_s}"
			result = MiscUtils.file_no_extension(aAttachment.file_path).bite('/').gsub('/','--')+'-'+aAttachment.file_location[-4,4]+'-'
			result += if aWidth && aHeight
				size+'.'+extThumb
			else
				'*'
			end
			result
		end
		
		def self.thumbnail_path_from_attachment(aAttachment,aWidth,aHeight)
			File.join(APP_CONFIG[:thumbs_cache],thumbnail_name_from_attachment(aAttachment,aWidth,aHeight))
		end
		
		def self.remove_attachment_thumbnails(aAttachment)
			nameThumb = thumbnail_name_from_attachment(aAttachment,nil,nil)		
			pathThumbWildcard = File.join(APP_CONFIG[:thumbs_cache],nameThumb)
			FileUtils.rm(Dir.glob(pathThumbWildcard))
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
		
		# Scale given aWidth,aHeight up to fit within aDestWidth,aDestHeight
		# return original width and height if nil given for both aDestWidth & aDestHeight
		# If either aDestWidth or aDestHeight are nil, it will scale to fit the other dimension
		# If both are non-nil, the maximum scaled size that will fit inside the given width and height will be returned.
		def self.scale_to_fit(aWidth,aHeight,aDestWidth,aDestHeight)
			if aDestWidth.nil? && aDestHeight.nil?
				ratio = 1
			else
				wRatio = aDestWidth && (aDestWidth / aWidth)
				hRatio = (aDestHeight.nil? ? wRatio : (aDestHeight / aHeight))
				wRatio ||= hRatio
				ratio = Math.min(wRatio,hRatio)
			end
			return aWidth*ratio,aHeight*ratio
		end
		
	end
	
	module PageHelper
	
		module_function # this makes these methods callable as BcmsTools::PageHelper.method

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
				return img = framed_attachment_img(att,aWidth,aHeight,img)
			
				#img = XmlUtils.quick_set_att(img,'src',src)		# File.join(APP_CONFIG[:thumbs_url],nameThumb))
				#return HtmlUtils.fixed_frame_image(img,aWidth,aHeight,aDestWidth,aDestHeight)
			rescue Exception => e
				RAILS_DEFAULT_LOGGER.warn "thumberize_img error: #{e.inspect}"
				RAILS_DEFAULT_LOGGER.debug e.backtrace      
				return img
			end
		end
		
		def shellescape(str)
			# An empty argument will be skipped, so return empty quotes.
			return "''" if str.empty?
	
			str = str.dup
	
			# Process as a single byte sequence because not all shell
			# implementations are multibyte aware.
			str.gsub!(/([^A-Za-z0-9_\-.,:\/@\n])/n, "\\\\\\1")
	
			# A LF cannot be escaped with a backslash because a backslash + LF
			# combo is regarded as line continuation and simply ignored.
			str.gsub!(/\n/, "'\n'")
	
			return str
		end
		
		def shellescape2(aString)
			result = shellescape(aString)
			result.gsub!('\\','\\\\\\')
		end
		
		
		# resizes and crops to fill given size completely, probably losing part of the image
		def attachment_cropped_src(aAttachment,aWidth,aHeight)
			return '' if !aAttachment || !aAttachment.file_location

			Buzzcore::ImageUtils.render_thumbnail(
				aAttachment.full_file_location,
				APP_CONFIG[:thumbs_cache],
				APP_CONFIG[:thumbs_url],
				aWidth,
				aHeight,
				{
					:name => BcmsTools::Thumbnails::thumbnail_name_from_attachment(aAttachment,aWidth,aHeight),
					:resize_mode => :cropfill
				}
			)

		end
		
		# fits entire image within available space, maintaining aspect, probably not filling the space
		def attachment_max_src(aAttachment,aWidth,aHeight)
			return '' if !aAttachment
			Buzzcore::ImageUtils.render_thumbnail(
				aAttachment.full_file_location,
				APP_CONFIG[:thumbs_cache],
				APP_CONFIG[:thumbs_url],
				aWidth,
				aHeight,
				{
					:name => BcmsTools::Thumbnails::thumbnail_name_from_attachment(aAttachment,aWidth,aHeight),
					:resize_mode => :fit
				}
			)
		end

		def image_max_src(aImagePath,aWidth,aHeight)
			Buzzcore::ImageUtils.render_thumbnail(
				aImagePath,
				APP_CONFIG[:thumbs_cache],
				APP_CONFIG[:thumbs_url],
				aWidth,
				aHeight
			)
		end			
		
		def framed_attachment_img(aAttachment,aWidth,aHeight,aImg=nil)
			return '' if !aAttachment
			begin
				details = Buzzcore::ImageUtils.render_thumbnail(
					aAttachment.full_file_location,
					APP_CONFIG[:thumbs_cache],
					APP_CONFIG[:thumbs_url],
					aWidth,
					aHeight,
					{
						:return_details => true,
						:name => BcmsTools::Thumbnails::thumbnail_name_from_attachment(aAttachment,aWidth,aHeight)
					}
				)
				
				if details[:pathThumb]
					dw,dh = Buzzcore::ImageUtils.image_file_dimensions(details[:pathThumb])	# might be able to optimize using details[:objThumb]
				else
					dw,dh = aWidth,aHeight
				end
				aImg ||= "<img width=\"#{dw}\" height=\"#{dh}\" />"
				aImg = XmlUtils.quick_set_att(aImg,'src',details[:src])
				return HtmlUtils.fixed_frame_image(aImg,aWidth,aHeight,dw,dh)
			rescue Exception => e
				RAILS_DEFAULT_LOGGER.warn "thumberize_img error: #{e.inspect}"
				RAILS_DEFAULT_LOGGER.debug e.backtrace
				return ''
			end
		end

	end
end
