module ActionView
  module Helpers
	
		def default_content_for(name, &block)
			name = name.kind_of?(Symbol) ? ":#{name}" : name
			out = eval("yield #{name}", block.binding)
			concat(out || capture(&block), block.binding)
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


