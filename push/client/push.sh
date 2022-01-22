#!/bin/bash

# PUSH型バックアップ
# reverse modeで暗号化したディレクトリをrsyncでバックアップサーバに送る

# メリット
# - PUSH型なのでバックアップサーバさえ常時稼働していればバックアップしやすい
# - バックアップサーバではバックアップ内容を見られない
# - ファイル転送にrsyncを使えるため高速

# デメリット
# - 全てのバックアップ対象にスクリプトを置く必要がある
# - rsyncのfilterを使うためにplaintextnames

# 事前にやること
# - reverse modeで暗号化(パスワードはバックアップ対象に置かない)
#   sudo gocryptfs -init -reverse -plaintextnames -passfile <(echo "$PASSWD") /


usage() {
    echo "Push backup tool"
    echo "Usage: backup.sh [OPTION...]"
    echo
    echo "-s DIR --source DIR   source directory"
    echo "-r HOST --remote HOST   remote host"
    echo "-l HOST --local HOST   local host"
    echo "-m MODULE --module MODULE     rsync module"
    echo "-f FILE --filter FILE   filterfs file"
    echo "-k FILE -key FILE      ssh identity file (id_rsa)"
    echo "-p FILE --passfile      gocryptfs password file"
    echo "-n --dry-run"
    echo "-v --verbose"
}

# default values
SOURCE=/
LOCAL_HOST=$HOSTNAME
REMOTE_MODULE=$LOCAL_HOST

while true; do
    case "$1" in
        -s | --source )
            if [[ ! $2 ]];then
                echo "Invalid source"
                exit 1
            fi
            SOURCE=$2
            shift 2;;
        -r | --remote )
            if [[ ! $2 ]];then
                echo "Invalid remote host"
                exit 1
            fi
            REMOTE_HOST=$2
            shift 2;;
        -l | --local )
            if [[ ! $2 ]];then
                echo "Invalid local host"
                exit 1
            fi
            LOCAL_HOST=$2
            shift 2;;
        -m | --module )
            if [[ ! $2 ]];then
                echo "Invalid remote module"
                exit 1
            fi
            REMOTE_MODULE=$2
            shift 2;;
        -f | --filter )
            if [[ ! -f $2 ]];then
                exit 1
            fi
            FILTER_FILE="$2"
            shift 2;;
        -k | --key )
            if [[ ! $2 ]];then
                exit 1
            fi
            IDENTITY_FILE="$2"
            shift 2;;
        -p | --passfile )
            if [[ ! $2 ]];then
                exit 1
            fi
            PASSFILE="$2"
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

if [[ ! $PASSFILE ]] || [[ ! $LOCAL_HOST ]] || [[ ! $REMOTE_HOST ]] || [[ ! $REMOTE_MODULE ]] || [[ ! $FILTER_FILE ]];then
    usage
    exit 1
fi

DEST_ROOT=$REMOTE_HOST::$REMOTE_MODULE

FILTER_ROOT=$(mktemp -d)
CRYPT_ROOT=$(mktemp -d)
echo "FILTER_ROOT: $FILTER_ROOT"
echo "CRYPT_ROOT: $CRYPT_ROOT"

SSH_COMMAND="ssh -i $IDENTITY_FILE"

# reverse modeで暗号化Viewを取得
filterfs --filter $FILTER_FILE --source $SOURCE $FILTER_ROOT
gocryptfs -q -passfile $PASSFILE -reverse -ro $FILTER_ROOT $CRYPT_ROOT

# バックアップ容量を抑えるために`--link-dest`を使う
# dry-runでバックアップ一覧を取得
LINK_DEST_DIR=$(rsync --out-format="%n" -n -a -e "$SSH_COMMAND" \
    --include="/*/" --exclude="*" $DEST_ROOT $(mktemp -d --dry-run) \
    | grep -v '\./' | sort | tail -1)
echo "LINK_DEST_DIR: $LINK_DEST_DIR"

# バックアップ実行
rsync -ah --numeric-ids --delete --delete-excluded --info=progress2,stats ${DRY_RUN:+-n} ${VERBOSE:+-v} \
        ${LINK_DEST_DIR:+--link-dest=/$LINK_DEST_DIR} \
        -e "$SSH_COMMAND" \
        $CRYPT_ROOT/ $DEST_ROOT/$(date -Iseconds)@$LOCAL_HOST

# 片付け
fusermount -u $FILTER_ROOT
fusermount -u $CRYPT_ROOT
