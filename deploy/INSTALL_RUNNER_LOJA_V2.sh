#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/superamplitude/loja_belastock"
RUNNER_DIR="/opt/actions-runner-belastock-loja"
RUNNER_VERSION="2.337.0"
RUNNER_NAME="belastock-loja-$(hostname -s)"
RUNNER_LABEL="belastock-loja"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Execute como root."
  exit 1
fi

case "$(uname -m)" in
  x86_64|amd64)
    ARCH="x64"
    SHA256="70920811a4f8ad4328818682bca5c6469c1c942fab52448868071d0063816613"
    ;;
  aarch64|arm64)
    ARCH="arm64"
    SHA256="9b1dc70626422526e3c94767cf024896beb15da5342a3f4819bf2feac13e0393"
    ;;
  *)
    echo "Arquitetura não suportada: $(uname -m)"
    exit 1
    ;;
esac

PKG="actions-runner-linux-${ARCH}-${RUNNER_VERSION}.tar.gz"
URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${PKG}"

mkdir -p "${RUNNER_DIR}"
cd "${RUNNER_DIR}"

if [[ ! -x ./config.sh ]]; then
  echo "[1/5] Baixando GitHub Actions Runner v${RUNNER_VERSION} (${ARCH})..."
  curl -fL --retry 3 --retry-delay 2 -o "${PKG}" "${URL}"
  echo "${SHA256}  ${PKG}" | sha256sum -c -
  tar xzf "${PKG}"
  rm -f "${PKG}"
else
  echo "[1/5] Runner já extraído em ${RUNNER_DIR}."
fi

if ./bin/Runner.Listener --version >/dev/null 2>&1; then
  echo "[2/5] Dependências já estão OK. Nada será reinstalado."
elif [[ -x ./bin/installdependencies.sh ]]; then
  echo "[2/5] Instalando dependências necessárias..."
  ./bin/installdependencies.sh || true
  ./bin/Runner.Listener --version >/dev/null 2>&1 || {
    echo "ERRO: dependências do runner ainda não estão válidas."
    exit 1
  }
fi

if [[ -f .runner ]]; then
  echo "Runner já configurado. Garantindo serviço ativo..."
  ./svc.sh start || true
  ./svc.sh status || true
  exit 0
fi

if [[ ! -r /dev/tty ]]; then
  echo "ERRO: /dev/tty indisponível."
  exit 1
fi

export RUNNER_ALLOW_RUNASROOT=1

while [[ ! -f .runner ]]; do
  RUNNER_TOKEN=""

  while :; do
    echo "" > /dev/tty
    echo "============================================================" > /dev/tty
    echo " COLE O TOKEN REAL GERADO PELO GITHUB" > /dev/tty
    echo " GitHub > loja_belastock > Settings > Actions > Runners" > /dev/tty
    echo " > New self-hosted runner" > /dev/tty
    echo " O token e temporario e expira em cerca de 1 hora." > /dev/tty
    echo " Pode colar somente o token ou o comando completo com --token." > /dev/tty
    echo "============================================================" > /dev/tty
    printf "TOKEN: " > /dev/tty
    IFS= read -r -s RUNNER_TOKEN < /dev/tty || true
    printf "\n" > /dev/tty

    RUNNER_TOKEN="${RUNNER_TOKEN//$'\r'/}"

    if [[ "${RUNNER_TOKEN}" == *"--token"* ]]; then
      PARSED_TOKEN="$(printf '%s\n' "${RUNNER_TOKEN}" | sed -nE 's/.*--token[[:space:]]+([^[:space:]\\]+).*/\1/p' | head -n1)"
      if [[ -n "${PARSED_TOKEN}" ]]; then
        RUNNER_TOKEN="${PARSED_TOKEN}"
      fi
      unset PARSED_TOKEN
    fi

    UPPER_TOKEN="$(printf '%s' "${RUNNER_TOKEN}" | tr '[:lower:]' '[:upper:]')"
    if [[ -z "${RUNNER_TOKEN}" ]]; then
      echo "ERRO: nenhum token foi colado. Tente novamente." > /dev/tty
      continue
    fi
    if [[ "${UPPER_TOKEN}" == "TOKEN" || "${UPPER_TOKEN}" == "NOVO_TOKEN" || "${UPPER_TOKEN}" == "SEU_TOKEN" || "${UPPER_TOKEN}" == "TOKEN_NOVO_DO_GITHUB" ]]; then
      echo "ERRO: isso e apenas um texto de exemplo, nao o token real do GitHub." > /dev/tty
      continue
    fi
    if (( ${#RUNNER_TOKEN} < 20 )); then
      echo "ERRO: token curto demais (${#RUNNER_TOKEN} caracteres). O token real e bem maior." > /dev/tty
      continue
    fi
    break
  done

  echo "Token recebido (${#RUNNER_TOKEN} caracteres). Conteudo oculto."
  echo "[3/5] Registrando runner exclusivo da loja..."

  if ./config.sh \
      --unattended \
      --url "${REPO_URL}" \
      --token "${RUNNER_TOKEN}" \
      --name "${RUNNER_NAME}" \
      --labels "${RUNNER_LABEL}" \
      --work "_work" \
      --replace; then
    unset RUNNER_TOKEN UPPER_TOKEN
    break
  fi

  unset RUNNER_TOKEN UPPER_TOKEN
  echo "" > /dev/tty
  echo "Falha ao registrar. O token pode estar incorreto ou expirado." > /dev/tty
  echo "Gere um NOVO token no GitHub e tente novamente nesta mesma tela." > /dev/tty
done

echo "[4/5] Instalando serviço systemd..."
./svc.sh install root

echo "[5/5] Iniciando serviço..."
./svc.sh start
sleep 2
./svc.sh status

echo
echo "============================================================"
echo " RUNNER BELA STOCK LOJA INSTALADO"
echo " Nome:   ${RUNNER_NAME}"
echo " Label:  ${RUNNER_LABEL}"
echo " Pasta:  ${RUNNER_DIR}"
echo " Repo:   ${REPO_URL}"
echo "============================================================"
