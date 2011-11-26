# Copyright (c) 2009-2011 by Ewout Vonk. All rights reserved.

Capistrano::Configuration.instance(:must_exist).load do 
  namespace :edeprec do
    namespace :imagemagick_src do

      SRC_PACKAGES[:imagemagick] = {
        :md5sum => "46c3e5aa967dcd821bd8de1904ecba52  ImageMagick-6.5.9-10.tar.gz",  
        :url => "ftp://ftp.imagemagick.org/pub/ImageMagick/ImageMagick-6.5.9-10.tar.gz",
        :configure => "./configure --prefix=/usr ;"
      }
      
      set :imagemagick_include_rmagick, false
      
      desc "Install imagemagick & rmagick"
      task :install, :roles => :app do
        # make sure there is no binary package (force uninstall), since we install in the same location
        top.deprec.imagemagick_bin.uninstall
        install_deps
        deprec2.download_src(SRC_PACKAGES[:imagemagick], src_dir)
        deprec2.install_from_src(SRC_PACKAGES[:imagemagick], src_dir)
        sudo "ldconfig"
        gem2.install 'rmagick' if imagemagick_include_rmagick
      end

      task :uninstall, :roles => :app do
        gem2.uninstall 'rmagick' if imagemagick_include_rmagick
        package_dir = File.join(src_dir, File.basename(SRC_PACKAGES[:imagemagick][:url]).sub(/(\.tgz|\.tar\.gz)/,''))
        sudo "sh -c 'cd #{package_dir} ; make uninstall || true'"
      end

      task :install_deps, :roles => :app do
        # install binary packages, so all needed dependencies are installed
        apt.install( {:base => %w(imagemagick libmagick9-dev libperl-dev libmagick10)}, :stable )
        # remove binary packages, leaving the dependencies, so we can install from src without needing all deps from
        # source as well
        apt.install( {:base => %w(imagemagick- libmagick9-dev- libmagick10-)}, :stable )
      end

    end
  end
end