# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do
    namespace :aspell do
      
      set :aspell_languages, [ :en, :fr, :de, :es ]
      
      desc "Install ASpell"
      task :install do
        install_deps
      end
      
      # Install dependencies for aspell
      task :install_deps do
        apt.install( {:base => %w(aspell libaspell-dev libaspell15)}, :stable )
        aspell_languages.each do |lang|
          apt.install( {:base => "aspell-#{lang}"}, :stable )
        end
      end
    end
  end
end