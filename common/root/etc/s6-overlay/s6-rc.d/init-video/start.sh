#!/usr/bin/env bash
# sourced from: https://github.com/linuxserver/docker-baseimage-kasmvnc/blob/master/root/etc/s6-overlay/s6-rc.d/init-video/run

FILES=$(find /dev/dri /dev/dvb -type c -print 2>/dev/null)

echo "Checking video permissions for user ${USER} with uid ${UID}"

for i in $FILES; do
	VIDEO_GID=$(stat -c '%g' "${i}")
	VIDEO_UID=$(stat -c '%u' "${i}")
	# check if user matches device
	if id -u "${USER}" | grep -qw "${VIDEO_UID}"; then
		echo "  permissions for ${i} are good" >/dev/null
	else
		# check if group matches and that device has group rw
		if id -G "${USER}" | grep -qw "${VIDEO_GID}" && [ $(stat -c '%A' "${i}" | cut -b 5,6) = "rw" ]; then
			echo "  permissions for ${i} are good" >/dev/null
		# check if device needs to be added to video group
		elif ! id -G "${USER}" | grep -qw "${VIDEO_GID}"; then
			# check if video group needs to be created
			VIDEO_NAME=$(getent group "${VIDEO_GID}" | awk -F: '{print $1}')
			if [ -z "${VIDEO_NAME}" ]; then
				VIDEO_NAME="video$(head /dev/urandom | tr -dc 'a-z0-9' | head -c4)"
				groupadd "${VIDEO_NAME}"
				groupmod -g "${VIDEO_GID}" "${VIDEO_NAME}"
				echo "  creating video group ${VIDEO_NAME} with id ${VIDEO_GID}" >/dev/null
			fi
			echo "  adding ${i} to video group ${VIDEO_NAME} with id ${VIDEO_GID}" >/dev/null
			usermod -a -G "${VIDEO_NAME}" "${USER}"
		fi
		# check if device has group rw
		if [ $(stat -c '%A' "${i}" | cut -b 5,6) != "rw" ]; then
			echo -e " The device ${i} does not have group read/write permissions, attempting to fix inside the container.If it doesn't work, you can run the following on your docker host: \nsudo chmod g+rw ${i}\n"
			chmod g+rw "${i}"
		fi
	fi
done
