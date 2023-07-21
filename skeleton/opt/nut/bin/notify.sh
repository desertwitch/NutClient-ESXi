#!/bin/sh
# Rene GARCIA (rene@margar.fr)
# Script executed on ups event

SHUDOWN_PID_FILE="/var/run/ups_shutdown.pid"

. /opt/nut/etc/notify.conf

# count how many UPSes are still online
NB_UPS_ONLINE=$(for UPS in ${UPS_LIST}; do /opt/nut/bin/upsc "${UPS}" ups.status; done | grep -c OL)

# Delayed shutdown if running on battery with less than minsupplies online
if [ "${NOTIFYTYPE}" = "ONBATT" -a "${NB_UPS_ONLINE}" -lt "${MINSUPPLIES}" -a "${ONBATT_DELAY}" -gt 0 ]
then
  if [ ! -f "${SHUDOWN_PID_FILE}" ]
  then
    (
      # seconds to wait
      sleep "${ONBATT_DELAY}"
      # force shutdown
      rm "${SHUDOWN_PID_FILE}"
      /opt/nut/sbin/upsmon -c fsd
      exit 0
    ) &
    echo $! > "${SHUDOWN_PID_FILE}"
  fi
fi

# Abort delayed shutdown if online UPS counter is greater or equal to minsupplies or SHUTDOWN requested immediately
if [ \( "${NB_UPS_ONLINE}" -ge "${MINSUPPLIES}" -o "${NOTIFYTYPE}" = "SHUTDOWN" \) -a -f "${SHUDOWN_PID_FILE}" ]
then
  kill $(cat "${SHUDOWN_PID_FILE}")
  rm "${SHUDOWN_PID_FILE}"
fi

# End here if no mail to send
[ "${SEND_MAIL}" = 1 ] || exit 0

HOSTNAME="`hostname`"
MESSAGE="$1"
DATE="`date +"%d/%m/%Y %k:%M:%S %Z"`"

wget --post-data "apikey=${TO}&priority=1&application=NUT&event=UPS Notification ${NOTIFYTYPE}&description=$DATE - UPS event on ${HOSTNAME} : ${MESSAGE}" -O /dev/null -o /dev/null http://api.prowlapp.com/publicapi/add

exit 0
