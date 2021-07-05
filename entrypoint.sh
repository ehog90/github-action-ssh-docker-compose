#!/usb/bin/env bash
set -e

log() {
  echo ">> [local]" $@
}

uuid()
{
    local N B T

    for (( N=0; N < 16; ++N ))
    do
        B=$(( $RANDOM%255 ))

        if (( N == 6 ))
        then
            printf '4%x' $(( B%15 ))
        elif (( N == 8 ))
        then
            local C='89ab'
            printf '%c%x' ${C:$(( $RANDOM%${#C} )):1} $(( B%15 ))
        else
            printf '%02x' $B
        fi

        for T in 3 5 7 9
        do
            if (( T == N ))
            then
                printf '-'
                break
            fi
        done
    done
}

WORKSPACE_ID=`uuid`
WORKSPACE_NAME=GITHUBWS_$WORKSPACE_ID

cleanup() {
  set +e
  log "Killing ssh agent."
  ssh-agent -k
  log "Removing workspace archive."
  rm -f /tmp/$WORKSPACE_NAME
.tar.bz2
}
trap cleanup EXIT

log "Packing workspace into archive to transfer onto remote machine. Individual Workspace ID: $WORKSPACE_NAME
tar cjvf /tmp/$WORKSPACE_NAME.tar.bz2 --exclude .git .

log "Launching ssh agent."
eval `ssh-agent -s`

ssh-add <(echo "$SSH_PRIVATE_KEY")

remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() { log 'Removing workspace...'; rm -rf \"\$HOME/$WORKSPACE_NAME\" ; } ; log 'Creating workspace directory...' ; mkdir \"\$HOME/$WORKSPACE_NAME\" ; trap cleanup EXIT ; log 'Unpacking workspace...' ; tar -C \"\$HOME/$WORKSPACE_NAME\" -xjv ; log 'Launching docker-compose...' ; cd \"\$HOME/$WORKSPACE_NAME\" ; docker-compose -f \"$DOCKER_COMPOSE_FILENAME\" -p \"$DOCKER_COMPOSE_PREFIX\" up -d --build"

echo ">> [local] Connecting to remote host."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  "$remote_command" \
  < /tmp/$WORKSPACE_NAME \
.tar.bz2
