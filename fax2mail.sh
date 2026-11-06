#!/bin/sh
# Called from the dialplan: fax2mail.sh <tif> <callerid> <status> <pages> <station-id>
# Received faxes are deleted after the mail was handed over successfully.
# If sending the mail fails, the PDF is kept in /var/spool/asterisk/fax.
TIF="$1"; CID="$2"; STATUS="$3"; PAGES="$4"; RSID="$5"
TO="${FAX_MAIL_TO:-root@localhost}"
# s-nail is installed as s-nail, mailx or mail depending on the distribution
MAILER="$(command -v s-nail || command -v mailx || command -v mail)" || {
    echo "fax: no s-nail/mailx found" >&2; exit 1; }

if [ "$STATUS" = "SUCCESS" ] && [ -s "$TIF" ]; then
    PDF="${TIF%.tif}.pdf"
    tiff2pdf -o "$PDF" "$TIF" && rm -f "$TIF"
    if printf 'Fax von %s (%s), %s Seite(n)\n' "$CID" "$RSID" "$PAGES" \
        | "$MAILER" -s "Fax von $CID" -a "$PDF" "$TO"; then
        rm -f "$PDF"
    fi
else
    printf 'Faxempfang fehlgeschlagen (%s) von %s\n' "$STATUS" "$CID" \
        | "$MAILER" -s "Fax-FEHLER von $CID" "$TO"
    # Remove partial or empty files from failed receptions
    [ -n "$TIF" ] && rm -f "$TIF"
fi
