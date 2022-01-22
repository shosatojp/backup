#!/bin/bash



usage() {
    echo "Push backup tool"
    echo "Usage: backup.sh [OPTION...]"
    echo
    echo "-d DIR --dest DIR   destination directory"
    echo "-r HOST --remote HOST   remote host"
    echo "-m MODULE --module MODULE     remote rsync module"
    echo "-k FILE -key FILE      ssh identity file (id_rsa)"
    echo "-n --dry-run"
    echo "-v --verbose"
}

# default values

while true; do
    case "$1" in
        -d | --dest )
            if [[ ! $2 ]];then
                echo "Invalid destination dir"
                exit 1
            fi
            DEST_ROOT=$2
            shift 2;;
        -r | --remote )
            if [[ ! $2 ]];then
                echo "Invalid remote host"
                exit 1
            fi
            REMOTE_HOST=$2
            shift 2;;
        -m | --module )
            if [[ ! $2 ]];then
                echo "Invalid remote module"
                exit 1
            fi
            REMOTE_MODULE=$2
            shift 2;;
        -k | --key )
            if [[ ! $2 ]];then
                exit 1
            fi
            IDENTITY_FILE="$2"
            shift 2;;
        -v | --verbose )
            VERBOSE=1
            shift;;
        -n | --dry-run )
            DRY_RUN=1
            shift;;
        -h | --help )
            usage
            exit 0
            ;;
        * ) 
            break;;
    esac
done

# find last modified (filename based) dir
LINK_DEST_DIR=$(find $DEST_ROOT -mindepth 1 -maxdepth 1 -type d | sort | tail -1)

rsync -e "ssh -i $IDENTITY_FILE" \
        -avh --delete --delete-excluded \
        ${LINK_DEST_DIR:+--link-dest=$LINK_DEST_DIR} \
        $REMOTE_HOST::$REMOTE_MODULE $DEST_ROOT/$(date -Iseconds)@$REMOTE_HOST
