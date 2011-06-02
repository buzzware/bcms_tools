Category.class_eval do

	def self.create_chain(
		aChain,		# an array of names from leaf to root
		aCatType		# an object or id of CategoryRoot
	)
		aCatType = CategoryType.find_by_id(aCatType) if aCatType.is_a? Fixnum
		parent = nil
		aChain.each do |name|
			currCat = Category.find_by_name(name) || aCatType.categories.create!(:name => name,:parent => parent)
			parent = currCat
		end
		parent
	end

end

