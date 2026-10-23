#!/usr/bin/env bash
# Build multi-stage da TechNova API e push para o Amazon ECR.
# Uso: ./ecr-push.sh
# Tags: sha-XXXXXXX e latest sempre; 1.2.3, 1.2 e 1 se o commit tiver git tag vX.Y.Z.
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
REPO_NAME="${REPO_NAME:-technova-api}"

cd "$(dirname "$0")"

echo "==> Identificando conta AWS"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text --region "$AWS_REGION")"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE="${REGISTRY}/${REPO_NAME}"
echo "    registry: ${REGISTRY}"

echo "==> Garantindo repositorio ${REPO_NAME} (idempotente)"
# describe falha se o repo nao existe; so entao criamos
if aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "    ja existe, nada a fazer"
else
  aws ecr create-repository --repository-name "$REPO_NAME" --region "$AWS_REGION" \
    --image-scanning-configuration scanOnPush=true >/dev/null
  echo "    criado (scan on push ligado)"
fi

echo "==> Aplicando lifecycle policy (substitui a anterior, entao e idempotente)"
aws ecr put-lifecycle-policy --repository-name "$REPO_NAME" --region "$AWS_REGION" \
  --lifecycle-policy-text file://lifecycle-policy.json >/dev/null
echo "    sem tag > 7 dias e sha-* alem das 20 mais recentes expiram"

echo "==> Login no ECR"
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

echo "==> Calculando tags"
SHA_TAG="sha-$(git rev-parse --short=7 HEAD)"
TAGS=("$SHA_TAG" "latest")

# Semver so se o commit atual tiver uma tag vX.Y.Z
GIT_TAG="$(git describe --tags --exact-match --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || true)"
if [[ "$GIT_TAG" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"; MINOR="${BASH_REMATCH[2]}"; PATCH="${BASH_REMATCH[3]}"
  TAGS+=("${MAJOR}.${MINOR}.${PATCH}" "${MAJOR}.${MINOR}" "${MAJOR}")
else
  echo "    (sem git tag v*.*.* neste commit: pulando tags semver)"
fi
printf '    - %s\n' "${TAGS[@]}"

echo "==> Build"
TAG_ARGS=()
for t in "${TAGS[@]}"; do TAG_ARGS+=(-t "${IMAGE}:${t}"); done
docker build -q "${TAG_ARGS[@]}" . >/dev/null

echo "==> Push"
# -q: imprime so a referencia final (sem o log de cada camada)
for t in "${TAGS[@]}"; do docker push -q "${IMAGE}:${t}"; done

echo "==> Concluido. Imagem publicada em ${IMAGE}"
echo "    Rollback: docker pull ${IMAGE}:<tag>"
