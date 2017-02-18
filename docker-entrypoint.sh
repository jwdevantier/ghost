#!/bin/bash
set -e

# Allow overriding the UID/GID used for the user which hosts the ghost CMS software.
# This allows a user of this image to modify the ghost content files without
# root permissions or mucking with chown/chgrp
USER_ID=${USER_ID:-1000}
GROUP_ID=${GROUP_ID:-1000}

# Note, the base image on which this relies seems to create a user
# with UID 1000 and a group with GID 1000 already, the code below
# checks for the existence of a user/group of using the specified UID/GID
# and if so, uses these (if not, it'll make the user/group on the fly)

GROUP_NAME=`getent group ${GROUP_ID}| cut -f 3 -d :`
if [[ -z "$GROUP_NAME" ]]; then
    groupadd -g ${GROUP_ID} user
    GROUP_NAME="user"
fi

USER_NAME=`getent passwd 1000| cut -f 1 -d :`
if [[ -z "${USER_NAME}" ]]; then
    useradd --create-home --home-dir /home/user -g ${GROUP_NAME} -u ${USER_ID} user
    USER_NAME="user"
fi

# finally, change ownership of the ghost source dir
chown -R ${USER_NAME}:${GROUP_NAME} ${GHOST_SOURCE}
chown -R ${USER_NAME}:${GROUP_NAME} /var/lib/ghost

# allow the container to be started with `--user`
if [[ "$*" == npm*start* ]] && [ "$(id -u)" = '0' ]; then
    chown -R ${USER_NAME} "$GHOST_CONTENT"
    exec gosu ${USER_NAME} "$BASH_SOURCE" "$@"
fi

if [[ "$*" == npm*start* ]]; then
	baseDir="$GHOST_SOURCE/content"
	for dir in "$baseDir"/*/ "$baseDir"/themes/*/; do
		targetDir="$GHOST_CONTENT/${dir#$baseDir/}"
		mkdir -p "$targetDir"
		if [ -z "$(ls -A "$targetDir")" ]; then
		    tar -c --one-file-system -C "$dir" . | tar xC "$targetDir"
		    chown -R ${USER_NAME}:${GROUP_NAME} $targetDir
		fi
	done

	if [ ! -e "$GHOST_CONTENT/config.js" ]; then
		sed -r '
			s/127\.0\.0\.1/0.0.0.0/g;
			s!path.join\(__dirname, (.)/content!path.join(process.env.GHOST_CONTENT, \1!g;
		' "$GHOST_SOURCE/config.example.js" > "$GHOST_CONTENT/config.js"
		chown -R ${USER_NAME}:${GROUP_NAME} "${GHOST_CONTENT}/config.js"
	fi
fi

exec "$@"
