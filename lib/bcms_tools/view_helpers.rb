module ActionView
  module Helpers

		# makes these accessible via ActionView::Helpers.function
		module_function

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

		def mailto_a_friend(aSubject,aOptions={})
			<<-EOS
				<SCRIPT LANGUAGE="JavaScript">
				<!-- Begin

				//Script by Tronn: http://come.to/tronds
				//Submitted to JavaScript Kit (http://javascriptkit.com)
				//Visit http://javascriptkit.com for this script

				var initialsubj="#{aSubject}"
				var initialmsg="Hello! You may be interested in this : "+window.location+" \n \n \n"
				var good;
				function checkEmailAddress(field) {

				var goodEmail = field.value.match(/\b(^(\S+@).+((\.com)|(\.net)|(\.edu)|(\.mil)|(\.gov)|(\.org)|(\.info)|(\.sex)|(\.biz)|(\.aero)|(\.coop)|(\.museum)|(\.name)|(\.pro)|(\..{2,2}))$)\b/gi);
				if (goodEmail) {
				good = true;
				}
				else {
				alert('Please enter a valid address.');
				field.focus();
				field.select();
				good = false;
					 }
				}
				u = window.location;
				function mailThisUrl() {
				good = false
				checkEmailAddress(document.mailto_a_friend.email);
				if (good) {

				//window.location = "mailto:"+document.mailto_a_friend.email.value+"?subject="+initialsubj+"&body="+document.title+" "+u;
				window.location = "mailto:"+document.mailto_a_friend.email.value+"?subject="+initialsubj+"&body="+initialmsg
					 }
				}
				//  End -->
				</script>


				<form class="mailto_a_friend" name="mailto_a_friend">
				<input class="mailto_a_friend" type="text" name="email" size="26" value="Email Address Here" onFocus="this.value=''" onMouseOver="window.status='Enter email address here and tell a friend about this...'; return true" onMouseOut="window.status='';return true">
				<input class="mailto_a_friend" type="button" value="Email to a friend" onMouseOver="window.status='Enter email address above and click this to send an email to a friend!'; return true" onMouseOut="window.status='';return true" onClick="mailThisUrl();">
				</form>

			EOS
		end

		def default_content_for(name, &block)
			name = name.kind_of?(Symbol) ? ":#{name}" : name
			out = eval("yield #{name}", block.binding)
			concat(out || capture(&block))
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
			top_section = ancestors[opts[:from_top].to_i]
			return '' unless top_section
			opts[:path] = top_section.path

			ancestors << selected_page if (selected_page.section == top_section) || (selected_page != selected_page.section.pages.first)

			result_i = Math.min(opts[:from_top] + opts[:depth],ancestors.length-1)
			opts[:page] = ancestors[result_i]
      opts[:items] ||= menu_items(opts)

			return '' if opts[:items].empty? || (opts[:items].length == 1 && !opts[:items].first[:children])	# return blank if only a single menu item

			render_menu opts
		end

		# Construct tree_nodes, an array of arrays - each array a level in tree.
		# Each level is a list children to the parents in the level before
		def construct_category_tree(aRootCategory)
			level_nodes = case aRootCategory
				when String
					[Category.find_by_name(aRootCategory)]
				when Category
					[aRootCategory]
				when CategoryType
					[aRootCategory.categories.top_level]
				else
					CategoryType.first.categories.top_level
			end
			tree_nodes = []
			begin
				tree_nodes << level_nodes
				ids = level_nodes.map {|n| n.id}
				level_nodes = Category.find_all_by_parent_id(ids)  #Category.all({:conditions => ['parent_id in (?)',ids.join(',')]})
			end while !level_nodes.empty?
			tree_nodes
		end

		# :base_url (String) : prepended to menu urls eg. /products
		# :category (String) : name of current category eg. 'Shoes'
		# :id_prefix (String) : will be prepended to ids of menu eg. 'section_'
		def category_menu_items(aRootCategory, aOptions={})
			aBaseUrl = (aOptions[:base_url] || '')
			aIdPrefix = (aOptions[:id_prefix] || '')
			category = aOptions[:category]
			category = category.name.urlize('+') if category.is_a?(Category)
			tree_nodes = construct_category_tree(aRootCategory)

			# now turn tree_nodes into menu items, still as array of levels
			tree_items = []
			last_lvl = nil
			tree_nodes.each do |lvl|
				item_level = []
				lvl.each do |node|
					name = (node.name.index('/') ? File.basename(node.name) : node.name)
					item = {:id => aIdPrefix+node.id.to_s, :name => name }
					item[:node] = node
					if last_lvl && parent_item = last_lvl.find {|i| i[:node].id == node.parent_id}
						parent_item[:children] ||= []
						parent_item[:children] << item
						item[:url] = parent_item[:url]
						item[:url] += '+' unless item[:url]=='' || item[:url].ends_with?('/') || item[:url].ends_with?('+')
						item[:url] += name.urlize('-')
					else
						item[:url] = File.join(aBaseUrl,name.urlize('-'))
					end

					item[:selected] = true if category && (category==node.name.urlize('+'))
					item[:order] = aOptions[:order_proc].call(item) if aOptions.has_key?(:order_proc)
					item_level << item
				end
				tree_items << item_level
				last_lvl = item_level
			end
			# clean
			tree_items.each do |lvl|
				lvl.each do |i|
					i.filter_include!([:url,:selected,:id,:name,:children,:order])
					i[:children].sort! {|a,b| a[:order].to_i <=> b[:order].to_i} if i[:children].is_a?(Array)
				end
			end
			tree_items.first.sort! {|a,b| a[:order].to_i <=> b[:order].to_i}
			tree_items.first
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


