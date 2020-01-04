
#must be sourced... as in:
#   . offset_flow.sh

export SR_DEV_APPNAME='sr-dynflow'

if [ ! -d ~/.config/sr-dynflow ]; then
    mkdir ~/.config/sr-dynflow
fi

cp ~/.config/sarra/credentials.conf ~/.config/sarra/default.conf ~/.config/sarra/admin.conf ~/.config/sr-dynflow
