#!/bin/sh
# Called from the dialplan after sending a fax:
#   faxsent.sh <tif> <destination> <status> <pages> <error>
# Mails the result with the sent fax attached as PDF.
# The TIFF is deleted after a successful transmission and kept after a failure.
# Old call files in outgoing_done and leftover TIFFs are removed after 30 days.
TIF="$1"; DEST="$2"; STATUS="$3"; PAGES="$4"; ERROR="$5"
TO="${FAX_MAIL_TO:-root@localhost}"
# s-nail is installed as s-nail, mailx or mail depending on the distribution
MAILER="$(command -v s-nail || command -v mailx || command -v mail)" || {
    echo "fax: no s-nail/mailx found" >&2; exit 1; }
SPOOL=/var/spool/asterisk
PDF="${TIF%.tif}.pdf"

[ -s "$TIF" ] && tiff2pdf -o "$PDF" "$TIF"

case "$STATUS" in
    SUCCESS)
        SUBJECT="Fax an $DEST gesendet"
        TEXT="Fax an $DEST erfolgreich gesendet, $PAGES Seite(n)." ;;
    NOANSWER)
        SUBJECT="Fax an $DEST: nicht erreicht"
        TEXT="Fax an $DEST konnte nicht zugestellt werden (Gegenstelle nicht erreicht oder besetzt)." ;;
    *)
        SUBJECT="Fax an $DEST: FEHLER"
        TEXT="Fax an $DEST fehlgeschlagen (${STATUS:-abgebrochen}${ERROR:+: $ERROR})." ;;
esac

if [ -s "$PDF" ]; then
    printf '%s\n' "$TEXT" | "$MAILER" -s "$SUBJECT" -a "$PDF" "$TO"
else
    printf '%s\n' "$TEXT" | "$MAILER" -s "$SUBJECT" "$TO"
fi

rm -f "$PDF"
[ "$STATUS" = "SUCCESS" ] && rm -f "$TIF"

find "$SPOOL/outgoing_done" "$SPOOL/fax-out" -type f -mtime +30 -delete 2>/dev/null
exit 0
