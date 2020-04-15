#!/bin/bash

# bail out on any error
set -e

ACTION="$1"
OS=`uname -s`

fold_start() {
  echo -e "travis_fold:start:$1\033[33;1m$2\033[0m"
}

fold_end() {
  echo -e "\ntravis_fold:end:$1\r"
}

SRC="`pwd`"

if [ "$ACTION" = R ]; then
    fold_start inst.R 'Install system libraries and R'
    cd /tmp
    echo ' - download TeX'
    curl -sSLO https://mac.R-project.org/misc/mactex-basictex-20191011.pkg
    echo ' - install TeX'
    sudo installer -pkg mactex-basictex-20191011.pkg -target /
    rm mactex-basictex-20191011.pkg
    echo ' - download R'
    curl -sSLO https://mac.R-project.org/high-sierra/R-4.0-branch/R-4.0-branch.pkg
    echo ' - install R'
    sudo installer -pkg R-4.0-branch.pkg -target /
    rm R-4.0-branch.pkg 
    echo ' - install libraries'
    ## for the test just few basic ones used by  Ritself
    for pkg in pkgconfig-0.28 xz-5.2.4; do #cairo-1.14.12 fontconfig-2.13.1 freetype-2.10.0 jpeg-9 pcre2-10.34 readline-5.2.14; do
	echo " - install $pkg"
	curl -sSLO https://mac.R-project.org/libs-4/${pkg}-darwin.17-x86_64.tar.gz | sudo tar fxz - -C /
    done
    fold_end int.R
fi

if [ "$ACTION" = build ]; then
    fold_start pkg.build "Building package ..."
    rm -f *_*.tar.gz
    R CMD build .
    ls *_*.tar.gz > ~/PACKAGE
    tar=`cat ~/PACKAGE`
    mv *_*.tar.gz ~/
    if [ -e ~/$tar ]; then
	echo " $tar built"
    else
	echo "*** Cannot find $tar !"
	exit 1
    fi
    fold_end pkg.build
fi

if [ "$ACTION" = check ]; then
    fold_start pkg.check "Checking package ..."
    cd $HOME
    tar=`cat ~/PACKAGE`
    R CMD check --as-cran $tar
    fold_end pkg.check
fi
