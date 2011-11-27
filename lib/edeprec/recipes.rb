Dir.glob("#{File.dirname(__FILE__)}/edeprec/recipes/**/*.rb").collect do |filename|
  require filename
end
