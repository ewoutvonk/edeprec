# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :hardy do
    namespace :rvm do
      
      RVM_UBUNTU_HARDY_DEPS = {
        :mri_ree => %w(libreadline5 libreadline-dev libxslt1-dev),
      }
      
      desc "Install Rvm"
      task :install do
        install_deps
        top.ubuntu.rvm.install
      end
      
      task :install_deps do
        apt.install( {:base => convert_rubies_to_deps(RVM_UBUNTU_DEPS, RVM_UBUNTU_HARDY_DEPS) }, :stable )
      end
      
      desc "Set project rvmrcs"
      task :set_project_rvmrcs do
        top.ubuntu.rvm.set_project_rvmrcs
      end
      
      desc "install selected rubies with rvm"
      task :install_rubies do
        top.ubuntu.rvm.install_rubies
      end
      
      desc "Set default ruby"
      task :set_default_ruby do
        top.ubuntu.rvm.set_default_ruby
      end
      
    end
  end
end