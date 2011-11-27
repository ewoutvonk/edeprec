Dir.glob("#{File.dirname(__FILE__)}/edeprec/unmaintained/recipes/**/*.rb").collect do |filename|
  require filename
end
