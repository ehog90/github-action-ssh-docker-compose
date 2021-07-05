#!/usb/bin/env bash
set -e

log() {
  echo ">> [local]" $@
}

cleanup() {
  set +e
  log "Killing ssh agent."
  ssh-agent -k
  log "Removing workspace archive."
  rm -f /tmp/${WORKSPACE_ID}.tar.bz2
}
trap cleanup EXIT

BUILD_ID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
WORKSPACE_ID=GITHUB_DOCKER_DEPLOYMENT_$BUILD_ID

log "Workspace ID is ${WORKSPACE_ID}."

log "Packing workspace into archive to transfer onto remote machine."
tar cjvf /tmp/${WORKSPACE_ID}.tar.bz2 --exclude .git .

log "Launching ssh agent."
eval `ssh-agent -s`

ssh-add <(echo "$SSH_PRIVATE_KEY")

remote_command="set -e ; log() { echo '>> [remote]' \$@ ; } ; cleanup() ; log 'Creating workspace directory for ${WORKSPACE_ID}...' ; mkdir \"\$HOME/${WORKSPACE_ID}\" ; trap cleanup EXIT ; log 'Unpacking ${WORKSPACE_ID}...' ; tar -C \"\$HOME/${WORKSPACE_ID}\" -xjv ; log 'Launching docker-compose...' ; cd \"\$HOME/${WORKSPACE_ID}\" ; docker-compose -f \"$DOCKER_COMPOSE_FILENAME\" -p \"$DOCKER_COMPOSE_PREFIX\" up -d --build"

echo ">> [local] Connecting to remote host."
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  "$SSH_USER@$SSH_HOST" -p "$SSH_PORT" \
  "$remote_command" \
  < /tmp/${WORKSPACE_ID}.tar.bz2
