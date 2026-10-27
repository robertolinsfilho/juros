"""Roda os testes e publica o site.

Uso: python tool/publicar.py "mensagem do commit"

O que faz:
  1. flutter analyze e flutter test (se falhar, não publica).
  2. Commita as alterações e envia para a branch main.
  3. O GitHub Actions compila o site e publica na branch site.
  4. O servidor busca a branch site sozinho, em até um minuto.

A mensagem do commit é obrigatória para não publicar sem descrição.
"""

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FLUTTER = os.path.join(os.environ.get("LOCALAPPDATA", ""), "flutter", "bin")
AUTHOR = ("Roberto Lins", "36731226+robertolinsfilho@users.noreply.github.com")


def run(command, **kwargs):
    print("+", " ".join(command))
    env = os.environ.copy()
    env["PATH"] = FLUTTER + os.pathsep + env.get("PATH", "")
    env["GIT_AUTHOR_NAME"], env["GIT_AUTHOR_EMAIL"] = AUTHOR
    env["GIT_COMMITTER_NAME"], env["GIT_COMMITTER_EMAIL"] = AUTHOR
    result = subprocess.run(command, cwd=ROOT, env=env, **kwargs)
    if result.returncode != 0:
        raise SystemExit(f"falhou: {' '.join(command)}")
    return result


def main():
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        raise SystemExit('informe a mensagem do commit: python tool/publicar.py "o que mudou"')
    message = sys.argv[1].strip()

    run(["flutter", "analyze", "--no-fatal-infos"])
    run(["flutter", "test"])

    pending = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT, capture_output=True, text=True)
    if pending.stdout.strip():
        run(["git", "add", "-A"])
        run(["git", "commit", "-m", message])
    else:
        print("nada novo para commitar")

    ahead = subprocess.run(
        ["git", "rev-list", "--count", "origin/main..HEAD"], cwd=ROOT, capture_output=True, text=True
    )
    if ahead.stdout.strip() not in ("", "0"):
        run(["git", "push", "origin", "main"])
    else:
        print("main já está atualizada")

    print("enviado. O GitHub compila e o servidor atualiza sozinho em até um minuto.")


if __name__ == "__main__":
    main()
