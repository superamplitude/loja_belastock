#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/superamplitude/loja_belastock"
RUNNER_DIR="/opt/actions-runner-belastock-loja"
RUNNER_VERSION="2.337.0"
RUNNER_NAME="belastock-loja-$(hostname -s)"
RUNNER_LABEL="belastock-loja"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Execute como root: sudo bash $0"
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
    echo "Arquitetura não suportada automaticamente: $(uname -m)"
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
  echo "Runner já configurado em ${RUNNER_DIR}."
  if [[ -x ./svc.sh ]]; then
    ./svc.sh start || true
    ./svc.sh status || true
  fi
  exit 0
fi

printf "Cole o NOVO token de registro do runner do GitHub e pressione Enter: "
read -r -s RUNNER_TOKEN
echo
if [[ -z "${RUNNER_TOKEN}" ]]; then
  echo "Token vazio. Abortando sem alterar a configuração."
  exit 1
fi

export RUNNER_ALLOW_RUNASROOT=1

echo "[3/5] Registrando runner exclusivo da loja..."
./config.sh \
  --unattended \
  --url "${REPO_URL}" \
  --token "${RUNNER_TOKEN}" \
  --name "${RUNNER_NAME}" \
  --labels "${RUNNER_LABEL}" \
  --work "_work" \
  --replace
unset RUNNER_TOKEN

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
