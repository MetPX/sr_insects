
#must be sourced... as in:
#   . offset_flow.sh


export SR_DEV_APPNAME='sr-staticflow'

if [ ! -d ~/.config/${SR_DEV_APPNAME} ]; then
    echo "mkdir  ~/.config/${SR_DEV_APPNAME}"
    mkdir ~/.config/${SR_DEV_APPNAME}
fi

cp ~/.config/sarra/credentials.conf ~/.config/sarra/default.conf ~/.config/sarra/admin.conf ~/.config/${SR_DEV_APPNAME}

if [ ! -d ~/.cache/${SR_DEV_APPNAME} ]; then
    echo "mkdir  ~/.cache/${SR_DEV_APPNAME}"
    mkdir ~/.cache/${SR_DEV_APPNAME}
fi

if [ ! -d ~/.cache/${SR_DEV_APPNAME}/log ]; then
    echo "mkdir  ~/.cache/${SR_DEV_APPNAME}/log"
    mkdir ~/.cache/${SR_DEV_APPNAME}/log
fi
