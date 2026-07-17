import os
import re
import sys
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from config.config import MAIL_CONFIG


def _is_html(text: str) -> bool:
    return bool(re.search(r"<[a-zA-Z][^>]*>", text))


def _format_addresses(addr) -> str:
    if isinstance(addr, list):
        return ", ".join(addr)
    return addr


def send_email(
    to: str | list[str],
    cc: str | list[str] = None,
    subject: str = "",
    body: str = "",
    attachments: list[str] | None = None,
    smtp_server: str | None = None,
    smtp_port: int | None = None,
    sender_email: str | None = None,
    sender_password: str | None = None,
):
    server_host = smtp_server or MAIL_CONFIG["smtp_server"]
    port = smtp_port or MAIL_CONFIG["smtp_port"]
    sender = sender_email or MAIL_CONFIG["sender_email"]
    password = sender_password or MAIL_CONFIG["sender_password"]

    msg = MIMEMultipart()
    msg["From"] = sender
    msg["To"] = _format_addresses(to)
    if cc:
        msg["Cc"] = _format_addresses(cc)
    msg["Subject"] = subject

    content_type = "html" if _is_html(body) else "plain"
    msg.attach(MIMEText(body, content_type, "utf-8"))

    for filepath in (attachments or []):
        ext = os.path.splitext(filepath)[1][1:]
        with open(filepath, "rb") as f:
            part = MIMEApplication(f.read(), _subtype=ext)
            part.add_header(
                "Content-Disposition",
                "attachment",
                filename=os.path.basename(filepath),
            )
            msg.attach(part)

    all_to = []
    for h in (msg.get_all("To") or []):
        all_to.extend(a.strip() for a in h.split(",") if a.strip())
    all_cc = []
    for h in (msg.get_all("Cc") or []):
        all_cc.extend(a.strip() for a in h.split(",") if a.strip())

    with smtplib.SMTP(server_host, port) as s:
        s.starttls()
        s.login(sender, password)
        all_recipients = [sender] + all_to + all_cc
        s.send_message(msg, sender, all_recipients)
