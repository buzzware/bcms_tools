module ActionView
  module Helpers
	
		def google_analytics(aTrackingId = nil)
			return '' if request.host.begins_with?('cms.')
			aTrackingId ||= APP_CONFIG[:google_analytics_tracking_id]
			return '' unless aTrackingId.to_nil

			<<-EOS
				<script type="text/javascript">
				var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");
				document.write(unescape("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));
				</script>
				<script type="text/javascript">
				try {
				var pageTracker = _gat._getTracker("#{aTrackingId}");
				pageTracker._trackPageview();
				} catch(err) {}
				</script>
			EOS
		end

		def default_content_for(name, &block)
			name = name.kind_of?(Symbol) ? ":#{name}" : name
			out = eval("yield #{name}", block.binding)
			concat(out || capture(&block), block.binding)
		end

		#render_menu(), or more precisely menu_items() doesn't seem to work well
		#for rendering a top menu when you want the ancestor item of the current
		#page highlighted. The problem is that it compares each menu item with the
		#current page, when the current page may be several levels deep under one
		#of the menu items.
		#
		#Fortunately the :page option allows the current page to be given, so the
		#correct output can be produced if we manipulate this option.
		#
		#This does the trick :
		#
		def render_menu2(aOptions=nil)
			opts = {
				:from_top => 0,	# menu root is how many levels down from root (0 = roots immediate children)
				:depth => 1,		# depth of menu from menu root
				:show_all_siblings => true
			}
			opts.merge!(aOptions) if aOptions

      selected_page = opts[:page] || @page
			ancestors = selected_page.ancestors
			top_section = ancestors[opts[:from_top]]
			opts[:path] = top_section.path
			
			ancestors << selected_page if (selected_page.section == top_section) || (selected_page != selected_page.section.pages.first)
			
			result_i = Math.min(opts[:from_top] + opts[:depth],ancestors.length-1)
			opts[:page] = ancestors[result_i]
      opts[:items] ||= menu_items(opts)

			return '' if opts[:items].empty? || (opts[:items].length == 1 && !opts[:items].first[:children])	# return blank if only a single menu item
			
			render_menu opts
		end

    module CaptureHelper
      def set_content_for(name, content = nil, &block)
        ivar = "@content_for_#{name}"
        instance_variable_set(ivar, nil)
        content_for(name, content, &block)
      end
    end
  end
end


