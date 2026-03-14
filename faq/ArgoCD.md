# ArgoCD — установка и настройка (GitOps)

---

# 1) Установить Argo CD в namespace `argocd`

```bash
kubectl create ns argocd

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

helm upgrade --install argocd argo/argo-cd \
  -n argocd \
  --set crds.install=true \
  --set configs.params."server\.insecure"=true
```

## Проверка

```bash
kubectl -n argocd get pods
kubectl -n argocd get svc
```

---

# 2) Создать ingress для ArgoCD

Создать / открыть файл:

```bash
vim argocd/ingress/argocd-ingress.yaml
```

Содержимое — смотри в проекте.

Применить:

```bash
kubectl apply -f argocd/ingress/argocd-ingress.yaml
kubectl -n argocd get ingress
```

---

# Проверка из Windows

Уже добавлена hosts запись:

```
172.21.106.163	argocd.selm.ag.192.168.49.2.nip.io
```

Открой в браузере на хосте с Windows:

```
http://argocd.selm.ag.192.168.49.2.nip.io
```

Логин по умолчанию:

```
admin
```

Получить пароль:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo
```

---

# 4) Подключаем репозиторий в ArgoCD по SSH

Твой `repoURL` и ветка.

Пример:

```
repoURL: git@github.com:gitueser/sc24_with_docker_compose.git
targetRevision: kubernetes-test-helm
```

---

# 4.1 Сгенерировать SSH ключ

```bash
ssh-keygen -t ed25519 -C "argocd@selmag" -f /tmp/argocd_repo_key -N ""
cat /tmp/argocd_repo_key.pub
```

Содержимое `.pub` добавить в GitHub:

```
Repo → Settings → Deploy keys → Add deploy key → Read-only
```

---

# 4.2 Создать secret репозитория в ArgoCD

```bash
kubectl -n argocd create secret generic repo-sc24 \
  --from-literal=type=git \
  --from-literal=url=git@github.com:gitueser/sc24_with_docker_compose.git \
  --from-file=sshPrivateKey=/tmp/argocd_repo_key \
  --dry-run=client -o yaml | \
  kubectl label -f - --local argocd.argoproj.io/secret-type=repository -o yaml | \
  kubectl apply -f -
```

---

# 5) Делаем app-of-apps (root + child) в репозитории

Создай файлы:

## 5.1 root приложение

```bash
vim argocd/apps/root.yaml
```

Содержимое смотри в проекте.

## 5.2 child приложение

```bash
vim argocd/apps/selmag.yaml
```

Содержимое смотри в проекте.

---

# 5.3 Закоммитить и запушить

```bash
git status
git add argocd/
git commit -m "Add ArgoCD bootstrap (ingress + app-of-apps)"
git push origin kubernetes-test-helm
```

---

# 5.4 Применить root app (bootstrap)

```bash
kubectl apply -f argocd/apps/root.yaml
```

После этого ArgoCD сам подхватит `selmag` из:

```
argocd/apps/selmag.yaml
```

---

# 6) Observability on/off

Best practice для текущего чарта:

- оставить **один selmag app**
- когда нужно `obs-on` — меняешь `valueFiles` в:

```
argocd/apps/selmag.yaml
```

```yaml
valueFiles:
  - values.yaml
  - values-observability.yaml
```

Коммит → push → ArgoCD сам применит.

Это будет ровно как `make obs-on`, только через **GitOps**.

---

# Секреты по best practice

Используем **SealedSecrets** вместо plaintext `.env.secret`.

Для minikube это самый практичный стандарт:

- в Git лежит **зашифрованный SealedSecret**
- контроллер в кластере расшифровывает его и создаёт обычный Secret

---

# 1. Установить SealedSecrets controller

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

kubectl create ns sealed-secrets

helm upgrade --install sealed-secrets bitnami/sealed-secrets \
  -n sealed-secrets
```

## Проверка

```bash
kubectl -n sealed-secrets get pods
kubectl get crd | grep sealedsecrets
```

---

# 2. Установка kubeseal CLI в WSL2

Без дополнительных пакетных менеджеров.

## 2.1 Поставить базовые утилиты

```bash
sudo apt-get update
sudo apt-get install -y curl tar
```

---

## 2.2 Скачать kubeseal

```bash
KUBESEAL_VERSION="0.36.0"

curl -fL -o kubeseal.tar.gz \
"https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"

tar -xzf kubeseal.tar.gz kubeseal

sudo install -m 755 kubeseal /usr/local/bin/kubeseal

rm -f kubeseal kubeseal.tar.gz
```

Проверка:

```bash
kubeseal --version
which kubeseal
```

---

# 3. (Опционально) забрать публичный сертификат контроллера

```bash
kubeseal \
  --controller-name=sealed-secrets \
  --controller-namespace=sealed-secrets \
  --fetch-cert > sealed-secrets-cert.pem
```

---

# 4. Сгенерировать SealedSecret из текущего `.env.secret`

Это актуально для моего случая, так как secret создавался раньше по‑другому.

```bash
kubectl -n selmag-helm create secret generic selmag-secret \
  --from-env-file=helm/selmag/files/.env.secret \
  --dry-run=client -o yaml > /tmp/selmag-secret.yaml
```

## 4.1 Запечатать его

```bash
kubeseal \
  --format yaml \
  --namespace selmag-helm \
  --name selmag-secret \
  --cert sealed-secrets-cert.pem \
  < /tmp/selmag-secret.yaml \
  > helm/selmag/templates/selmag-secret-sealed.yaml
```

---

# 5. Отключить Helm генерацию selmag-secret

В:

```
helm/selmag/values.yaml
```

Изменить:

```yaml
bootstrap:
  secret:
    enabled: false
```

`bootstrap.configMap.enabled: true` оставить как есть.

---

# 6. Убрать plaintext `.env.secret` из Git

Файл оставить локально.

```bash
echo "helm/selmag/files/.env.secret" >> .gitignore

git rm --cached helm/selmag/files/.env.secret

git add .gitignore \
helm/selmag/templates/selmag-secret-sealed.yaml \
helm/selmag/values.yaml

git commit -m "Move selmag-secret to SealedSecrets; stop storing plaintext .env.secret"
git push origin kubernetes-test-helm
```

После этого файл останется на диске, но перестанет быть tracked в git.

Если удалить его физически — тоже ок.

---

# 7. Дождаться синка ArgoCD и проверить

```bash
kubectl -n selmag-helm get sealedsecret

kubectl -n selmag-helm describe sealedsecret selmag-secret | sed -n '1,120p'

kubectl -n selmag-helm get secret selmag-secret -o yaml | head -n 40
```

Сервисам перезапуск обычно не нужен.

Если нужно принудительно обновить:

```bash
kubectl rollout restart deploy -n selmag-helm --all
```

---

# Можно настроить GitHub webhook для ArgoCD

```
Repo → Settings → Webhooks → Add webhook
```

## URL вебхука

```
http://argocd.selm.ag.192.168.49.2.nip.io/api/webhook
```

```
Content type: application/json
Events: Just the push event
```

---

# Секрет вебхука (рекомендуется)

Сгенерировать:

```bash
openssl rand -hex 32
```

---

# Прописать secret в ArgoCD

```bash
WEBHOOK_SECRET="PASTE_HEX_HERE"

kubectl -n argocd patch secret argocd-secret \
  -p "{\"stringData\": {\"webhook.github.secret\": \"${WEBHOOK_SECRET}\"}}"
```

Перезапустить сервер:

```bash
kubectl -n argocd rollout restart deploy/argocd-server
kubectl -n argocd rollout status deploy/argocd-server --timeout=120s
```

---

# Прописать secret в GitHub

```
Payload URL: http://argocd.../api/webhook
Content type: application/json
Secret: тот же hex
Events: push
Active: true
```

---

# Проверка

Сделать любой commit / push.

Ожидаемый результат:

- GitHub webhook deliveries → `200 OK`
- ArgoCD приложение быстро делает refresh

---

# Проверить дайджест и sha сервисов внутри кластера

Чтобы сравнить с тем, который был назначен ботом для PR.

```bash
kubectl -n selmag-helm get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.containerStatuses[*]}  {.name}{"\n"}    image:   {.image}{"\n"}    imageID: {.imageID}{"\n"}{end}{"\n"}{end}'
```
