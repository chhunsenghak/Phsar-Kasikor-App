import logging
import smtplib
from email.mime.text import MIMEText
from email.utils import formatdate, make_msgid

from app.core.config import settings

logger = logging.getLogger("email_service")


def send_email(to_email: str, subject: str, body: str) -> bool:
    """
    Best-effort plain-text send. Returns False (never raises) if SMTP isn't
    configured or the send fails — callers should treat that as "the code
    exists but delivery failed," not as a request failure, since retrying
    the whole flow (not just the email) is the user's only real recourse
    anyway.
    """
    if not settings.SMTP_HOST or not settings.SMTP_USERNAME:
        logger.info("SMTP not configured — skipping email send.")
        return False

    try:
        from_addr = settings.SMTP_FROM_EMAIL or settings.SMTP_USERNAME
        msg = MIMEText(body)
        msg["Subject"] = subject
        msg["From"] = from_addr
        msg["To"] = to_email
        # A brand-new sending account has no reputation yet, and a message
        # missing Date/Message-ID is a classic spam-filter signal — Gmail
        # was silently dropping these into Spam without them.
        msg["Date"] = formatdate(localtime=True)
        msg["Message-ID"] = make_msgid(domain=from_addr.split("@")[-1])

        server = smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=10)
        try:
            if settings.SMTP_USE_TLS:
                server.starttls()
            server.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
            server.sendmail(msg["From"], [to_email], msg.as_string())
        finally:
            server.quit()
        logger.info(f"Email sent to {to_email}: {subject}")
        return True
    except Exception as e:
        logger.warning(f"Failed to send email to {to_email}: {e}")
        return False
