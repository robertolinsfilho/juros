#!/usr/bin/env python3
"""Login e níveis de acesso do Juros. Escuta só em localhost."""

import hashlib
import hmac
import html
import json
import os
import re
import secrets
import smtplib
import sqlite3
import time
import urllib.error
import urllib.parse
import urllib.request
from email.message import EmailMessage
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DB_PATH = os.environ.get("JUROS_AUTH_DB", "/var/lib/juros/auth.db")
PASSWORD_FILE = os.environ.get("JUROS_AUTH_PASSWORDS", "/var/lib/juros/senhas-iniciais.txt")
HOST = "127.0.0.1"
PORT = 8765
ITERATIONS = 120_000
SESSION_SECONDS = 14 * 24 * 60 * 60
DAY = 24 * 60 * 60
USERNAME = re.compile(r"^[a-z0-9._]{3,32}$")
EMAIL = re.compile(r"^[a-z0-9._%+\-]+@[a-z0-9.\-]+\.[a-z]{2,}$")

# Preços em centavos. "mes" cobra um mês de acesso; "ano" cobra o valor anual.
PLANS = {
    "mensal": {
        "label": "Plano Mensal",
        "price": "R$ 49,99/mês",
        "offers": {
            "mes": {"title": "Acertaí Finanças — Plano Mensal", "cents": 4999, "days": 31},
            "ano": {"title": "Acertaí Finanças — Plano Mensal anual", "cents": 48000, "days": 365},
        },
    },
    "app_relatorio": {
        "label": "Aplicativo + Relatório",
        "price": "R$ 69,90/mês",
        "offers": {
            "mes": {"title": "Acertaí Finanças — Aplicativo + Relatório", "cents": 6990, "days": 31},
            "ano": {"title": "Acertaí Finanças — Aplicativo + Relatório anual", "cents": 49900, "days": 365},
        },
    },
}
PUBLIC_URL = os.environ.get("JUROS_PUBLIC_URL", "https://acertaifinancas.com.br").rstrip("/")
MAIL_FROM = os.environ.get("MAIL_FROM", "Acertaí Finanças <noreply@acertaifinancas.com.br>")
PASSWORD_CODE_TTL = 10 * 60
CONFIRM_TTL = 24 * 60 * 60
MP_API = "https://api.mercadopago.com"
TRIAL_DAYS = 3
# Configurações de cada pessoa que acompanham o login em qualquer aparelho.
SETTING_KEY = re.compile(
    r"^(creditor_name|company_name|pix_key|pix_keys|font_scale|sig_[a-z_]{1,40}|msg_[a-z0-9_]{1,60})$"
)
SETTING_VALUE_MAX = 20_000
SETTINGS_MAX = 200
ACCOUNT_MAX = 1_500_000
ACCOUNT_TABLES = ("clients", "loans", "installments", "cash_entries", "reminders")


def connect():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    return conn


def hash_password(password, salt=None):
    if salt is None:
        salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), ITERATIONS).hex()
    return salt, digest


def password_ok(password, salt, digest):
    check = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), ITERATIONS).hex()
    return hmac.compare_digest(check, digest)


class MailError(Exception):
    pass


def mask_email(email):
    local, _, domain = str(email or "").partition("@")
    if not local or not domain:
        return ""
    return f"{local[0]}***@{domain}"


def send_mail(recipient, subject, body, html_body=None):
    """Envia pelo Postfix local. O código não entra no log."""
    message = EmailMessage()
    message["From"] = MAIL_FROM
    message["To"] = recipient
    message["Subject"] = subject
    message.set_content(body)
    if html_body:
        message.add_alternative(html_body, subtype="html")
    try:
        with smtplib.SMTP("127.0.0.1", 25, timeout=15) as smtp:
            smtp.send_message(message)
    except (OSError, smtplib.SMTPException) as error:
        print(f"email falhou {type(error).__name__}", flush=True)
        raise MailError("envio") from error


def send_password_code(recipient, code):
    send_mail(
        recipient,
        "Código para trocar a senha",
        "Use este código para confirmar a troca de senha na Acertaí Finanças:\n\n"
        f"{code}\n\n"
        "Ele vale por 10 minutos. Se você não pediu a troca, ignore este e-mail.\n",
    )


def issue_password_code(conn, user_id, password, now=None):
    """Guarda o código e a senha nova. Um pedido novo invalida o anterior."""
    now = int(time.time() if now is None else now)
    hour = conn.execute(
        "SELECT COUNT(*) AS n FROM password_codes WHERE user_id = ? AND created_at > ?",
        (user_id, now - 3600),
    ).fetchone()["n"]
    if hour >= 5:
        return None, "Muitos códigos pedidos. Espere um pouco e tente de novo."
    code = f"{secrets.randbelow(1_000_000):06d}"
    salt, digest = hash_password(code)
    pw_salt, pw_digest = hash_password(password)
    conn.execute(
        "UPDATE password_codes SET expires_at = ? WHERE user_id = ? AND expires_at > ?",
        (now, user_id, now),
    )
    conn.execute(
        """
        INSERT INTO password_codes(
          user_id, code_hash, salt, password_hash, password_salt, expires_at, attempts, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, 0, ?)
        """,
        (user_id, digest, salt, pw_digest, pw_salt, now + PASSWORD_CODE_TTL, now),
    )
    conn.commit()
    return code, ""


def take_password_code(conn, user_id, code, password, now=None):
    now = int(time.time() if now is None else now)
    row = conn.execute(
        """
        SELECT * FROM password_codes
        WHERE user_id = ? AND expires_at >= ?
        ORDER BY id DESC
        LIMIT 1
        """,
        (user_id, now),
    ).fetchone()
    if row is None:
        return False, "O código expirou. Peça outro."
    if row["attempts"] >= 5:
        return False, "Muitas tentativas. Peça outro código."
    if not password_ok(str(password), row["password_salt"], row["password_hash"]):
        return False, "A senha mudou depois do código. Peça outro."
    if not password_ok(str(code or "").strip(), row["salt"], row["code_hash"]):
        conn.execute("UPDATE password_codes SET attempts = attempts + 1 WHERE id = ?", (row["id"],))
        conn.commit()
        return False, "Código incorreto."
    conn.execute("DELETE FROM password_codes WHERE user_id = ?", (user_id,))
    conn.commit()
    return True, ""


def email_token_hash(token):
    return hashlib.sha256(str(token).encode()).hexdigest()


def issue_email_confirmation(conn, user_id, now=None):
    """Gera o link de confirmação. Um pedido novo invalida o anterior."""
    now = int(time.time() if now is None else now)
    hour = conn.execute(
        "SELECT COUNT(*) AS n FROM email_confirmations WHERE user_id = ? AND created_at > ?",
        (user_id, now - 3600),
    ).fetchone()["n"]
    if hour >= 5:
        return None
    token = secrets.token_urlsafe(32)
    conn.execute(
        "UPDATE email_confirmations SET expires_at = ? WHERE user_id = ? AND expires_at > ?",
        (now, user_id, now),
    )
    conn.execute(
        """
        INSERT INTO email_confirmations(user_id, token_hash, expires_at, created_at)
        VALUES (?, ?, ?, ?)
        """,
        (user_id, email_token_hash(token), now + CONFIRM_TTL, now),
    )
    return token


def take_email_confirmation(conn, token, now=None):
    """Libera a conta se o link ainda vale. O mesmo link não funciona de novo."""
    now = int(time.time() if now is None else now)
    raw = str(token or "")
    if not raw or len(raw) > 200:
        return None
    row = conn.execute(
        """
        SELECT u.id, u.name
        FROM email_confirmations c
        JOIN users u ON u.id = c.user_id
        WHERE c.token_hash = ? AND c.expires_at >= ?
        """,
        (email_token_hash(raw), now),
    ).fetchone()
    if row is None:
        return None
    conn.execute("UPDATE users SET email_confirmed = 1 WHERE id = ?", (row["id"],))
    conn.execute("DELETE FROM email_confirmations WHERE user_id = ?", (row["id"],))
    conn.commit()
    return row


def _first_name(name):
    parts = str(name or "").split()
    return parts[0] if parts else "olá"


def _mail_document(title, preheader, inner):
    logo = html.escape(f"{PUBLIC_URL}/logo.png", quote=True)
    site = html.escape(PUBLIC_URL, quote=True)
    return f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(title)}</title>
</head>
<body style="margin:0;padding:0;background:#e7eef3;">
  <div style="display:none;max-height:0;overflow:hidden;">{html.escape(preheader)}</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#e7eef3;">
    <tr>
      <td align="center" style="padding:32px 16px;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:16px;overflow:hidden;">
          <tr>
            <td align="center" bgcolor="#060E18" style="padding:32px 24px;">
              <img src="{logo}" width="180" alt="Acertaí Finanças" style="display:block;width:180px;max-width:70%;height:auto;border:0;">
            </td>
          </tr>
          <tr>
            <td style="padding:32px 32px 16px;font-family:Arial,Helvetica,sans-serif;color:#12202b;">
              {inner}
            </td>
          </tr>
          <tr>
            <td style="padding:8px 32px 32px;font-family:Arial,Helvetica,sans-serif;font-size:13px;line-height:20px;color:#5d6d7c;">
              Acertaí Finanças<br>
              <a href="{site}" style="color:#047a6e;text-decoration:none;">acertaifinancas.com.br</a>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""


def confirmation_mail(name, link):
    safe_link = html.escape(link, quote=True)
    who = html.escape(_first_name(name), quote=True)
    button = (
        '<table role="presentation" cellspacing="0" cellpadding="0" style="margin:24px 0;">'
        '<tr><td bgcolor="#45CF6F" style="border-radius:8px;">'
        f'<a href="{safe_link}" style="display:inline-block;padding:14px 28px;font-family:Arial,Helvetica,sans-serif;'
        'font-size:16px;font-weight:700;color:#04230F;text-decoration:none;">Liberar minha conta</a>'
        "</td></tr></table>"
    )
    inner = (
        '<h1 style="margin:0 0 16px;font-size:24px;line-height:32px;font-weight:700;">Confirme seu e-mail</h1>'
        f'<p style="margin:0 0 16px;font-size:16px;line-height:24px;">Olá, {who}.</p>'
        '<p style="margin:0 0 16px;font-size:16px;line-height:24px;">Sua conta na Acertaí Finanças foi criada e ainda não está liberada. '
        "Clique no botão para confirmar que este e-mail é seu. O teste de 3 dias começa quando você entrar.</p>"
        f"{button}"
        '<p style="margin:0 0 16px;font-size:14px;line-height:22px;color:#5d6d7c;">Se o botão não abrir, copie e cole este endereço no navegador:<br>'
        f'<a href="{safe_link}" style="color:#047a6e;word-break:break-all;">{safe_link}</a></p>'
        '<p style="margin:0;font-size:14px;line-height:22px;color:#5d6d7c;">O link vale por 24 horas e só funciona uma vez. '
        "Se você não criou a conta, ignore este e-mail.</p>"
    )
    plain = (
        f"Olá, {_first_name(name)}.\n\n"
        "Sua conta na Acertaí Finanças foi criada e ainda não está liberada.\n"
        "Abra o link abaixo para confirmar o e-mail. O teste de 3 dias começa quando você entrar.\n\n"
        f"{link}\n\n"
        "O link vale por 24 horas e só funciona uma vez.\n"
        "Se você não criou a conta, ignore este e-mail.\n"
    )
    html_body = _mail_document(
        "Confirme seu e-mail",
        "Confirme seu e-mail para liberar a conta na Acertaí Finanças.",
        inner,
    )
    return plain, html_body


def confirmation_page(ok, name=""):
    if ok:
        who = html.escape(_first_name(name), quote=True)
        title = "Conta liberada"
        inner = (
            f'<h1 style="margin:0 0 16px;font-size:24px;line-height:32px;">Conta liberada</h1>'
            f'<p style="margin:0 0 16px;font-size:16px;line-height:24px;">Olá, {who}. Seu e-mail foi confirmado.</p>'
            '<p style="margin:0 0 16px;font-size:16px;line-height:24px;">Agora é só entrar com o usuário e a senha que você escolheu. '
            "O teste de 3 dias começa nessa entrada.</p>"
        )
        label = "Entrar na Acertaí"
    else:
        title = "Link inválido"
        inner = (
            '<h1 style="margin:0 0 16px;font-size:24px;line-height:32px;">Este link não vale mais</h1>'
            '<p style="margin:0 0 16px;font-size:16px;line-height:24px;">Ele já foi usado ou passou de 24 horas. '
            "Se a conta já foi liberada, entre normalmente. Se ainda não foi, peça um novo e-mail na tela de entrada.</p>"
        )
        label = "Ir para o site"
    site = html.escape(PUBLIC_URL, quote=True)
    button = (
        '<table role="presentation" cellspacing="0" cellpadding="0" style="margin:8px 0 16px;">'
        '<tr><td bgcolor="#45CF6F" style="border-radius:8px;">'
        f'<a href="{site}" style="display:inline-block;padding:14px 28px;font-family:Arial,Helvetica,sans-serif;'
        f'font-size:16px;font-weight:700;color:#04230F;text-decoration:none;">{label}</a>'
        "</td></tr></table>"
    )
    return _mail_document(title, title, inner + button)


def send_confirmation_mail(recipient, name, token):
    link = f"{PUBLIC_URL}/api/confirm-email?token={urllib.parse.quote(token)}"
    plain, html_body = confirmation_mail(name, link)
    send_mail(recipient, "Confirme seu e-mail para liberar a conta", plain, html_body)


def end_other_sessions(conn, user_id, keep_token=""):
    """Encerra as outras entradas desta conta. A sessão atual continua."""
    if keep_token:
        conn.execute(
            "DELETE FROM sessions WHERE user_id = ? AND token != ?",
            (user_id, keep_token),
        )
    else:
        conn.execute("DELETE FROM sessions WHERE user_id = ?", (user_id,))


def start_password_change(conn, row, current, password, send, now=None):
    """Confere a senha atual e manda o código. Não devolve o código."""
    email = str(row["email"] or "").strip().lower()
    if not EMAIL.fullmatch(email):
        return None, "Sua conta não tem um e-mail cadastrado para receber o código.", 400
    if not password_ok(str(current), row["salt"], row["password_hash"]):
        return None, "Senha atual incorreta.", 400
    if len(str(password)) < 6:
        return None, "A senha precisa ter pelo menos 6 caracteres.", 400
    code, message = issue_password_code(conn, row["id"], password, now=now)
    if code is None:
        return None, message, 429
    try:
        send(email, code)
    except MailError:
        moment = int(time.time() if now is None else now)
        conn.execute(
            "DELETE FROM password_codes WHERE user_id = ? AND expires_at > ?",
            (row["id"], moment),
        )
        conn.commit()
        return None, "Não foi possível enviar o e-mail. Tente de novo.", 502
    return mask_email(email), "", 200


def mp_token():
    return os.environ.get("MERCADOPAGO_ACCESS_TOKEN", "").strip()


def offer_of(plan, period):
    item = PLANS.get(plan)
    if item is None:
        return None
    return item["offers"].get(period)


def build_preference(user_id, plan, period, email=""):
    """Corpo do checkout (Checkout Pro) para um plano e um prazo."""
    offer = offer_of(plan, period)
    body = {
        "items": [
            {
                "id": f"{plan}-{period}",
                "title": offer["title"],
                "quantity": 1,
                "currency_id": "BRL",
                "unit_price": offer["cents"] / 100,
            }
        ],
        "external_reference": f"{user_id}:{plan}:{period}",
        "notification_url": f"{PUBLIC_URL}/api/mercadopago/webhook",
        "back_urls": {
            "success": f"{PUBLIC_URL}/?assinatura=ok",
            "pending": f"{PUBLIC_URL}/?assinatura=pendente",
            "failure": f"{PUBLIC_URL}/?assinatura=falha",
        },
        "auto_return": "approved",
        "statement_descriptor": "ACERTAI",
        "metadata": {"user_id": user_id, "plan": plan, "period": period},
    }
    if email:
        body["payer"] = {"email": email}
    return body


class MercadoPagoError(Exception):
    pass


def mp_json(method, path, payload=None):
    """Chama a API do Mercado Pago. O token fica só na variável de ambiente."""
    token = mp_token()
    if not token:
        raise MercadoPagoError("sem token")
    body = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(
        MP_API + path,
        data=body,
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", "replace")[:300]
        print(f"mercadopago {error.code} {detail}", flush=True)
        raise MercadoPagoError("falha") from error
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        print(f"mercadopago rede {error}", flush=True)
        raise MercadoPagoError("rede") from error


def checkout_url(preference):
    """Checkout Pro usa sempre o init_point, também com a credencial de teste."""
    return preference.get("init_point") or ""


CONSULTA_API = os.environ.get("CONSULTA_API_URL", "https://gateway.apibrasil.io/api/v2").rstrip("/")


def consulta_token():
    return os.environ.get("CONSULTA_API_TOKEN", "").strip()


# Preço de vitrine em centavos. O custo fica na APIBrasil; o cliente paga aqui, no Mercado Pago.
CONSULTAS = {
    "localizador": {
        "title": "Localizador",
        "summary": "Encontra a pessoa a partir do telefone ou do e-mail.",
        "cents": 990,
        "inputs": [{"id": "telefone", "label": "Telefone"}, {"id": "email", "label": "E-mail"}],
        "bullets": ["Nome e CPF de quem aparece na busca", "Telefones e e-mails ligados ao contato", "Endereços quando a base tiver"],
        "calls": {
            "telefone": {"path": "/consulta/cpf/credits", "tipo": "enriquecimento-de-lead", "field": "telefone"},
            "email": {"path": "/consulta/cpf/credits", "tipo": "enriquecimento-de-lead", "field": "email"},
        },
    },
    "dossie": {
        "title": "Dossiê",
        "summary": "Cadastro, pendências, protestos, empresas e telefones.",
        "cents": 1990,
        "inputs": [{"id": "cpf", "label": "CPF"}, {"id": "cnpj", "label": "CNPJ"}],
        "bullets": ["Dados na Receita e identificação", "Pendências financeiras e protestos", "Empresas e telefones"],
        "calls": {
            "cpf": {"path": "/consulta/cpf/credits", "tipo": "dossie-credito-pf", "field": "cpf"},
            "cnpj": {"path": "/consulta/cnpj/credits", "tipo": "dossie-credito-pj", "field": "cnpj"},
        },
    },
    "protestos": {
        "title": "Protestos",
        "summary": "Protestos em cartório, com cidade, data e valor.",
        "cents": 990,
        "inputs": [{"id": "cpf", "label": "CPF"}, {"id": "cnpj", "label": "CNPJ"}],
        "bullets": ["Protestos ativos", "Cartório, cidade e UF", "Datas e valores"],
        "calls": {
            "cpf": {"path": "/consulta/cpf/credits", "tipo": "protestos-nacional-base", "field": "cpf"},
            "cnpj": {"path": "/consulta/cnpj/credits", "tipo": "pessoa-juridica-protesto", "field": "cnpj"},
        },
    },
    "rating": {
        "title": "Rating de crédito",
        "summary": "Score, risco, pendências, protestos e cheques sem fundo.",
        "cents": 2990,
        "inputs": [{"id": "cpf", "label": "CPF"}, {"id": "cnpj", "label": "CNPJ"}],
        "bullets": ["Score e risco", "Pendências e protestos", "Cheques sem fundo e ações"],
        "calls": {
            "cpf": {"path": "/consulta/cpf/credits", "tipo": "restricoes-score-pf", "field": "cpf"},
            "cnpj": {"path": "/consulta/cnpj/credits", "tipo": "restricoes-score-pj", "field": "cnpj"},
        },
    },
    "cadastro": {
        "title": "Cadastro",
        "summary": "Identidade, situação cadastral e contatos.",
        "cents": 500,
        "inputs": [{"id": "cpf", "label": "CPF"}, {"id": "cnpj", "label": "CNPJ"}],
        "bullets": ["Identidade e situação cadastral", "Endereços e telefones", "E-mails quando a base tiver"],
        "calls": {
            "cpf": {"path": "/consulta/cpf/credits", "tipo": "cpf-hotline", "field": "cpf"},
            "cnpj": {"path": "/consulta/cnpj/credits", "tipo": "cnpj-cadastral", "field": "cnpj"},
        },
    },
    "essencial": {
        "title": "Essencial positivo",
        "summary": "Situação do CPF, score, protestos, pendências e contatos.",
        "cents": 1090,
        "inputs": [{"id": "cpf", "label": "CPF"}],
        "bullets": ["Situação do CPF na Receita", "Score, protestos e pendências", "Telefones, e-mails e endereços"],
        "calls": {
            "cpf": {"path": "/consulta/cpf/credits", "tipo": "acerta-essencial-positivo", "field": "cpf"},
        },
    },
    "bacen": {
        "title": "Resumo BACEN",
        "summary": "SCR do Banco Central: responsabilidade, modalidades e instituições.",
        "cents": 1390,
        "inputs": [{"id": "cpf", "label": "CPF"}, {"id": "cnpj", "label": "CNPJ"}],
        "bullets": ["Mês de referência e responsabilidade total", "Operações por modalidade", "Instituições e operações sub judice"],
        "calls": {
            "cpf": {"path": "/consulta/cpf/credits", "tipo": "scr-bacen-score", "field": "cpf"},
            "cnpj": {"path": "/consulta/cnpj/credits", "tipo": "scr-bacen-score", "field": "cnpj"},
        },
    },
}


def digits_only(value):
    return re.sub(r"\D", "", str(value or ""))


def cpf_ok(digits):
    if len(digits) != 11 or digits == digits[0] * 11:
        return False

    def dv(base):
        total = sum(int(digit) * factor for digit, factor in zip(base, range(len(base) + 1, 1, -1)))
        rest = (total * 10) % 11
        return 0 if rest == 10 else rest

    return dv(digits[:9]) == int(digits[9]) and dv(digits[:10]) == int(digits[10])


def cnpj_ok(digits):
    if len(digits) != 14 or digits == digits[0] * 14:
        return False

    def dv(base, weights):
        rest = sum(int(digit) * weight for digit, weight in zip(base, weights)) % 11
        return 0 if rest < 2 else 11 - rest

    first = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    second = [6, *first]
    return dv(digits[:12], first) == int(digits[12]) and dv(digits[:13], second) == int(digits[13])


def prepare_consulta(slug, document, search_type):
    """Confere o produto e o documento. Não fala com o fornecedor."""
    item = CONSULTAS.get(str(slug or "").strip())
    if item is None:
        return None, "Consulta inválida."
    kind = str(search_type or "").strip().lower()
    call = item["calls"].get(kind)
    if call is None:
        return None, "Escolha CPF, CNPJ, telefone ou e-mail."
    raw = str(document or "").strip()
    field = call["field"]
    if field == "email":
        value = raw.lower()
        if not EMAIL.match(value):
            return None, "Informe um e-mail válido."
    elif field == "telefone":
        value = digits_only(raw)
        if len(value) not in (10, 11):
            return None, "Informe um telefone com DDD."
    elif field == "cpf":
        value = digits_only(raw)
        if not cpf_ok(value):
            return None, "Informe um CPF válido."
    elif field == "cnpj":
        value = digits_only(raw)
        if not cnpj_ok(value):
            return None, "Informe um CNPJ válido."
    else:
        return None, "Consulta inválida."
    return {"slug": slug, "search_type": kind, "document": value, "cents": item["cents"], "title": item["title"]}, ""


def consulta_catalog():
    return [
        {
            "slug": slug,
            "title": item["title"],
            "summary": item["summary"],
            "cents": item["cents"],
            "inputs": item["inputs"],
            "bullets": item["bullets"],
        }
        for slug, item in CONSULTAS.items()
    ]


def build_consulta_preference(consult_id, title, cents, email=""):
    """Checkout de uma consulta. A referência não é a de assinatura, para não somar dias de plano."""
    body = {
        "items": [
            {
                "id": f"consulta-{consult_id}",
                "title": f"Acertaí Finanças — {title}",
                "quantity": 1,
                "currency_id": "BRL",
                "unit_price": cents / 100,
            }
        ],
        "external_reference": f"consulta:{consult_id}",
        "notification_url": f"{PUBLIC_URL}/api/mercadopago/webhook",
        "back_urls": {
            "success": f"{PUBLIC_URL}/?consulta=ok",
            "pending": f"{PUBLIC_URL}/?consulta=pendente",
            "failure": f"{PUBLIC_URL}/?consulta=falha",
        },
        "auto_return": "approved",
        "statement_descriptor": "ACERTAI",
        "metadata": {"consult_id": consult_id},
    }
    if email:
        body["payer"] = {"email": email}
    return body


class ConsultaError(Exception):
    def __init__(self, message, retry=False):
        super().__init__(message)
        self.retry = retry


def provider_message(text):
    clean = " ".join(str(text or "").split())
    lowered = clean.lower()
    if not clean or len(clean) > 180 or "token" in lowered or "bearer" in lowered:
        return "A consulta não foi concluída."
    return clean


def consulta_payload(loaded):
    """O dossiê vem em data. Alguns retornos embrulham isso em response."""
    if not isinstance(loaded, dict):
        return None
    data = loaded.get("data")
    if isinstance(data, (dict, list)):
        return data
    inner = loaded.get("response")
    if isinstance(inner, dict):
        nested = inner.get("data")
        if isinstance(nested, (dict, list)):
            return nested
    return None


def run_consulta(slug, search_type, document):
    """Busca o dossiê na APIBrasil. O token fica só na variável de ambiente."""
    call = CONSULTAS[slug]["calls"][search_type]
    token = consulta_token()
    if not token:
        raise ConsultaError("As consultas ainda não estão ligadas ao fornecedor.", retry=True)
    payload = {"tipo": call["tipo"], call["field"]: document}
    request = urllib.request.Request(
        CONSULTA_API + call["path"],
        data=json.dumps(payload).encode(),
        method="POST",
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=40) as response:
            loaded = json.loads(response.read().decode())
    except urllib.error.HTTPError as error:
        print(f"consulta http {error.code}", flush=True)
        if error.code == 402:
            raise ConsultaError("O saldo do fornecedor acabou. Tente de novo sem pagar outra vez.", retry=True) from error
        if error.code == 404:
            raise ConsultaError("Nenhum dado encontrado para esta consulta.") from error
        if error.code in (408, 429, 500, 502, 503, 504):
            raise ConsultaError("A fonte demorou para responder. Tente de novo sem pagar outra vez.", retry=True) from error
        raise ConsultaError("A consulta não foi concluída.") from error
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        print(f"consulta rede {error}", flush=True)
        raise ConsultaError("A fonte demorou para responder. Tente de novo sem pagar outra vez.", retry=True) from error
    if not isinstance(loaded, dict) or loaded.get("error") is True:
        raw = " ".join(str(loaded.get("message") or "").split()) if isinstance(loaded, dict) else ""
        if "saldo" in raw.lower() or "insuficiente" in raw.lower():
            raise ConsultaError("O saldo do fornecedor acabou. Tente de novo sem pagar outra vez.", retry=True)
        raise ConsultaError(provider_message(raw))
    data = consulta_payload(loaded)
    if data is None:
        raise ConsultaError("A consulta voltou sem dados.", retry=True)
    return data


def consulta_row(row, with_result=False):
    item = CONSULTAS.get(row["type_slug"], {})
    body = {
        "id": row["id"],
        "slug": row["type_slug"],
        "title": item.get("title", row["type_slug"]),
        "search_type": row["search_type"],
        "document": row["document"],
        "amount_cents": row["amount_cents"],
        "status": row["status"],
        "error": row["error"],
        "created_at": row["created_at"],
    }
    if with_result and row["result_json"]:
        try:
            body["result"] = json.loads(row["result_json"])
        except json.JSONDecodeError:
            body["result"] = None
    return body


def finish_consulta(conn, row):
    """Chama o fornecedor uma vez. Outra chamada simultânea encontra o status consultando."""
    cur = conn.execute(
        """
        UPDATE consultations
        SET status = 'consultando', error = ''
        WHERE id = ? AND status = 'paga' AND result_json = ''
        """,
        (row["id"],),
    )
    if cur.rowcount != 1:
        conn.rollback()
        return
    conn.commit()
    try:
        data = run_consulta(row["type_slug"], row["search_type"], row["document"])
    except ConsultaError as error:
        status = "paga" if error.retry else "falha"
        conn.execute(
            "UPDATE consultations SET status = ?, error = ? WHERE id = ?",
            (status, str(error), row["id"]),
        )
        conn.commit()
        return
    conn.execute(
        "UPDATE consultations SET status = 'concluida', result_json = ?, error = '' WHERE id = ?",
        (json.dumps(data, ensure_ascii=False), row["id"]),
    )
    conn.commit()


def apply_consulta_payment(conn, payment):
    """Marca a consulta como paga e dispara a busca. Não mexe na assinatura."""
    if payment.get("status") != "approved":
        return "ignored"
    ref = str(payment.get("external_reference") or "")
    if not ref.startswith("consulta:"):
        return "ignored"
    consult_id = ref.split(":", 1)[1]
    if not consult_id.isdigit() or payment.get("currency_id") != "BRL":
        return "ignored"
    row = conn.execute("SELECT * FROM consultations WHERE id = ?", (int(consult_id),)).fetchone()
    if row is None:
        return "ignored"
    paid = int(round(float(payment.get("transaction_amount") or 0) * 100))
    if abs(paid - int(row["amount_cents"])) > 1:
        return "ignored"
    mp_id = str(payment.get("id") or "")
    if not mp_id:
        return "ignored"
    if row["mp_id"]:
        return "duplicate" if row["mp_id"] == mp_id else "ignored"
    now = int(time.time())
    try:
        cur = conn.execute(
            """
            UPDATE consultations
            SET status = 'paga', mp_id = ?, paid_at = ?
            WHERE id = ? AND COALESCE(mp_id, '') = ''
            """,
            (mp_id, now, row["id"]),
        )
        if cur.rowcount != 1:
            conn.rollback()
            return "duplicate"
        conn.commit()
    except sqlite3.IntegrityError:
        conn.rollback()
        return "duplicate"
    fresh = conn.execute("SELECT * FROM consultations WHERE id = ?", (row["id"],)).fetchone()
    finish_consulta(conn, fresh)
    return "applied"


def find_consulta_payment(consult_id):
    """Pagamento aprovado desta consulta, quando o aviso do Mercado Pago ainda não chegou."""
    query = urllib.parse.urlencode(
        {
            "external_reference": f"consulta:{consult_id}",
            "sort": "date_created",
            "criteria": "desc",
            "limit": "5",
        }
    )
    found = mp_json("GET", f"/v1/payments/search?{query}")
    results = found.get("results") if isinstance(found, dict) else None
    if not isinstance(results, list):
        return None
    wanted = f"consulta:{consult_id}"
    for payment in results:
        if not isinstance(payment, dict):
            continue
        if str(payment.get("external_reference") or "") != wanted:
            continue
        if payment.get("status") == "approved":
            return payment
    return None


def sync_consulta_payment(conn, row, lookup=None):
    """Marca a consulta como paga assim que o Mercado Pago confirma, sem depender só do aviso."""
    if row["mp_id"] or row["status"] != "aguardando":
        return row
    if lookup is None:
        if not mp_token():
            return row
        try:
            payment = find_consulta_payment(row["id"])
        except MercadoPagoError:
            return row
    else:
        payment = lookup(row["id"])
    if not isinstance(payment, dict):
        return row
    apply_consulta_payment(conn, payment)
    fresh = conn.execute("SELECT * FROM consultations WHERE id = ?", (row["id"],)).fetchone()
    return fresh or row


def resume_consulta(conn, row):
    """Chama o fornecedor se o pagamento entrou e a busca ainda não saiu."""
    if row["status"] != "paga" or row["result_json"] or row["error"]:
        return row
    finish_consulta(conn, row)
    fresh = conn.execute("SELECT * FROM consultations WHERE id = ?", (row["id"],)).fetchone()
    return fresh or row


def apply_approved_payment(conn, payment):
    """Libera os dias do plano quando o Mercado Pago confirma o valor certo.

    Pagamento repetido não soma os dias de novo.
    """
    if payment.get("status") != "approved":
        return "ignored"
    parts = str(payment.get("external_reference") or "").split(":")
    if len(parts) != 3 or not parts[0].isdigit():
        return "ignored"
    user_id, plan, period = int(parts[0]), parts[1], parts[2]
    offer = offer_of(plan, period)
    if offer is None or payment.get("currency_id") != "BRL":
        return "ignored"
    paid = int(round(float(payment.get("transaction_amount") or 0) * 100))
    if abs(paid - offer["cents"]) > 1:
        return "ignored"
    mp_id = str(payment.get("id") or "")
    if not mp_id:
        return "ignored"
    user = conn.execute("SELECT id, paid_until FROM users WHERE id = ?", (user_id,)).fetchone()
    if user is None:
        return "ignored"
    now = int(time.time())
    base = max(int(user["paid_until"] or 0), now)
    try:
        conn.execute(
            """
            INSERT INTO payments(mp_id, user_id, plan, days, amount_cents, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (mp_id, user_id, plan, offer["days"], paid, now),
        )
        conn.execute(
            "UPDATE users SET paid_until = ?, plan = ? WHERE id = ?",
            (base + offer["days"] * DAY, plan, user_id),
        )
        conn.execute(
            "UPDATE subscription_requests SET status = 'concluido' WHERE user_id = ? AND status = 'pendente'",
            (user_id,),
        )
        conn.commit()
    except sqlite3.IntegrityError:
        conn.rollback()
        return "duplicate"
    return "applied"


def _account_cell_ok(value):
    if value is None or isinstance(value, bool):
        return True
    if isinstance(value, int):
        return abs(value) < 10**15
    if isinstance(value, float):
        return abs(value) < 10**12
    if isinstance(value, str):
        return len(value) <= 4000
    return False


def account_payload_ok(payload):
    """A cópia da conta só traz as tabelas do movimento e os ajustes."""
    if not isinstance(payload, dict):
        return False
    if set(payload) - set(ACCOUNT_TABLES) - {"settings"}:
        return False
    for table in ACCOUNT_TABLES:
        rows = payload.get(table, [])
        if not isinstance(rows, list):
            return False
        for row in rows:
            if not isinstance(row, dict) or len(row) > 40:
                return False
            for key, value in row.items():
                if not isinstance(key, str) or len(key) > 64 or not _account_cell_ok(value):
                    return False
    settings = payload.get("settings", {})
    if not isinstance(settings, dict) or len(settings) > 300:
        return False
    for key, value in settings.items():
        if not isinstance(key, str) or len(key) > 80 or key == "session_token":
            return False
        if not isinstance(value, str) or len(value) > SETTING_VALUE_MAX:
            return False
    return True


def store_account(conn, user_id, base, payload, now):
    """Grava a cópia da conta se a revisão ainda é a que o aparelho viu."""
    if not account_payload_ok(payload):
        return "invalid", 0, 0, None
    raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    if len(raw.encode()) > ACCOUNT_MAX:
        return "too_big", 0, 0, None
    row = conn.execute(
        "SELECT revision, updated_at, payload FROM account_data WHERE user_id = ?",
        (user_id,),
    ).fetchone()
    if row is None:
        if base != 0:
            return "conflict", 0, 0, None
        conn.execute(
            "INSERT INTO account_data(user_id, revision, updated_at, payload) VALUES (?, 1, ?, ?)",
            (user_id, now, raw),
        )
        return "ok", 1, now, None
    if int(row["revision"]) != base:
        current = json.loads(row["payload"])
        return "conflict", int(row["revision"]), int(row["updated_at"]), current
    revision = int(row["revision"]) + 1
    conn.execute(
        "UPDATE account_data SET revision = ?, updated_at = ?, payload = ? WHERE user_id = ?",
        (revision, now, raw, user_id),
    )
    return "ok", revision, now, None


def ensure_schema(conn):
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY,
          username TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          role TEXT NOT NULL,
          salt TEXT NOT NULL,
          password_hash TEXT NOT NULL,
          active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          trial_ends_at INTEGER NOT NULL DEFAULT 0,
          paid_until INTEGER NOT NULL DEFAULT 0,
          plan TEXT NOT NULL DEFAULT ''
        );
        CREATE TABLE IF NOT EXISTS sessions (
          token TEXT PRIMARY KEY,
          user_id INTEGER NOT NULL REFERENCES users(id),
          expires_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS user_settings (
          user_id INTEGER NOT NULL REFERENCES users(id),
          key TEXT NOT NULL,
          value TEXT NOT NULL,
          PRIMARY KEY (user_id, key)
        );
        CREATE TABLE IF NOT EXISTS subscription_requests (
          id INTEGER PRIMARY KEY,
          user_id INTEGER NOT NULL REFERENCES users(id),
          plan TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'pendente'
        );
        CREATE TABLE IF NOT EXISTS payments (
          mp_id TEXT PRIMARY KEY,
          user_id INTEGER NOT NULL REFERENCES users(id),
          plan TEXT NOT NULL,
          days INTEGER NOT NULL,
          amount_cents INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS consultations (
          id INTEGER PRIMARY KEY,
          user_id INTEGER NOT NULL REFERENCES users(id),
          type_slug TEXT NOT NULL,
          search_type TEXT NOT NULL,
          document TEXT NOT NULL,
          amount_cents INTEGER NOT NULL,
          status TEXT NOT NULL DEFAULT 'aguardando',
          mp_id TEXT UNIQUE,
          result_json TEXT NOT NULL DEFAULT '',
          error TEXT NOT NULL DEFAULT '',
          created_at INTEGER NOT NULL,
          paid_at INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS password_codes (
          id INTEGER PRIMARY KEY,
          user_id INTEGER NOT NULL REFERENCES users(id),
          code_hash TEXT NOT NULL,
          salt TEXT NOT NULL,
          password_hash TEXT NOT NULL,
          password_salt TEXT NOT NULL,
          expires_at INTEGER NOT NULL,
          attempts INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS email_confirmations (
          id INTEGER PRIMARY KEY,
          user_id INTEGER NOT NULL REFERENCES users(id),
          token_hash TEXT NOT NULL,
          expires_at INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS account_data (
          user_id INTEGER PRIMARY KEY REFERENCES users(id),
          revision INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          payload TEXT NOT NULL
        );
        """
    )
    upgraded = False
    columns = {row["name"] for row in conn.execute("PRAGMA table_info(users)").fetchall()}
    for name, definition in (
        ("trial_ends_at", "INTEGER NOT NULL DEFAULT 0"),
        ("paid_until", "INTEGER NOT NULL DEFAULT 0"),
        ("plan", "TEXT NOT NULL DEFAULT ''"),
    ):
        if name not in columns:
            conn.execute(f"ALTER TABLE users ADD COLUMN {name} {definition}")
            upgraded = True
    if upgraded:
        # Quem administra o sistema não é afetado pelo teste; os demais começam os 3 dias agora.
        now = int(time.time())
        conn.execute(
            "UPDATE users SET paid_until = ?, plan = 'cortesia' WHERE role = 'admin'",
            (now + 3650 * DAY,),
        )
        conn.execute(
            "UPDATE users SET trial_ends_at = ?, paid_until = 0, plan = '' WHERE role != 'admin'",
            (now + TRIAL_DAYS * DAY,),
        )
        conn.commit()
    if "email" not in columns:
        conn.execute("ALTER TABLE users ADD COLUMN email TEXT NOT NULL DEFAULT ''")
        conn.commit()
    if "email_confirmed" not in columns:
        conn.execute("ALTER TABLE users ADD COLUMN email_confirmed INTEGER NOT NULL DEFAULT 1")
        conn.commit()
    count = conn.execute("SELECT COUNT(*) AS n FROM users").fetchone()["n"]
    if count:
        conn.commit()
        return
    created = []
    now = int(time.time())
    for username, name, role in (
        ("admin", "Roberto Lins", "admin"),
        ("operador", "Operador", "comum"),
        ("caixa", "Caixa", "comum"),
    ):
        password = secrets.token_urlsafe(9)
        salt, digest = hash_password(password)
        conn.execute(
            """
            INSERT INTO users(username, name, role, salt, password_hash, active, created_at, trial_ends_at)
            VALUES (?, ?, ?, ?, ?, 1, ?, ?)
            """,
            (username, name, role, salt, digest, now, now + TRIAL_DAYS * DAY),
        )
        created.append(f"{username} ({role}): {password}")
    conn.commit()
    flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC
    fd = os.open(PASSWORD_FILE, flags, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        handle.write("\n".join(created) + "\n")


def access_of(row, now=None):
    """Situação do acesso: teste, assinatura ativa ou vencido, com os dias restantes."""
    now = int(now or time.time())
    paid_until = int(row["paid_until"] or 0)
    created = int(row["created_at"] or now)
    trial_end = int(row["trial_ends_at"] or 0) or (created + TRIAL_DAYS * DAY)
    # Administrador nunca fica trancado fora do sistema.
    admin = row["role"] == "admin"
    if paid_until > now:
        return {
            "status": "assinante",
            "days_left": (paid_until - now + DAY - 1) // DAY,
            "trial_ends_at": trial_end,
            "paid_until": paid_until,
            "plan": row["plan"] or "",
            "blocked": False,
        }
    if trial_end > now:
        return {
            "status": "teste",
            "days_left": (trial_end - now + DAY - 1) // DAY,
            "trial_ends_at": trial_end,
            "paid_until": paid_until,
            "plan": row["plan"] or "",
            "blocked": False,
        }
    return {
        "status": "vencido",
        "days_left": 0,
        "trial_ends_at": trial_end,
        "paid_until": paid_until,
        "plan": row["plan"] or "",
        "blocked": not admin,
    }


def cancel_subscription(conn, user_id):
    """Encerra o acesso pago de quem tem assinatura. Não estorna o Mercado Pago."""
    row = conn.execute(
        "SELECT id, username, name, email, role, active, created_at, trial_ends_at, paid_until, plan FROM users WHERE id = ?",
        (user_id,),
    ).fetchone()
    if row is None:
        return None, "Usuário não encontrado."
    if access_of(row)["status"] != "assinante":
        return None, "Não há assinatura ativa para cancelar."
    plan = row["plan"] or ""
    if row["role"] == "admin" and plan in ("", "cortesia"):
        return None, "O acesso de administrador não é uma assinatura."
    conn.execute("UPDATE users SET paid_until = 0, plan = '' WHERE id = ?", (user_id,))
    conn.commit()
    fresh = conn.execute(
        "SELECT id, username, name, email, role, active, created_at, trial_ends_at, paid_until, plan FROM users WHERE id = ?",
        (user_id,),
    ).fetchone()
    return fresh, ""


def public_user(row, now=None):
    return {
        "id": row["id"],
        "username": row["username"],
        "name": row["name"],
        "role": row["role"],
        "active": bool(row["active"]),
        "email": row["email"] if "email" in row.keys() else "",
        "access": access_of(row, now),
    }


def current_user(conn, header):
    if not header or not header.startswith("Bearer "):
        return None
    token = header[7:].strip()
    if not token:
        return None
    row = conn.execute(
        """
        SELECT u.id, u.username, u.name, u.email, u.role, u.active, u.created_at,
               u.trial_ends_at, u.paid_until, u.plan
        FROM sessions s
        JOIN users u ON u.id = s.user_id
        WHERE s.token = ? AND s.expires_at > ?
        """,
        (token, int(time.time())),
    ).fetchone()
    if row is None or not row["active"]:
        return None
    return row


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self._route("GET")

    def do_POST(self):
        self._route("POST")

    def log_message(self, fmt, *args):
        return

    def _route(self, method):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path.rstrip("/") or "/"
        query = urllib.parse.parse_qs(parsed.query)
        length = int(self.headers.get("Content-Length", "0") or "0")
        if length < 0 or length > ACCOUNT_MAX + 80_000:
            self.close_connection = True
            self._send(413, {"error": "Pedido grande demais."})
            return
        raw = self.rfile.read(length) if length else b""
        data = {}
        if raw:
            try:
                loaded = json.loads(raw.decode() or "{}")
            except json.JSONDecodeError:
                loaded = None
            if not isinstance(loaded, dict):
                if path != "/api/mercadopago/webhook":
                    self._send(400, {"error": "Pedido inválido."})
                    return
                loaded = {}
            data = loaded
        conn = connect()
        try:
            if path == "/api/mercadopago/webhook" and method in ("GET", "POST"):
                self._mercadopago_webhook(conn, data, query)
                return
            if method == "GET" and path == "/api/health":
                self._send(200, {"ok": True})
                return
            if method == "POST" and path == "/api/login":
                self._login(conn, data)
                return
            if method == "POST" and path == "/api/signup":
                self._signup(conn, data)
                return
            if method == "POST" and path == "/api/signup/resend":
                self._resend_confirmation(conn, data)
                return
            if method == "GET" and path == "/api/confirm-email":
                self._confirm_email(conn, (query.get("token") or [""])[0])
                return
            actor = current_user(conn, self.headers.get("Authorization"))
            if actor is None:
                self._send(401, {"error": "Entre novamente."})
                return
            if method == "POST" and path == "/api/logout":
                token = self.headers.get("Authorization", "")[7:].strip()
                conn.execute("DELETE FROM sessions WHERE token = ?", (token,))
                conn.commit()
                self._send(200, {"ok": True})
                return
            if path == "/api/me" and method == "GET":
                self._send(200, {"user": public_user(actor)})
                return
            if path == "/api/me" and method == "POST":
                self._update_profile(conn, actor, data)
                return
            if path == "/api/me/cancel" and method == "POST":
                self._cancel_subscription(conn, actor)
                return
            if path == "/api/me/password-code" and method == "POST":
                self._password_code(conn, actor, data)
                return
            if path == "/api/subscribe" and method == "POST":
                self._subscribe(conn, actor, data)
                return
            if path == "/api/requests" and method == "GET":
                self._list_requests(conn, actor)
                return
            if path == "/api/settings" and method == "GET":
                self._get_settings(conn, actor)
                return
            if path == "/api/settings" and method == "POST":
                self._save_settings(conn, actor, data)
                return
            if path == "/api/account" and method == "GET":
                self._get_account(conn, actor)
                return
            if path == "/api/account" and method == "POST":
                self._save_account(conn, actor, data)
                return
            if path == "/api/users" and method == "GET":
                self._list_users(conn, actor)
                return
            if path == "/api/users" and method == "POST":
                self._create_user(conn, actor, data)
                return
            if path == "/api/consultas" and method == "GET":
                self._consultas_get(conn, actor, query)
                return
            if path == "/api/consultas" and method == "POST":
                self._consulta_create(conn, actor, data)
                return
            parts = path.split("/")
            if (
                len(parts) == 5
                and parts[1] == "api"
                and parts[2] == "consultas"
                and parts[4] == "buscar"
                and method == "POST"
            ):
                try:
                    consult_id = int(parts[3])
                except ValueError:
                    self._send(404, {"error": "Consulta não encontrada."})
                    return
                self._consulta_retry(conn, actor, consult_id)
                return
            parts = path.split("/")
            if len(parts) == 5 and parts[1] == "api" and parts[2] == "users" and method == "POST":
                try:
                    user_id = int(parts[3])
                except ValueError:
                    self._send(404, {"error": "Usuário não encontrado."})
                    return
                action = parts[4]
                if action == "role":
                    self._set_role(conn, actor, user_id, data)
                elif action == "active":
                    self._set_active(conn, actor, user_id, data)
                elif action == "password":
                    self._set_password(conn, actor, user_id, data)
                elif action == "access":
                    self._set_access(conn, actor, user_id, data)
                else:
                    self._send(404, {"error": "Não encontrado."})
                return
            self._send(404, {"error": "Não encontrado."})
        finally:
            conn.close()

    def _login(self, conn, data):
        username = str(data.get("username", "")).strip().lower()
        password = str(data.get("password", ""))
        row = conn.execute("SELECT * FROM users WHERE username = ?", (username,)).fetchone()
        if row is None or not password_ok(password, row["salt"], row["password_hash"]):
            self._send(401, {"error": "Usuário ou senha incorretos."})
            return
        if not row["active"]:
            self._send(403, {"error": "Este usuário está desativado."})
            return
        if not row["email_confirmed"]:
            self._send(
                403,
                {
                    "error": "Confirme o e-mail para liberar a conta. Olhe a caixa de entrada e o spam.",
                    "pending": True,
                    "email": mask_email(row["email"]),
                },
            )
            return
        if not int(row["trial_ends_at"] or 0) and row["role"] != "admin":
            conn.execute(
                "UPDATE users SET trial_ends_at = ? WHERE id = ?",
                (int(time.time()) + TRIAL_DAYS * DAY, row["id"]),
            )
            row = conn.execute("SELECT * FROM users WHERE id = ?", (row["id"],)).fetchone()
        token = secrets.token_urlsafe(32)
        conn.execute(
            "INSERT INTO sessions(token, user_id, expires_at) VALUES (?, ?, ?)",
            (token, row["id"], int(time.time()) + SESSION_SECONDS),
        )
        conn.commit()
        self._send(200, {"token": token, "user": public_user(row)})

    def _signup(self, conn, data):
        """Conta nova fica parada até a pessoa confirmar o e-mail."""
        recent = conn.execute(
            "SELECT COUNT(*) AS n FROM users WHERE created_at > ?",
            (int(time.time()) - 3600,),
        ).fetchone()["n"]
        if recent >= 40:
            self._send(429, {"error": "Muitas contas criadas agora. Tente de novo em alguns minutos."})
            return
        username = str(data.get("username", "")).strip().lower()
        name = str(data.get("name", "")).strip()
        email = str(data.get("email", "")).strip().lower()
        password = str(data.get("password", ""))
        if not USERNAME.fullmatch(username):
            self._send(400, {"error": "Usuário: 3 a 32 letras, números, ponto ou _."})
            return
        if not name or len(name) > 80:
            self._send(400, {"error": "Informe o nome."})
            return
        if not EMAIL.fullmatch(email) or len(email) > 120:
            self._send(400, {"error": "Informe um e-mail válido."})
            return
        if not password or len(password) < 6:
            self._send(400, {"error": "A senha precisa ter pelo menos 6 caracteres."})
            return
        taken = conn.execute("SELECT id FROM users WHERE email = ?", (email,)).fetchone()
        if taken is not None:
            self._send(409, {"error": "Já existe uma conta com esse e-mail."})
            return
        now = int(time.time())
        salt, digest = hash_password(password)
        try:
            cur = conn.execute(
                """
                INSERT INTO users(
                  username, name, email, role, salt, password_hash, active, created_at, trial_ends_at, email_confirmed
                ) VALUES (?, ?, ?, 'comum', ?, ?, 1, ?, ?, 0)
                """,
                (username, name, email, salt, digest, now, 0),
            )
        except sqlite3.IntegrityError:
            self._send(409, {"error": "Já existe um usuário com esse login."})
            return
        token = issue_email_confirmation(conn, cur.lastrowid, now)
        if token is None:
            conn.rollback()
            self._send(429, {"error": "Muitos e-mails pedidos. Espere um pouco e tente de novo."})
            return
        try:
            send_confirmation_mail(email, name, token)
        except MailError:
            conn.rollback()
            self._send(502, {"error": "Não foi possível enviar o e-mail. Tente de novo."})
            return
        conn.commit()
        self._send(200, {"pending": True, "email": mask_email(email)})

    def _resend_confirmation(self, conn, data):
        username = str(data.get("username", "")).strip().lower()
        password = str(data.get("password", ""))
        row = conn.execute("SELECT * FROM users WHERE username = ?", (username,)).fetchone()
        if row is None or not password_ok(password, row["salt"], row["password_hash"]):
            self._send(401, {"error": "Usuário ou senha incorretos."})
            return
        if row["email_confirmed"]:
            self._send(400, {"error": "Esta conta já está liberada. Entre normalmente."})
            return
        token = issue_email_confirmation(conn, row["id"])
        if token is None:
            self._send(429, {"error": "Muitos e-mails pedidos. Espere um pouco e tente de novo."})
            return
        try:
            send_confirmation_mail(row["email"], row["name"], token)
        except MailError:
            conn.rollback()
            self._send(502, {"error": "Não foi possível enviar o e-mail. Tente de novo."})
            return
        conn.commit()
        self._send(200, {"sent": True, "email": mask_email(row["email"])})

    def _confirm_email(self, conn, token):
        row = take_email_confirmation(conn, token)
        if row is None:
            self._send_html(400, confirmation_page(False))
            return
        self._send_html(200, confirmation_page(True, row["name"]))

    def _require_admin(self, actor):
        if actor["role"] != "admin":
            self._send(403, {"error": "Só um administrador pode fazer isso."})
            return False
        return True

    def _list_users(self, conn, actor):
        if not self._require_admin(actor):
            return
        rows = conn.execute("SELECT id, username, name, email, role, active, created_at, trial_ends_at, paid_until, plan FROM users ORDER BY name").fetchall()
        self._send(200, {"users": [public_user(row) for row in rows]})

    def _create_user(self, conn, actor, data):
        if not self._require_admin(actor):
            return
        username = str(data.get("username", "")).strip().lower()
        name = str(data.get("name", "")).strip()
        password = str(data.get("password", ""))
        role = str(data.get("role", "comum"))
        if not USERNAME.fullmatch(username):
            self._send(400, {"error": "Usuário: 3 a 32 letras, números, ponto ou _."})
            return
        if not name or len(name) > 80:
            self._send(400, {"error": "Informe o nome."})
            return
        if len(password) < 6:
            self._send(400, {"error": "A senha precisa ter pelo menos 6 caracteres."})
            return
        if role not in ("admin", "comum"):
            self._send(400, {"error": "Nível de acesso inválido."})
            return
        salt, digest = hash_password(password)
        try:
            cur = conn.execute(
                """
                INSERT INTO users(username, name, role, salt, password_hash, active, created_at, trial_ends_at)
                VALUES (?, ?, ?, ?, ?, 1, ?, ?)
                """,
                (username, name, role, salt, digest, int(time.time()), int(time.time()) + TRIAL_DAYS * DAY),
            )
            conn.commit()
        except sqlite3.IntegrityError:
            self._send(409, {"error": "Já existe um usuário com esse login."})
            return
        row = conn.execute(
            "SELECT id, username, name, email, role, active, created_at, trial_ends_at, paid_until, plan FROM users WHERE id = ?",
            (cur.lastrowid,),
        ).fetchone()
        self._send(200, {"user": public_user(row)})

    def _set_role(self, conn, actor, user_id, data):
        if not self._require_admin(actor):
            return
        role = str(data.get("role", ""))
        if role not in ("admin", "comum"):
            self._send(400, {"error": "Nível de acesso inválido."})
            return
        row = conn.execute("SELECT id, role FROM users WHERE id = ?", (user_id,)).fetchone()
        if row is None:
            self._send(404, {"error": "Usuário não encontrado."})
            return
        if row["role"] == "admin" and role != "admin":
            admins = conn.execute("SELECT COUNT(*) AS n FROM users WHERE role = 'admin' AND active = 1").fetchone()["n"]
            if admins <= 1:
                self._send(400, {"error": "Precisa continuar existindo um administrador."})
                return
        conn.execute("UPDATE users SET role = ? WHERE id = ?", (role, user_id))
        conn.commit()
        self._send(200, {"ok": True})

    def _set_active(self, conn, actor, user_id, data):
        if not self._require_admin(actor):
            return
        if actor["id"] == user_id:
            self._send(400, {"error": "Você não pode desativar a própria conta."})
            return
        active = 1 if data.get("active") else 0
        row = conn.execute("SELECT id, role, active FROM users WHERE id = ?", (user_id,)).fetchone()
        if row is None:
            self._send(404, {"error": "Usuário não encontrado."})
            return
        if row["role"] == "admin" and row["active"] and not active:
            admins = conn.execute("SELECT COUNT(*) AS n FROM users WHERE role = 'admin' AND active = 1").fetchone()["n"]
            if admins <= 1:
                self._send(400, {"error": "Precisa continuar existindo um administrador."})
                return
        conn.execute("UPDATE users SET active = ? WHERE id = ?", (active, user_id))
        if not active:
            conn.execute("DELETE FROM sessions WHERE user_id = ?", (user_id,))
        conn.commit()
        self._send(200, {"ok": True})

    def _get_settings(self, conn, actor):
        rows = conn.execute("SELECT key, value FROM user_settings WHERE user_id = ?", (actor["id"],)).fetchall()
        self._send(200, {"settings": {row["key"]: row["value"] for row in rows}})

    def _subscribe(self, conn, actor, data):
        """Abre o checkout do Mercado Pago para o plano e o prazo escolhidos."""
        plan = str(data.get("plan", "")).strip()
        period = str(data.get("period", "mes")).strip()
        if offer_of(plan, period) is None:
            self._send(400, {"error": "Plano inválido."})
            return
        if not mp_token():
            self._send(503, {"error": "O checkout do Mercado Pago ainda não está configurado."})
            return
        conn.execute(
            "INSERT INTO subscription_requests(user_id, plan, created_at) VALUES (?, ?, ?)",
            (actor["id"], plan, int(time.time())),
        )
        conn.commit()
        try:
            preference = mp_json(
                "POST",
                "/checkout/preferences",
                build_preference(actor["id"], plan, period, actor["email"] if "email" in actor.keys() else ""),
            )
        except MercadoPagoError:
            self._send(502, {"error": "Não foi possível abrir o checkout do Mercado Pago."})
            return
        link = checkout_url(preference)
        if not link:
            self._send(502, {"error": "O Mercado Pago não devolveu o checkout."})
            return
        self._send(200, {"requested": True, "checkout_url": link, "message": ""})

    def _mercadopago_webhook(self, conn, data, query):
        """Confirma o pagamento na API do Mercado Pago e libera o acesso."""
        payment_id = ""
        kind = str(data.get("type") or data.get("topic") or "")
        if kind == "payment":
            inner = data.get("data")
            if isinstance(inner, dict) and inner.get("id") is not None:
                payment_id = str(inner.get("id"))
            elif data.get("id") is not None:
                payment_id = str(data.get("id"))
        if not payment_id:
            topic = (query.get("type") or query.get("topic") or [""])[0]
            if topic == "payment":
                payment_id = (query.get("data.id") or query.get("id") or [""])[0]
        if not payment_id or not mp_token():
            self._send(200, {"ok": True})
            return
        try:
            payment = mp_json("GET", f"/v1/payments/{urllib.parse.quote(payment_id)}")
        except MercadoPagoError:
            self._send(500, {"error": "Não foi possível confirmar o pagamento."})
            return
        ref = str(payment.get("external_reference") or "")
        if ref.startswith("consulta:"):
            apply_consulta_payment(conn, payment)
        else:
            apply_approved_payment(conn, payment)
        self._send(200, {"ok": True})

    def _list_requests(self, conn, actor):
        if not self._require_admin(actor):
            return
        rows = conn.execute(
            """
            SELECT r.id, r.plan, r.created_at, r.status, u.name, u.username
            FROM subscription_requests r
            JOIN users u ON u.id = r.user_id
            ORDER BY r.created_at DESC
            LIMIT 200
            """
        ).fetchall()
        self._send(
            200,
            {
                "requests": [
                    {
                        "id": row["id"],
                        "plan": row["plan"],
                        "plan_label": PLANS.get(row["plan"], {}).get("label", row["plan"]),
                        "created_at": row["created_at"],
                        "status": row["status"],
                        "name": row["name"],
                        "username": row["username"],
                    }
                    for row in rows
                ]
            },
        )

    def _set_access(self, conn, actor, user_id, data):
        """Libera ou encerra o acesso de alguém (usado depois de confirmar o pagamento)."""
        if not self._require_admin(actor):
            return
        row = conn.execute("SELECT id FROM users WHERE id = ?", (user_id,)).fetchone()
        if row is None:
            self._send(404, {"error": "Usuário não encontrado."})
            return
        days = data.get("days", 0)
        try:
            days = int(days)
        except (TypeError, ValueError):
            self._send(400, {"error": "Informe os dias."})
            return
        if days < 0 or days > 3650:
            self._send(400, {"error": "Dias inválidos."})
            return
        plan = str(data.get("plan", "")).strip()
        current = conn.execute("SELECT paid_until FROM users WHERE id = ?", (user_id,)).fetchone()["paid_until"]
        base = max(int(current or 0), int(time.time()))
        paid_until = base + days * DAY if days else 0
        conn.execute(
            "UPDATE users SET paid_until = ?, plan = ? WHERE id = ?",
            (paid_until, plan if days else "", user_id),
        )
        conn.execute(
            "UPDATE subscription_requests SET status = 'concluido' WHERE user_id = ? AND status = 'pendente'",
            (user_id,),
        )
        conn.commit()
        fresh = conn.execute(
            "SELECT id, username, name, email, role, active, created_at, trial_ends_at, paid_until, plan FROM users WHERE id = ?",
            (user_id,),
        ).fetchone()
        self._send(200, {"user": public_user(fresh)})
    def _save_settings(self, conn, actor, data):
        changes = data.get("settings")
        if not isinstance(changes, dict):
            self._send(400, {"error": "Pedido inválido."})
            return
        for key, value in changes.items():
            if not isinstance(key, str) or not SETTING_KEY.match(key):
                self._send(400, {"error": "Configuração desconhecida."})
                return
            if value is not None and (not isinstance(value, str) or len(value) > SETTING_VALUE_MAX):
                self._send(400, {"error": "Valor inválido."})
                return
        existing = {
            row["key"]
            for row in conn.execute("SELECT key FROM user_settings WHERE user_id = ?", (actor["id"],)).fetchall()
        }
        final = (existing | {k for k, v in changes.items() if v is not None}) - {
            k for k, v in changes.items() if v is None
        }
        if len(final) > SETTINGS_MAX:
            self._send(400, {"error": "Configurações demais."})
            return
        for key, value in changes.items():
            if value is None:
                conn.execute("DELETE FROM user_settings WHERE user_id = ? AND key = ?", (actor["id"], key))
            else:
                conn.execute(
                    """
                    INSERT INTO user_settings(user_id, key, value) VALUES (?, ?, ?)
                    ON CONFLICT(user_id, key) DO UPDATE SET value = excluded.value
                    """,
                    (actor["id"], key, value),
                )
        conn.commit()
        self._send(200, {"ok": True})

    def _get_account(self, conn, actor):
        row = conn.execute(
            "SELECT revision, updated_at, payload FROM account_data WHERE user_id = ?",
            (actor["id"],),
        ).fetchone()
        if row is None:
            self._send(200, {"revision": 0, "updated_at": 0, "data": None})
            return
        try:
            data = json.loads(row["payload"])
        except json.JSONDecodeError:
            data = None
        self._send(200, {"revision": row["revision"], "updated_at": row["updated_at"], "data": data})

    def _save_account(self, conn, actor, data):
        payload = data.get("data")
        base = data.get("base")
        if isinstance(base, bool) or not isinstance(base, int):
            self._send(400, {"error": "Pedido inválido."})
            return
        status, revision, updated, current = store_account(conn, actor["id"], base, payload, int(time.time()))
        if status == "invalid":
            self._send(400, {"error": "Pedido inválido."})
            return
        if status == "too_big":
            self._send(413, {"error": "Os dados passaram do limite."})
            return
        if status == "conflict":
            self._send(
                409,
                {
                    "error": "Os dados mudaram em outro aparelho.",
                    "revision": revision,
                    "updated_at": updated,
                    "data": current,
                },
            )
            return
        conn.commit()
        self._send(200, {"revision": revision, "updated_at": updated})

    def _update_profile(self, conn, actor, data):
        name = str(data.get("name", "")).strip()
        if not name or len(name) > 80:
            self._send(400, {"error": "Informe o nome."})
            return
        conn.execute("UPDATE users SET name = ? WHERE id = ?", (name, actor["id"]))
        conn.commit()
        row = conn.execute(
            "SELECT id, username, name, email, role, active, created_at, trial_ends_at, paid_until, plan FROM users WHERE id = ?",
            (actor["id"],),
        ).fetchone()
        self._send(200, {"user": public_user(row)})

    def _cancel_subscription(self, conn, actor):
        fresh, message = cancel_subscription(conn, actor["id"])
        if fresh is None:
            self._send(400, {"error": message})
            return
        self._send(200, {"user": public_user(fresh)})

    def _password_code(self, conn, actor, data):
        row = conn.execute("SELECT id, email, salt, password_hash FROM users WHERE id = ?", (actor["id"],)).fetchone()
        if row is None:
            self._send(404, {"error": "Usuário não encontrado."})
            return
        masked, message, status = start_password_change(
            conn,
            row,
            data.get("current", ""),
            data.get("password", ""),
            send_password_code,
        )
        if masked is None:
            self._send(status, {"error": message})
            return
        self._send(200, {"sent": True, "email": masked})

    def _set_password(self, conn, actor, user_id, data):
        if actor["id"] != user_id and actor["role"] != "admin":
            self._send(403, {"error": "Só um administrador pode alterar a senha de outra pessoa."})
            return
        password = str(data.get("password", ""))
        if len(password) < 6:
            self._send(400, {"error": "A senha precisa ter pelo menos 6 caracteres."})
            return
        row = conn.execute(
            "SELECT id, email, salt, password_hash FROM users WHERE id = ?",
            (user_id,),
        ).fetchone()
        if row is None:
            self._send(404, {"error": "Usuário não encontrado."})
            return
        if actor["id"] == user_id:
            email = str(row["email"] or "").strip().lower()
            if EMAIL.fullmatch(email):
                ok, message = take_password_code(conn, user_id, data.get("code"), password)
                if not ok:
                    self._send(400, {"error": message})
                    return
            elif not password_ok(str(data.get("current", "")), row["salt"], row["password_hash"]):
                self._send(400, {"error": "Senha atual incorreta."})
                return
        salt, digest = hash_password(password)
        conn.execute("UPDATE users SET salt = ?, password_hash = ? WHERE id = ?", (salt, digest, user_id))
        keep = ""
        if actor["id"] == user_id:
            keep = self.headers.get("Authorization", "")[7:].strip()
        end_other_sessions(conn, user_id, keep)
        conn.commit()
        self._send(200, {"ok": True})

    def _consultas_get(self, conn, actor, query):
        ident = (query.get("id") or [""])[0]
        if ident:
            if not str(ident).isdigit():
                self._send(404, {"error": "Consulta não encontrada."})
                return
            row = conn.execute(
                "SELECT * FROM consultations WHERE id = ? AND user_id = ?",
                (int(ident), actor["id"]),
            ).fetchone()
            if row is None:
                self._send(404, {"error": "Consulta não encontrada."})
                return
            row = sync_consulta_payment(conn, row)
            row = resume_consulta(conn, row)
            self._send(200, {"consulta": consulta_row(row, with_result=True)})
            return
        rows = conn.execute(
            """
            SELECT * FROM consultations
            WHERE user_id = ?
            ORDER BY created_at DESC
            LIMIT 100
            """,
            (actor["id"],),
        ).fetchall()
        self._send(
            200,
            {
                "provider": bool(consulta_token()),
                "products": consulta_catalog(),
                "history": [consulta_row(row) for row in rows],
            },
        )

    def _consulta_create(self, conn, actor, data):
        prepared, message = prepare_consulta(data.get("slug"), data.get("document"), data.get("search_type"))
        if prepared is None:
            self._send(400, {"error": message})
            return
        if not consulta_token():
            self._send(503, {"error": "As consultas ainda não estão ligadas ao fornecedor. O pagamento não foi aberto."})
            return
        if not mp_token():
            self._send(503, {"error": "O checkout do Mercado Pago ainda não está configurado."})
            return
        now = int(time.time())
        cur = conn.execute(
            """
            INSERT INTO consultations(user_id, type_slug, search_type, document, amount_cents, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
            """,
            (actor["id"], prepared["slug"], prepared["search_type"], prepared["document"], prepared["cents"], now),
        )
        conn.commit()
        consult_id = cur.lastrowid
        email = actor["email"] if "email" in actor.keys() else ""
        try:
            preference = mp_json(
                "POST",
                "/checkout/preferences",
                build_consulta_preference(consult_id, prepared["title"], prepared["cents"], email),
            )
        except MercadoPagoError:
            self._send(502, {"error": "Não foi possível abrir o checkout do Mercado Pago."})
            return
        link = checkout_url(preference)
        if not link:
            self._send(502, {"error": "O Mercado Pago não devolveu o checkout."})
            return
        self._send(200, {"id": consult_id, "checkout_url": link})

    def _consulta_retry(self, conn, actor, consult_id):
        row = conn.execute(
            "SELECT * FROM consultations WHERE id = ? AND user_id = ?",
            (consult_id, actor["id"]),
        ).fetchone()
        if row is None:
            self._send(404, {"error": "Consulta não encontrada."})
            return
        if not row["mp_id"] or row["status"] == "aguardando":
            self._send(400, {"error": "Esta consulta ainda não foi paga."})
            return
        if row["status"] == "paga":
            finish_consulta(conn, row)
            row = conn.execute("SELECT * FROM consultations WHERE id = ?", (consult_id,)).fetchone()
        self._send(200, {"consulta": consulta_row(row, with_result=True)})

    def _send(self, code, payload):
        body = json.dumps(payload, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _send_html(self, code, page):
        body = page.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(body)


def main():
    conn = connect()
    try:
        ensure_schema(conn)
    finally:
        conn.close()
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
