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

PATH=/Library/TeX/texbin:/usr/local/bin:$PATH
export PATH

if [ "$ACTION" = R ]; then
    fold_start inst.R 'Install system libraries and R'
    cd /tmp
    set -x
    echo ' - download TeX'
    curl -LO https://mac.R-project.org/misc/mactex-basictex-20191011.pkg
    echo ' - install TeX'
    sudo installer -pkg mactex-basictex-20191011.pkg -target /
    rm mactex-basictex-20191011.pkg
    sudo -i /Library/TeX/texbin/tlmgr install collection-latexrecommended collection-fontsrecommended
    echo ' - install inconsolata from CTAN'
    (cd /tmp
     curl -LO http://mirrors.ctan.org/install/fonts/inconsolata.tds.zip
     mkdir zi4
     cd zi4
     unzip -q ../inconsolata.tds.zip
     sudo chown -Rh 0:0 .
     sudo rsync -a ./ /usr/local/texlive/2019basic/texmf-dist/
     sudo rm -rf /tmp/zi4
    )
    sudo -i /Library/TeX/texbin/texhash
    sudo -i /Library/TeX/texbin/updmap-sys --enable Map=zi4.map

    echo ' - download R'
    curl -LO https://mac.R-project.org/high-sierra/R-4.0-branch/R-4.0-branch.pkg
    echo ' - install R'
    sudo installer -pkg R-4.0-branch.pkg -target /
    rm R-4.0-branch.pkg 

    echo ' - install libraries'
    ## for the test just few basic ones used by  Ritself
    for pkg in pkgconfig-0.28 xz-5.2.4; do #cairo-1.14.12 fontconfig-2.13.1 freetype-2.10.0 jpeg-9 pcre2-10.34 readline-5.2.14; do
	echo " - install $pkg"
	curl -sSLO https://mac.R-project.org/libs-4/${pkg}-darwin.17-x86_64.tar.gz | sudo tar fxz - -C /
    done
    set +x
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

if [ "$ACTION" = deps ]; then
    fold_start pkg.deps "Installing package dependencies ..."
    cd $HOME
    tar=`cat ~/PACKAGE`
    set -x
    mkdir -p src/contrib
    cp -p $tar src/contrib/
    Rscript -e "pkg=rownames(available.packages(repos='file:///$HOME',type='source')); install.packages(pkg, repos=c('https://cloud.R-project.org','file:///$HOME'), dependencies=c('Depends','Imports','LinkingTo','Enhances'))"
    fold_end pkg.deps
fi

if [ "$ACTION" = check ]; then
    fold_start pkg.check "Checking package ..."
    cd $HOME
    tar=`cat ~/PACKAGE`
    set -x
    R CMD check --as-cran $tar
    set +x
    fold_end pkg.check
fi

if [ "$ACTION" = binary ]; then
    fold_start pkg.binary "Creating binary ..."
    cd $HOME
    tar=`cat ~/PACKAGE`
    set -x
    R CMD INSTALL --build $tar
    set +x
    ls -l *.tgz
    fold_end pkg.binary
fi
