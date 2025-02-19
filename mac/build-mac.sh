#!/bin/bash


# setup global state
MAC_ROOT=$( cd "$(dirname "$0")" ; pwd -P ) # The absolute path to this files parent
PROJECT_ROOT=$( cd $MAC_ROOT/.. ; pwd -P ) # The absolute path to ginkou-flatpak
TEMPLATE=$MAC_ROOT/template.app
RES=$MAC_ROOT/ginkou.app/Contents/MacOS/res # The absolue path to the (yet to be created) ginkou.app
ARTIFACTS=$MAC_ROOT/artifacts
TMP=$MAC_ROOT/tmp
# each of these functions depends on global state 

# the install functions build and install the artifacts into $ARTIFACTS

install_ginkou_loader () {
    echo "Starting Rust installation"
    cargo install --locked --path $PROJECT_ROOT/ginkou-loader --root $TMP
    mv $TMP/bin/ginkou-loader $ARTIFACTS
    echo =======================


}


install_melwalletd () {
    cargo install --locked --path $PROJECT_ROOT/melwalletd --root $TMP
    mv $TMP/bin/melwalletd $ARTIFACTS
    echo =======================

}



install_ginkou () {

    echo "Building ginkou"

    pushd $TMP
        git clone $PROJECT_ROOT/ginkou 
        cd ginkou
        npm install
        npm run build
        rm -rf $ARTIFACTS/ginkou-public
        mv public $ARTIFACTS/ginkou-public
    popd

}

# clean up any old app, clone the temp app, and copy the artifacts to $RES
build_app (){
    
    pushd $MAC_ROOT

        rm -rf ginkou.app
        cp -r $TEMPLATE ginkou.app
        mkdir -p $RES
        cp -r $ARTIFACTS/* $RES

        # build_dmg assumes this exists
        rm -rf dmg_setup
        mkdir dmg_setup
        mv ginkou.app dmg_setup

        # add a sym link to applications into which users may drag ginkou.app
        cd dmg_setup
        ln -s /Applications
    popd

}

build_dmg () {
# setup a directory containing ginkou.app
    pushd $MAC_ROOT         

        cd $MAC_ROOT
        [[ -f mellis.dmg ]] && mv mellis.dmg mellis.dmg-`date +%s` # store old dmg unobtrusively
        create-dmg mellis.dmg dmg_setup # build new dmg

        # delete artifacts
        rm -rf dmg_setup
        rm -rf $RES/tmp
    popd



}


_GINKOU_LOADER=0
_MELWALLETD=0
_GINKOU=0
_APP=0
_DMG=0



# if any argument is specified then only that build process is run
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -gl|--ginkou-loader) 
            _GINKOU_LOADER=1
            shift ;;
        -mwd|--melwalletd) 
            _MELWALLETD=1
            shift ;;
        -g|--ginkou)
            _GINKOU=1
            shift ;;
        -A|--app)
            _APP=1
            shift ;;
        -D|--dmg)
            _DMG=1
            shift;;

        --clean)
            rm -rf $ARTIFACTS
            shift;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
done


set -ex

[[ ! -d $ARTIFACTS ]] && mkdir $ARTIFACTS
ls
# test ! `which create-dmg` && brew install create-dmg

rm -rf $TMP
mkdir $TMP

if (($_GINKOU_LOADER + $_MELWALLETD + $_GINKOU + $_APP + $_DMG < 1)); then  
    install_ginkou_loader   
    install_melwalletd
    install_ginkou
    build_app
    build_dmg
fi;

(( $_GINKOU_LOADER > 0 )) && install_ginkou_loader
(( $_MELWALLETD > 0 )) && install_melwalletd
(( $_GINKOU > 0 )) && install_ginkou
rm -rf $TMP
(( $_APP > 0 )) && build_app
(( $_DMG > 0 )) && build_dmg 

echo "DONE"