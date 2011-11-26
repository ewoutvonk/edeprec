# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :ubuntu do 
    namespace :git do
      
      SRC_PACKAGES[:git] = {
        :md5sum => '7cfb3e7ea585037272a7ad8e35f4ac0a  git-1.7.7.1.tar.gz',
        :filename => 'git-1.7.7.1.tar.gz',
        :dir => 'git-1.7.7.1',
        :url => "http://git-core.googlecode.com/files/git-1.7.7.1.tar.gz",
        :unpack => "tar zxf git-1.7.7.1.tar.gz;",
        :configure => %w(
          ./configure --without-tcltk
          ;
          ).reject{|arg| arg.match '#'}.join(' '),
        :make => 'make;',
        :install => 'make install;'
      }
      
      desc "install git"
      task :install, :roles => :sphinx do
        install_deps
        deprec2.download_src(SRC_PACKAGES[:git], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:git], src_dir)
      end
      
      task :install_deps, :roles => :app do
        apt.install( {:base => %w(zlib1g-dev)}, :stable )
      end
    
    end 
  end
end