# Kubernetes / Minikube / kubectl / Docker Registry — рабочие заметки

---

# Установка `kubectl` в Ubuntu (WSL2)

## Шаг 1: базовые пакеты

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gpg
```

## Шаг 2: добавить ключ репозитория Kubernetes

```bash
sudo mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

> Версия `v1.30` сейчас (29.11.2025) стабильная, но со временем можно подправить на актуальную.

## Шаг 3: добавить репозиторий

```bash
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
| sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
```

## Шаг 4: установка `kubectl`

```bash
sudo apt-get update
sudo apt-get install -y kubectl
```

---

# Установка `minikube` в Ubuntu (WSL2)

## Шаг 1: скачать бинарник

```bash
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
```

## Шаг 2: установить в `/usr/local/bin`

```bash
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

## Создать новый кластер Kubernetes под управлением `minikube`

```bash
minikube start --driver=docker --insecure-registry="192.168.49.1/24" --addons="ingress" --cpus=8 --memory=8g
```

или вот так, если нужно явно сказать minikube: «мой приватный реестр — `host.docker.internal:5000`, можно к нему по HTTP»:

```bash
minikube start --driver=docker --insecure-registry="host.docker.internal:5000" --addons=ingress --cpus=8 --memory=8g
```

## Проверить список ingress контроллеров

```bash
minikube addons list | grep -i ingress
```

Выведет примерно что-то такое:

```text
│ ingress                     │ minikube │ enabled ✅ │ Kubernetes │
│ ingress-dns                 │ minikube │ disabled   │ minikube    │
```

## Проверить pod'ы ingress-nginx

```bash
kubectl get pods -n ingress-nginx
```

Выведет примерно что-то такое:

```text
NAME                                       READY   STATUS      RESTARTS        AGE
ingress-nginx-admission-create-xcv99       0/1     Completed   0               3d18h
ingress-nginx-admission-patch-9m629        0/1     Completed   1               3d18h
ingress-nginx-controller-9cc49f96f-bxzvp   1/1     Running     1 (2d20h ago)   3d18h
```

## Проверить сервисы ingress-nginx

```bash
kubectl get svc -n ingress-nginx
```

Выведет примерно что-то такое:

```text
NAME                                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx-controller             NodePort    10.109.8.179   <none>        80:30583/TCP,443:32398/TCP   3d18h
ingress-nginx-controller-admission   ClusterIP   10.98.12.255   <none>        443/TCP                      3d18h
```

## Определить название `IngressClass`

```bash
kubectl get ingressclass
```

Выведет примерно что-то такое:

```text
NAME    CONTROLLER             PARAMETERS   AGE
nginx   k8s.io/ingress-nginx   <none>       3d18h
```

## Удалить текущий кластер `minikube`

```bash
minikube delete
```

---

# Дальнейшая работа с Kubernetes

## Базовые команды

```bash
minikube status
```

### Список деплойментов

```bash
kubectl get deployments.apps
kubectl get deployments
kubectl get deployment
```

### Проверить кластер

```bash
kubectl get nodes
kubectl get pods -A
```

### Перезапустить pod’ы

```bash
kubectl rollout restart deployment/selmag-eureka-server-deployment -n selmag
```

### Посмотреть ingress-контроллер

```bash
kubectl get pods -n ingress-nginx
```

### Создать namespace

```bash
kubectl create namespace selmag
```

### Сделать контекст `selmag` по умолчанию

```bash
kubectl config set-context --current --namespace selmag
```

---

# Задеплоить `nginx`

```bash
kubectl create deployment nginx --image nginx
```

## Посмотреть подробности о данном deployment

```bash
kubectl describe deployments.apps nginx
```

## Посмотреть подробности о pod'е

```bash
kubectl describe pod <pod_name>
kubectl describe pod nginx-66686b6766-k9f9z
```

## Посмотреть логи pod'а

```bash
kubectl logs <pod_name>
kubectl logs nginx-66686b6766-k9f9z
```

## Следить за логами в реальном времени

```bash
kubectl logs <pod_name> -f
kubectl logs nginx-66686b6766-k9f9z -f
```

---

# Создать сервис для pod'а

```bash
kubectl expose deployment <service_name> --type=NodePort --port=80
kubectl expose deployment nginx --type=NodePort --port=80
```

Расшифровка:

- `expose deployment nginx` — взять Pod’ы из Deployment `nginx` и сделать для них Service.
- `--type=NodePort` — Service будет доступен снаружи ноды по порту из диапазона `30000–32767`.
- `--port=80` — внешний порт сервиса внутри кластера, который будут видеть другие Pod’ы.
- `targetPort` по умолчанию возьмётся из `containerPort` (у образа `nginx` это `80`), так что отдельно указывать не обязательно.

## Затем можно проверить, что получилось

```bash
kubectl get svc
```

Увидишь что-то вроде:

```text
NAME         TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP  10.96.0.1       <none>        443/TCP        ...
nginx        NodePort   10.101.243.87   <none>        80:3xxxx/TCP   1m
```

Здесь важно:

- `80:3xxxx/TCP` — `80` это порт сервиса внутри кластера,
- `3xxxx` — `NodePort` (порт на ноде).

## Просмотреть IP-адрес

```bash
minikube ip
```

---

# Как открыть `nginx` из браузера

## Самый простой способ в `minikube`

```bash
minikube service nginx --url
```

или для конкретного namespace:

```bash
minikube service nginx -n selmag --url
minikube service nginx --namespace selmag --url
```

`minikube` сам:

- найдёт `NodePort`,
- возьмёт IP ноды,
- выдаст готовый URL, типа:

```text
http://192.168.49.2:3xxxx
```

Если это выполнять при такой работе с кубернетес: `Windows → WSL2 → Docker Desktop → minikube`, то выдаст что-то такое:

```text
http://127.0.0.1:3xxxx
```

Тогда этот адрес можно будет открывать в браузере на хосте с Виндой.

---

# `kubectl port-forward`

Для конструкции вида `Windows → WSL2 → Docker Desktop → minikube` можно воспользоваться командой `kubectl port-forward`.

`port-forward` создаёт туннель:

```text
WSL2 localhost:PORT → K8s Service/Pod → контейнер
```

Никаких IP, никаких NodePort, никаких docker-сетей — работает всегда.

```bash
kubectl port-forward svc/nginx 8080:80 -n selmag
```

Расшифровка:

- `svc/nginx` — перенаправляем трафик на Service `nginx`;
- `8080:80` — локальный порт `8080` → порт сервиса `80`;
- `-n selmag` — твой namespace.

После этого в браузере на хосте с Виндой можно открыть:

```text
http://127.0.0.1:8080
```

Можно использовать и другой порт. Например:

```bash
kubectl port-forward svc/nginx 9989:80 -n selmag
```

Тогда открыть в браузере на хосте с Виндой можно будет так:

```text
http://127.0.0.1:9989
```

---

# Создать ingress сервис (в данном случае `nginx`) для перенаправления HTTP-трафика

## a) Если выполнять всё на хосте с Linux OS

```bash
kubectl create ingress nginx-ingress --rule=nginx.selm.ag.192.168.49.2.nip.io/=nginx:80
```

### Проверка

```bash
kubectl get ingress
```

Выведет примерно такое:

```text
NAME            CLASS   HOSTS                                   ADDRESS   PORTS AGE
nginx-ingress   nginx   nginx.selm.ag.192.168.49.2.nip.io                  80    42s
```

Если зайти внутрь `minikube` и сделать `curl`, всё будет работать:

```bash
minikube ssh
curl http://nginx.selm.ag.192.168.49.2.nip.io
```

## b) Если конструкция вида `Windows → WSL2 → Docker Desktop → minikube`

То есть команда выполняется на хосте с Виндой и на ней есть Docker Desktop, а также используется WSL2:

```bash
kubectl create ingress nginx-ingress --rule=nginx.selm.ag.127.0.0.1.nip.io/=nginx:80
```

### Проверка

```bash
kubectl get ingress
```

Выведет примерно такое:

```text
NAME            CLASS   HOSTS                                   ADDRESS   PORTS AGE
nginx-ingress   nginx   nginx.selm.ag.127.0.0.1.nip.io                    80    3s
```

### Открыть в браузере на хосте с Виндой

#### Шаг 1. Найти pod контроллера

```bash
kubectl get pods -n ingress-nginx
```

Будет что-то типа:

```text
ingress-nginx-controller-xxxxxx
```

#### Шаг 2. Пробросить порт 80 этого Pod наружу

```bash
kubectl port-forward -n ingress-nginx pod/ingress-nginx-controller-xxxxx 8089:80
kubectl port-forward -n ingress-nginx pod/ingress-nginx-controller-9cc49f96f-bxzvp 8089:80
```

Теперь Ingress-контроллер доступен по адресу:

```text
http://nginx.selm.ag.127.0.0.1.nip.io:8089
```

---

# Удалить всё это

```bash
kubectl delete ingress nginx-ingress
kubectl delete svc nginx
kubectl delete deployments.apps nginx
```

---

# ConfigMap и Secret

## ConfigMap с несекретными настройками

```bash
kubectl create configmap selmag-config \
  --from-env-file=.env.config \
  -n selmag
```

## Пересоздать ConfigMap с несекретными настройками

```bash
kubectl delete configmap selmag-config -n selmag --ignore-not-found
kubectl create configmap selmag-config --from-env-file=k8s/shared/.env.config -n selmag
```

или так:

```bash
kubectl -n selmag create configmap selmag-config \
  --from-env-file=k8s/shared/.env.config \
  -o yaml --dry-run=client | kubectl apply -f -
```

## Secret с паролями и клиентскими секретами

```bash
kubectl create secret generic selmag-secret \
  --from-env-file=.env.secret \
  -n selmag
```

## Пересоздать Secret с несекретными настройками

```bash
kubectl delete secret selmag-secret -n selmag --ignore-not-found
kubectl create secret generic selmag-secret --from-env-file=k8s/shared/.env.secret -n selmag
```

или так:

```bash
kubectl -n selmag create secret generic selmag-secret \
  --from-env-file=k8s/shared/.env.secret \
  -o yaml --dry-run=client | kubectl apply -f -
```

## Создать Secret для Keycloak из файла `selmag-minikube.json`

Это наш realm для minikube с клиентскими секретами:

```bash
kubectl create secret generic selmag-keycloak-realm \
  --from-file=selmag-minikube.json=config/keycloak/import/selmag-minikube.json \
  -n selmag
```

## Пересоздать / обновить

```bash
kubectl create secret generic selmag-keycloak-realm \
  --from-file=selmag-minikube.json=config/keycloak/import/selmag-minikube.json \
  -n selmag \
  --dry-run=client -o yaml | kubectl apply -f -
```

или так:

```bash
kubectl delete secret selmag-keycloak-realm -n selmag

kubectl create secret generic selmag-keycloak-realm \
  --from-file=selmag-minikube.json=config/keycloak/import/selmag-minikube.json \
  -n selmag
```

---

# Как сделать полный экспорт `selmag-minikube.json` из контейнера Keycloak в Kubernetes

```bash
POD=$(kubectl -n selmag get pod -l app=selmag-keycloak -o jsonpath='{.items[0].metadata.name}')

kubectl -n selmag exec "$POD" -- /opt/keycloak/bin/kc.sh export \
  --realm selmag \
  --file /tmp/selmag-export.json \
  --users same_file

kubectl -n selmag exec "$POD" -- sh -c 'cat /tmp/selmag-export.json' > ./selmag-export.json
```

## Затем перезапустить deployment'ы, которые должны подхватить новые значения

```bash
kubectl rollout restart deployment -n selmag
```

или точечно: `deployment/selmag-admin-server-deployment`, `deployment/selmag-catalogue-service-deployment` и т.д.

Расшифровка:

- `create configmap selmag-config` — создаёт объект `ConfigMap` с именем `selmag-config`.
- `create secret generic selmag-secret` — создаёт `Secret` произвольного типа `generic` с именем `selmag-secret`.
- `--from-env-file=FILE` — берёт файл как набор `KEY=VALUE`.
- `-n selmag` — всё это складываем в namespace `selmag`.

## Посмотреть

```bash
kubectl get configmap selmag-config -n selmag
kubectl describe configmap selmag-config -n selmag

kubectl get secret selmag-secret -n selmag
kubectl describe secret selmag-secret -n selmag
```

> значения в `base64`

---

# Настройка deployment-файлов сервисов

## Config Server

Путь к файлу такой, если эту команду выполнять из корня проекта:

```bash
kubectl apply -f k8s/services/config-server-deployment.yaml -n selmag
kubectl apply --filename k8s/services/config-server-deployment.yaml
```

## Для других сервисов

```bash
kubectl apply -f k8s/services/eureka-server-deployment.yaml -n selmag
kubectl apply -f k8s/services/customer-app-deployment.yaml -n selmag
```

## Посмотреть, поднялся ли pod

```bash
kubectl get pods -n selmag -l app=selmag-customer-app
kubectl logs -n selmag -l app=selmag-customer-app --tail=200
```

## Проверка результата работы команды

```bash
kubectl get deployments.apps
```

## Посмотреть список pod'ов

```bash
kubectl get pods -n selmag
kubectl get pod
```

## Посмотреть логи одного pod'а

```bash
kubectl logs <имя-pod-а> -n selmag
kubectl logs selmag-config-server-deployment-786dcd4b9b-5wgb7 -n selmag
```

## Если нужны логи прямо с Deployment

Автоматически выберет один pod:

```bash
kubectl logs -n selmag deploy/selmag-config-server-deployment
```

---

# Логи с подсветкой

## С помощью `perl`

```bash
kubectl logs -n selmag deploy/selmag-config-server-deployment \
  | perl -pe 's/\b(dev|git|INFO|WARN|ERROR)\b/\e[1;32m$1\e[0m/g'
```

> `]` — эта квадратная скобочка нужна не для команды, а чтобы здесь в редакторе не ломалась дальнейшая подсветка. Просто игнорь её ;)

## Разноцветный вывод через `perl`

```bash
kubectl logs -n selmag deploy/selmag-config-server-deployment \
| perl -pe '
  s/\bERROR\b/\e[1;31m$&\e[0m/g;
  s/\bWARN\b/\e[1;33m$&\e[0m/g;
  s/\bINFO\b/\e[1;32m$&\e[0m/g;

  s/\b(dev|git)\b/\e[1;36m$&\e[0m/g;

  s/config resource/\e[1;35m$&\e[0m/g;
'
```

> `]` — эта квадратная скобочка нужна не для команды, а чтобы здесь в редакторе не ломалась дальнейшая подсветка. Просто игнорь её ;)

## С помощью `grep`

```bash
kubectl logs -n selmag deploy/selmag-config-server-deployment \
  | grep --color=always -E "dev|git|INFO|ERROR|WARN|The following 1 profile is active"
```

То есть в выводе в консоли цветом будут подсвечены слова `dev`, `git`, `INFO`, `ERROR`, `WARN`, `The following 1 profile is active`, если они там есть.

> Важно: `grep` выводит только строки, где есть совпадение, и скроет строки, где нет ни одного из этих токенов.

## `grep` с выведением всех строк

```bash
kubectl logs -n selmag deploy/selmag-config-server-deployment \
  | GREP_COLORS='mt=1;32' grep --color=always -E 'dev|git|INFO|WARN|ERROR|Config resource|$'
```

## Смотреть логи в режиме `tail -f`

```bash
kubectl logs -n selmag -f deploy/selmag-config-server-deployment
```

## Если контейнеров в pod'е несколько

У тебя один, но на будущее:

```bash
kubectl logs -n selmag pod-name -c container-name
```

## Проверить события, если pod не стартует

```bash
kubectl describe pod -n selmag <pod-name>
kubectl describe pod -n selmag selmag-config-server-deployment-786dcd4b9b-5wgb7
```

---

# Удалить существующий deployment

```bash
kubectl delete -f k8s/services/config-server-deployment.yaml -n selmag
kubectl delete deployment selmag-config-server-deployment -n selmag
```

---

# «Перезапустить» pod

## Вариант A. Через Deployment (правильный способ)

```bash
kubectl rollout restart deployment selmag-config-server-deployment -n selmag
kubectl rollout status deployment selmag-config-server-deployment -n selmag
```

## Вариант B. Удалить конкретный pod

```bash
kubectl delete pod selmag-config-server-deployment-786dcd4b9b-5wgb7 -n selmag
```

Deployment увидит, что один pod пропал, и создаст новый с другим суффиксом. Это тоже «перезапуск», но более грубый.

---

# Остановить / запустить сервис полностью

## Остановить, не держать ни одного pod'а

```bash
kubectl scale deployment selmag-config-server-deployment -n selmag --replicas=0
```

## Потом снова запустить

```bash
kubectl scale deployment selmag-config-server-deployment -n selmag --replicas=1
```

---

# Полностью удалить Config Server из кластера

```bash
kubectl delete -f k8s/services/config-server-deployment.yaml -n selmag
kubectl delete deployment selmag-config-server-deployment -n selmag
```

`ConfigMap` / `Secret` при этом не удаляются — только `Deployment` и pod.

---

# Проброс портов наружу

## Из pod'а `config-server`

Чтобы открыть в браузере на хосте с Виндой путь вида:

```text
http://localhost:8888/selmag-catalogue-service/cloudconfig/kubernetes-test
```

```bash
kubectl port-forward -n selmag selmag-config-server-deployment-786dcd4b9b-5wgb7 8888:8888
```

Тогда в браузере открываешь:

```text
http://localhost:8888/selmag-catalogue-service/cloudconfig/kubernetes-test
```

## Через Service

```bash
kubectl port-forward -n selmag svc/selmag-config-server-svc 8888:8888
```

Тогда в браузере открываешь:

```text
http://localhost:8888/selmag-catalogue-service/cloudconfig/kubernetes-test
```

## Быстрая проверка через `port-forward`

Самый надёжный способ на старте:

```bash
kubectl port-forward -n selmag svc/selmag-customer-app-svc 8083:8083
```

Потом открыть в браузере:

```text
http://localhost:8083/actuator/health
```

---

# Альтернативы на будущее

## 1. `minikube service`

Можно попросить `minikube` сам организовать доступ:

```bash
minikube service selmag-config-server-svc -n selmag --url
```

Он выведет URL, по которому можно открыть сервис, часто автоматически открывает браузер, что-то вроде:

```text
http://127.0.0.1:46685
```

> Because you are using a Docker driver on linux, the terminal needs to be open to run it.

Тогда в браузере на хосте с Виндой можно будет открыть:

```text
http://127.0.0.1:46685/selmag-catalogue-service/cloudconfig/kubernetes-test
```

Где `selmag-catalogue-service/cloudconfig` — это папки, где хранится конфиг в проекте в git, а `kubernetes-test` — это имя ветки в git, откуда скачивать конфиг. Эти вещи можно найти в самом проекте.

Также можно для разных сервисов указывать разные места скачивания конфигов, с разных веток или тэгов и т.д.

## 2. Ingress + Ingress Controller

Более «боевой» вариант — поставить ingress-контроллер (например, NGINX Ingress Controller) и пробрасывать только HTTP/HTTPS наружу. Это уже следующая ступень.

---

# Проверка через Ingress

Если `ingress-nginx-controller` проброшен на `8080` как раньше:

```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

И на Windows в `hosts`:

```text
127.0.0.1 customer.selm.ag.192.168.49.2.nip.io
```

Открыть в браузере на хосте с Виндой:

```text
http://customer.selm.ag.192.168.49.2.nip.io:8080/
```

---

# Как правильно проверять Ingress в твоей среде

## Самый надёжный способ

```bash
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
```

## В Windows (или WSL-браузере)

### 1. Добавить в `hosts`

```text
127.0.0.1  config.selm.ag.192.168.49.2.nip.io
127.0.0.1  eureka.selm.ag.192.168.49.2.nip.io
```

### 2. Открывать

```text
http://config.selm.ag.192.168.49.2.nip.io:8080/selmag-catalogue-service/cloudconfig/kubernetes-test
http://config.selm.ag.192.168.49.2.nip.io:8080/selmag-eureka-server/cloudconfig/kubernetes-test
```

Открыть саму Эврику в браузере на хосте с Виндой:

```text
http://eureka.selm.ag.192.168.49.2.nip.io:8080/
```

Откуда берётся этот URL? Это нужно смотреть настройки в файле-конфиге для `kind: Ingress`:

```yaml
spec:
  ingressClassName: nginx
  rules:
    - host: config.selm.ag.192.168.49.2.nip.io
```

То есть из `host` мы и видим этот URL, а уже вот `8080/selmag-catalogue-service/cloudconfig/kubernetes-test` состоит из порта `8080`, который мы прокидывали выше (он может быть и другим, какой пропишем во время проброса), а оставшаяся часть — это путь, откуда в git-репозитории, так как сервис `config-server` был запущен с профилем `git`, брать конфиг для сервиса `catalogue-service`.

---

# Практическая проверка переменной `CONFIG_SERVER_URI`

Чтобы убедиться, что переменная реально в Pod:

```bash
kubectl exec -n selmag deploy/selmag-eureka-server-deployment -- printenv | grep CONFIG_SERVER_URI
```

Должно вывести:

```text
CONFIG_SERVER_URI=http://selmag-config-server-svc:8888
```

## Узнать `nodePort`

```bash
kubectl get svc selmag-config-server-svc -n selmag -o wide
```

---

# Что за `image: 192.168.49.1:5000/selmag/config-server:24.1.1`

Формат такой строки:

```text
image: <registry-host>:<port>/<repo>/<image-name>:<tag>
```

- `192.168.49.1:5000` — адрес registry (реестр Docker-образов)
- `selmag/config-server` — имя репозитория / образа
- `24.1.1` — тег образа

---

# Поднять registry в Docker

## В Ubuntu / WSL2

```bash
docker run -d \
  --restart=always \
  --name selmag-registry \
  -p 5000:5000 \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  -v selmag-registry-data:/var/lib/registry \
  registry:2
```

Что получилось:

- На Windows-хосте (и в WSL2) слушает порт `5000`
- Внутри Docker-сети этот порт тоже есть
- Для minikube:
    - minikube-нода имеет IP `192.168.49.2`
    - Windows-хост с точки зрения minikube — `192.168.49.1`
    - поэтому адрес registry для Kubernetes: `192.168.49.1:5000`

## Проверка из WSL2

```bash
curl http://127.0.0.1:5000/v2/_catalog
```

Должно вывести что-то такое, так как репозиторий пока пустой:

```json
{"repositories":[]}
```

## Проверка изнутри `minikube`

```bash
minikube ssh
curl http://host.docker.internal:5000/v2/_catalog
```

---

# Docker Desktop и `insecure-registries`

Перед тем как пушить образ в registry, нужно открыть:

`Docker Desktop → Settings → Docker Engine`

И внутри JSON добавить поле `insecure-registries`:

```json
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "experimental": false,
  "insecure-registries": [
    "host.docker.internal:5000"
  ]
}
```

А затем нажать **Apply & Restart** — Docker перезапустится.

Теперь Docker daemon официально разрешает HTTP-регистри по адресу `host.docker.internal:5000`.

## Проверить, что образ появился в registry

```bash
curl http://host.docker.internal:5000/v2/_catalog
```

В ответе должен быть примерно такой JSON:

```json
{"repositories":["selmag/config-server"]}
```

---

# Push образов в registry

## Config Server

```bash
docker push host.docker.internal:5000/selmag/config-server:24.1.1
```

## Другие сервисы

```bash
docker push host.docker.internal:5000/selmag/eureka-server:24.1.1
```

## Перетегировать Keycloak

```bash
docker tag quay.io/keycloak/keycloak:23.0.7 \
  host.docker.internal:5000/selmag/keycloak:23.0.7
```

И дальше запушить Keycloak:

```bash
docker push host.docker.internal:5000/selmag/keycloak:23.0.7
```

---

# Как подробно удалить старый образ из своего registry

## Вариант A. Выкинуть весь registry

Для разработки это норм. Если это только твой dev-регистри и внутри ничего особо ценного:

### Остановить и удалить контейнер с registry

```bash
docker stop selmag-registry
docker rm selmag-registry
```

Если у тебя не было выделенного volume, его слой внутри WSL тоже уйдёт, и все образы из registry будут удалены.

Потом, если нужно, поднимаешь его заново той же командой:

```bash
docker run -d \
  --restart=always \
  --name selmag-registry \
  -p 5000:5000 \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  -v selmag-registry-data:/var/lib/registry \
  registry:2
```

Minikube и конфигурации `image: host.docker.internal:5000/...` никуда не «сломаются» — просто при первом `pull` kube не найдёт образ и ты заново запушишь нужные.

## Вариант B. Удалять конкретные теги

Чуть более «правильно».

### 1. Поднять registry с включённым удалением

```bash
docker stop selmag-registry
docker rm selmag-registry

docker volume create selmag-registry-data

docker run -d \
  --restart=always \
  --name selmag-registry \
  -p 5000:5000 \
  -e REGISTRY_STORAGE_DELETE_ENABLED=true \
  -v selmag-registry-data:/var/lib/registry \
  registry:2
```

### 2. Удалить тег через HTTP API в три шага

#### 2.1 Вытащить digest

```bash
DIGEST=$(docker inspect \
  --format='{{index .RepoDigests 0}}' \
  host.docker.internal:5000/selmag/config-server:24.1.1 | cut -d'@' -f2)

echo "DIGEST = $DIGEST"
```

#### 2.2 Удалить этот манифест по digest

```bash
curl -X DELETE \
  "http://host.docker.internal:5000/v2/selmag/config-server/manifests/${DIGEST}"
```

Чтобы проверить, что всё удалилось, нужно выполнить вот это.

##### а) удалён ли манифест (описание образа, index / manifest)

```bash
curl -I \
  -H "Accept: application/vnd.oci.image.index.v1+json" \
  "http://host.docker.internal:5000/v2/selmag/config-server/manifests/24.1.1"
```

Если удалился, то выведет примерно следующее:

```text
HTTP/1.1 404 Not Found
Content-Type: application/json; charset=utf-8
Docker-Distribution-Api-Version: registry/2.0
X-Content-Type-Options: nosniff
Date: Thu, 11 Dec 2025 21:02:26 GMT
Content-Length: 96
```

##### б) удалена ли ссылка тега (`24.1.1`) на этот манифест

```bash
curl http://host.docker.internal:5000/v2/selmag/config-server/tags/list
```

Если удалено, то выведет примерно следующее. Если этот тег был единственный, то увидишь либо пустой список тегов, либо сам репозиторий пропадёт из `_catalog`:

```json
{"name":"selmag/config-server","tags":null}
```

#### 2.3 Garbage collection внутри registry

Слои (`blobs`), лежащие в томе `/var/lib/registry`, остаются, пока ты не запустишь garbage collector.

То есть:

- снаружи кажется, что образа нет, по тегу не достать,
- но фактические файлы под `blobs/sha256/...` ещё занимают место на диске.

### 3. Запустить garbage collection внутри registry

```bash
docker exec -it selmag-registry \
  bin/registry garbage-collect /etc/docker/registry/config.yml
```

Тогда увидишь что-то такое:

```text
selmag/config-server
selmag/config-server: marking manifest sha256:4c21f316433f099e411316612fc57c5daceaa881efa2481f8949ebfce72700da
selmag/config-server: marking blob sha256:b702b01d244ae3a5a9ed5964c2caafa1f5d4d2cc1f814f7cdaf1e4f43bcf0652
selmag/config-server: marking blob sha256:0cb391e5c7a00d4cfb635eca5f4e4d556c24927d0823e3809bea97924c441db4
selmag/config-server: marking manifest sha256:cef94f80e1fc761e756f83c51287c33cdf75c01c7f5342efe3a9281cb11d522a
selmag/config-server: marking blob sha256:128e75b98daffb338a0451703bc6d5c2826ae40515785262ac2797269e589d07
selmag/config-server: marking blob sha256:7021d1b70935851c95c45ed18156980b5024eda29b99564429025ea04f5ec109
selmag/config-server: marking blob sha256:0f3320e4e2ae41973a279c466eba6f7af49750691a7d55baabde5b47c635660f
selmag/config-server: marking blob sha256:c2a1b74c104b713ce63e80a9eba70615f3839a39bc32ff2ec1cb1b1bab1d3844
selmag/config-server: marking blob sha256:9388fd15f91d7f97ac726a3f7e073ffdc8f95fd4204c775024910abc24fc5891
selmag/config-server: marking blob sha256:f99452047d19dd426b965f3b598f549a7a5d402bb4f0cf5867e62f934e3b50d7
selmag/config-server: marking blob sha256:963231cc384712ebf8c4a515e28047521f082a9df2d2e775faf09f76678668af
selmag/config-server: marking blob sha256:d1fd02e18224c8aecd980f4890d6f97c79c1ff5656fc77872fc9d5409db9e587
selmag/config-server: marking blob sha256:c44d35bc40bf42aae9a2930980bcf6b4835e9f67c8a9e2a18603bc0648cc9bdb
selmag/config-server: marking blob sha256:21b9b27446dbf3f5b4b81f599bdcf3ee3e0228d1607bfdcd60653b36ff049055
selmag/config-server: marking blob sha256:6546c4cae03ae7f63d5fbe55303fe0dabb70c6668f1cb6ecc6231b8c889362fd
selmag/config-server: marking blob sha256:4f4fb700ef54461cfa02571ae0db9a0dc1e0cdb5577484a6d75e68dc38e8acc1
selmag/config-server: marking blob sha256:ba8b7f2a998d0eb55a5a5b25668d072c8bb524fc6eeedf6faca00cf84aa28d27

17 blobs marked, 1 blobs and 0 manifests eligible for deletion
blob eligible for deletion: sha256:aca29015007ff6e0050da0a035ec2eb43435961ac34d86244818be02fb05ddb9
INFO[0000] Deleting blob: /docker/registry/v2/blobs/sha256/ac/aca29015007ff6e0050da0a035ec2eb43435961ac34d86244818be02fb05ddb9
go.version=go1.20.8 instance.id=05532279-4de5-4da4-8f75-d73ba7ee727f service=registry
```

Теперь можно заново запушить образ `config-server` сервиса:

```bash
docker push host.docker.internal:5000/selmag/config-server:24.1.1
```

---

# PowerShell-скрипты

```powershell
powershell -ExecutionPolicy Bypass -File C:\scripts\selmag-update-hosts.ps1
powershell -ExecutionPolicy Bypass -File d:\programming\projects\Rural_Java\2024\selmag-update-hosts.ps1
```

---

# Ещё попробовать для кубера попозже

## 6. Хочешь настроить доступ без `port-forward`?

Выбор зависит от архитектуры.

### Вариант A: Service типа `ClusterIP`

Для других Pod-ов.

Тогда другие сервисы будут обращаться:

```text
http://selmag-config-server.selmag:8888
```

если Service будет называться `selmag-config-server`.

### Вариант B: `NodePort`

Для доступа снаружи без `port-forward`:

```yaml
spec:
  type: NodePort
```

Тогда можно открыть:

```text
http://<minikube-ip>:<nodeport>
```

### Вариант C: Ingress

Для красивого DNS:

```text
http://config-server.local/...
```

Если хочешь — могу написать готовые manifest-файлы для `Service` / `NodePort` / `Ingress`.

## 7. Если хочешь автоматически перезапускать Config-Server при изменении Git

Можно включить:

```properties
spring.cloud.config.server.git.refreshRate=30
```

Или настроить:

```text
/actuator/refresh
```

В Kubernetes это тоже можно реализовать.

---

# Что такое Service Mesh

`Service Mesh` — это дополнительный сетевой слой внутри Kubernetes, который отвечает за:

- маршрутизацию трафика между сервисами,
- наблюдаемость (метрики, трассировка),
- ретраи, таймауты, канареечные релизы,
- безопасное взаимное TLS-шифрование (`mTLS`),
- балансировку,
- автоматическое восстановление соединений,
- `A/B-deployments` и `traffic shifting`.

Проще говоря:

> Service Mesh — это «умная сеть» внутри кластера, которая позволяет программам общаться безопасно, надёжно и прозрачно, без изменения их исходного кода.

Типичные представители:

- Istio
- Linkerd
- Consul Connect
- Kuma

## Имя порта (`name: http`) — это сигнал для Service Mesh

Что:

- этот порт обслуживает `HTTP`-трафик, а не `TCP`, `gRPC` и т.д.,
- значит, Mesh может:
    - применять правила маршрутизации,
    - собирать HTTP-метрики (`latency`, `errors`, `requests`),
    - управлять ретраями,
    - выполнять канареечный трафик,
    - включать автоматический `mTLS`.

---

# Что можно улучшить позже

Не ошибки, а идеи «на вырост»:

1. `Ingress annotations`
    - timeouts
    - body size
    - SSL (позже)

2. `Ingress TLS`
    - cert-manager
    - letsencrypt
    - wildcard `*.selm.ag`

3. Gateway
    - rate limiting
    - retry / circuit breaker
    - global filters

---
## Туннелирование

```bash
sudo env \
  "HOME=$HOME" \
  "PATH=$PATH" \
  "MINIKUBE_HOME=$HOME/.minikube" \
  "KUBECONFIG=$HOME/.kube/config" \
  minikube tunnel -p minikube
```

## Порт-форвардинг

```bash
kubectl -n selmag port-forward svc/selmag-keycloak-svc 8080:8080
```

```bash
sudo minikube tunnel --bind-address=0.0.0.0
```

---

# WSL IP, LoadBalancer и `minikube tunnel`

## 1) Узнаем IP-адрес

```bash
ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
```

Пример:

```text
172.21.106.163
```

## 1.1) Переключить `ingress-nginx-controller` Service в `LoadBalancer`

Делается один раз, переживает рестарты кластера, пока ты не пересоздашь addon.

```bash
kubectl -n ingress-nginx patch svc ingress-nginx-controller -p '{"spec":{"type":"LoadBalancer"}}'
```

### Проверка

```bash
kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide
```

## 2) Запустить `minikube tunnel` в WSL2

В другом окне WSL. Это обязательная часть для `LoadBalancer` в `minikube`:

```bash
sudo -E env "HOME=$HOME" "USER=$USER" minikube tunnel --bind-address=0.0.0.0
```

Почему `--bind-address=0.0.0.0`: чтобы `LB` был доступен не только из WSL, но и с Windows через IP WSL.

### Проверка

```bash
kubectl -n ingress-nginx get svc ingress-nginx-controller -w
```

Ты должен увидеть, что `EXTERNAL-IP` перестал быть `<pending>` и стал каким-то значением, часто это IP, который `tunnel` поднял локально / виртуально.

## 3) На Windows открыть от администратора `hosts`

```text
C:\Windows\System32\drivers\etc\hosts
```

И добавить строку, подставив свой WSL IP из шага 1:

```text
<WSL_IP> keycloak.selm.ag.192.168.49.2.nip.io
172.21.106.163 keycloak.selm.ag.192.168.49.2.nip.io
```

## 4) Проверка из Windows

```powershell
Test-NetConnection <WSL_IP> -Port 80
Test-NetConnection 172.21.106.163 -Port 80
```

Должно стать:

```text
TcpTestSucceeded : True
```

---

# Патчим CoreDNS ConfigMap (`kube-system/coredns`)

## Сделать бэкап

```bash
kubectl -n kube-system get configmap coredns -o yaml > /tmp/coredns.yaml
```

## Открыть на редактирование

```bash
kubectl -n kube-system edit configmap coredns
```

## Заменить в `/tmp/coredns.yaml` только секцию `data.Corefile`

```yaml
apiVersion: v1
data:
  Corefile: |
    .:53 {
        log
        errors
        health {
           lameduck 5s
        }
        ready

        # --- Force internal routing for external hostnames (nip.io) ---
        # Map external FQDNs to ingress-nginx service inside the cluster
        rewrite name exact keycloak.selm.ag.192.168.49.2.nip.io. ingress-nginx-controller.ingress-nginx.svc.cluster.local.
        rewrite name exact eureka.selm.ag.192.168.49.2.nip.io. ingress-nginx-controller.ingress-nginx.svc.cluster.local.

        kubernetes cluster.local in-addr.arpa ip6.arpa {
           pods insecure
           fallthrough in-addr.arpa ip6.arpa
           ttl 30
        }

        prometheus :9153

        hosts {
           192.168.49.1 host.minikube.internal
           fallthrough
        }

        forward . /etc/resolv.conf {
           max_concurrent 1000
        }

        cache 30 {
           disable success cluster.local
           disable denial cluster.local
        }

        loop
        reload
        loadbalance
    }
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
```

## Применяем

```bash
kubectl -n kube-system apply -f /tmp/coredns.yaml
```

## Перезапустить CoreDNS

```bash
kubectl -n kube-system rollout restart deployment/coredns
kubectl -n kube-system rollout status deployment/coredns --timeout=120s
```

## Проверка DNS из pod

```bash
kubectl -n selmag run dns-check --rm -it --image=busybox:1.36 --restart=Never -- \
  sh -lc "nslookup keycloak.selm.ag.192.168.49.2.nip.io"
```

Ожидаемо: в ответе ты увидишь, что имя резолвится, обычно в `ClusterIP ingress-nginx-controller`.

## Проверка HTTP из pod по «внешнему» hostname

```bash
kubectl -n selmag run http-check --rm -it --image=curlimages/curl:8.10.1 --restart=Never -- \
  sh -lc "curl -fsS http://keycloak.selm.ag.192.168.49.2.nip.io/realms/selmag/.well-known/openid-configuration | grep -o '\"issuer\"[^,]*'"
```

Должно вернуться:

```json
"issuer":"http://keycloak.selm.ag.192.168.49.2.nip.io/realms/selmag"
```

Это означает:

- `issuer` внешний, как и должен быть,
- но маршрут внутри кластера, DNS ведёт на ingress controller.

## Что это даёт архитектурно

- UI / Browser работает корректно, все ссылки, редиректы, JS-запросы — наружные
- токены имеют единый `iss`, и Spring Security перестаёт конфликтовать
- внутри кластера сервисы обращаются к тому же hostname, но фактически идут на `ingress-nginx-controller` внутри Kubernetes, без выхода на Windows / WSL tunnel / маршруты

## Важное замечание про `minikube tunnel` / WSL

`minikube tunnel` нужен, чтобы Windows мог открыть `http://keycloak...` — это экспонирование `80/443` наружу.

Но для внутрикластерного трафика он не нужен — после `CoreDNS rewrite` всё остаётся внутри.

---

# Обновление ConfigMap после правки `.env.config`

```bash
kubectl -n selmag create configmap selmag-config \
  --from-env-file=k8s/shared/.env.config \
  --dry-run=client -o yaml | kubectl apply -f -
```

---

# Дальше перезапускаешь deployment'ы

## Keycloak

```bash
kubectl -n selmag rollout restart deploy/selmag-keycloak-deployment
kubectl -n selmag rollout status deploy/selmag-keycloak-deployment
```

## Все сервисы, которые используют `issuer-uri`

Фактически все твои Spring resource server / oauth2 client.

### Например

```bash
kubectl -n selmag rollout restart deploy/selmag-config-server-deployment
kubectl -n selmag rollout status deploy/selmag-config-server-deployment
kubectl -n selmag port-forward svc/selmag-config-server-svc 8888:8888 --address 0.0.0.0

kubectl -n selmag rollout restart deploy/selmag-eureka-server-deployment
kubectl -n selmag rollout status deploy/selmag-eureka-server-deployment

kubectl -n selmag rollout restart deploy/selmag-catalogue-service-deployment
kubectl -n selmag rollout status deploy/selmag-catalogue-service-deployment
```

URL, по которым можно открыть Swagger в браузере на хосте с Виндой:

```text
http://catalogue.api.selm.ag.192.168.49.2.nip.io/swagger-ui/index.html
```

```bash
kubectl -n selmag rollout restart deploy/selmag-feedback-service-deployment
kubectl -n selmag rollout status deploy/selmag-feedback-service-deployment
```

URL, по которым можно открыть Swagger:

```text
http://feedback.api.selm.ag.192.168.49.2.nip.io/webjars/swagger-ui/index.html
```

```bash
kubectl -n selmag rollout restart deploy/selmag-customer-app-deployment
kubectl -n selmag rollout status deploy/selmag-customer-app-deployment

kubectl -n selmag rollout restart deploy/selmag-manager-app-deployment
kubectl -n selmag rollout status deploy/selmag-manager-app-deployment

kubectl -n selmag rollout restart deploy/selmag-admin-server-deployment
kubectl -n selmag rollout status deploy/selmag-admin-server-deployment
kubectl -n selmag port-forward svc/selmag-admin-server-svc 8085:8085 --address 0.0.0.0

kubectl -n selmag rollout restart deploy/selmag-api-gateway-deployment
kubectl -n selmag rollout status deploy/selmag-api-gateway-deployment
```

---

# Применение изменений в deployment'ах

## API Gateway

```bash
kubectl -n selmag apply -f k8s/services/api-gateway/deployment.yaml
kubectl -n selmag rollout status deploy/selmag-api-gateway-deployment
```

## Admin Server

```bash
kubectl -n selmag apply -f k8s/services/admin-server/deployment.yaml
kubectl -n selmag rollout status deploy/selmag-admin-server-deployment
```

## Catalogue Service

```bash
kubectl -n selmag apply -f k8s/services/catalogue-service/deployment.yaml
kubectl -n selmag rollout status deploy/selmag-catalogue-service-deployment
```

## Feedback Service

```bash
kubectl -n selmag apply -f k8s/services/feedback-service/deployment.yaml
kubectl -n selmag rollout status deploy/selmag-feedback-service-deployment
```

## Customer App

```bash
kubectl -n selmag apply -f k8s/services/customer-app/deployment.yaml
kubectl -n selmag rollout status deploy/selmag-customer-app-deployment
```

## Manager App

```bash
kubectl -n selmag apply -f k8s/services/manager-app/deployment.yaml
kubectl -n selmag rollout status deploy/selmag-manager-app-deployment
```

## Проверить профили

```bash
kubectl -n selmag exec deploy/selmag-api-gateway-deployment -- printenv | grep SPRING_PROFILES_ACTIVE
kubectl -n selmag exec deploy/selmag-admin-server-deployment -- printenv | grep SPRING_PROFILES_ACTIVE
kubectl -n selmag exec deploy/selmag-catalogue-service-deployment -- printenv | grep SPRING_PROFILES_ACTIVE
kubectl -n selmag exec deploy/selmag-feedback-service-deployment -- printenv | grep SPRING_PROFILES_ACTIVE
kubectl -n selmag exec deploy/selmag-customer-app-deployment -- printenv | grep SPRING_PROFILES_ACTIVE
kubectl -n selmag exec deploy/selmag-manager-app-deployment -- printenv | grep SPRING_PROFILES_ACTIVE
```

---

# Port forwarding для `config-server`

## Вариант A — самый простой и рекомендуемый для dev

### Шаг 1. Запускаешь `port-forward` в WSL

В отдельном терминале и не закрывать его:

```bash
kubectl -n selmag port-forward svc/selmag-config-server-svc 8888:8888
```

### Шаг 2. Открываешь в браузере Windows

```text
http://localhost:8888
```

Примеры:

```text
http://localhost:8888/selmag-catalogue-service-cloudconfig.properties
http://localhost:8888/selmag-eureka-server/cloudconfig
```

> `hosts`-файл Windows не нужен. В современных WSL2 `localhost` пробрасывается автоматически — у тебя это уже работает.

## Вариант B — если вдруг `localhost` не откроется

### Шаг 1. Узнать IP WSL

```bash
ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'
```

Допустим, это `172.21.106.163`.

### Шаг 2. `port-forward` с bind на все интерфейсы

```bash
kubectl -n selmag port-forward svc/selmag-config-server-svc 8888:8888 --address 0.0.0.0
```

### Шаг 3. В браузере Windows

```text
http://172.21.106.163:8888
```

> `hosts`-файл Windows всё равно не нужен.

---

# Записи для `hosts`

```text
172.21.106.163 catalogue.api.selm.ag.192.168.49.2.nip.io
172.21.106.163 feedback.api.selm.ag.192.168.49.2.nip.io
172.21.106.163 manager.selm.ag.192.168.49.2.nip.io
172.21.106.163 customer.selm.ag.192.168.49.2.nip.io
172.21.106.163 grafana.selm.ag.192.168.49.2.nip.io
```

---

# Узнать IP-адреса сервиса и его порт внутри pod'а

```bash
kubectl -n selmag get endpointslice -l kubernetes.io/service-name=selmag-api-gateway-svc -o wide
kubectl -n selmag get endpointslice -l kubernetes.io/service-name=selmag-catalogue-service-svc -o wide
```

---

# Observability сервисы

## Применение

```bash
kubectl apply -f k8s/observability/tempo/configmap.yaml
kubectl apply -f k8s/observability/tempo/service.yaml
kubectl apply -f k8s/observability/tempo/deployment.yaml

kubectl apply -f k8s/observability/loki/service.yaml
kubectl apply -f k8s/observability/loki/deployment.yaml

kubectl apply -f k8s/observability/victoria-metrics/configmap-scrape.yaml
kubectl apply -f k8s/observability/victoria-metrics/service.yaml
kubectl apply -f k8s/observability/victoria-metrics/deployment.yaml
kubectl -n selmag port-forward svc/selmag-victoria-metrics-svc 8428:8428

kubectl apply -f k8s/observability/grafana/configmap-datasources.yaml
kubectl apply -f k8s/observability/grafana/service.yaml
kubectl apply -f k8s/observability/grafana/deployment.yaml
```

URL, по которым можно открыть Victoria в браузере на хосте с Виндой:

```text
http://localhost:8428/targets
```

## Перезапуск

```bash
kubectl -n selmag rollout restart deploy/selmag-grafana-deployment
kubectl -n selmag rollout status  deploy/selmag-grafana-deployment

kubectl -n selmag rollout restart deploy/selmag-loki-deployment
kubectl -n selmag rollout status  deploy/selmag-loki-deployment

kubectl -n selmag rollout restart deploy/selmag-tempo-deployment
kubectl -n selmag rollout status  deploy/selmag-tempo-deployment

kubectl -n selmag rollout restart deploy/selmag-victoria-metrics-deployment
kubectl -n selmag rollout status  deploy/selmag-victoria-metrics-deployment
```

### А можно целой пачкой

```bash
for d in \
  selmag-grafana-deployment \
  selmag-loki-deployment \
  selmag-tempo-deployment \
  selmag-victoria-metrics-deployment
do
  kubectl -n selmag rollout restart deploy/$d
  kubectl -n selmag rollout status  deploy/$d
done
```

## Проверки

```bash
kubectl -n selmag get pods -o wide | egrep 'tempo|loki|victoria|grafana'
kubectl -n selmag get svc  | egrep 'tempo|loki|victoria|grafana'
kubectl -n selmag logs deploy/selmag-victoria-metrics-deployment --tail=200
kubectl -n selmag logs deploy/selmag-grafana-deployment --tail=200
```

### Health endpoints изнутри pod’ов

Это хороший smoke test:

```bash
kubectl -n selmag exec -it deploy/selmag-tempo-deployment -- sh -lc 'wget -qO- http://127.0.0.1:3200/ready; echo'
kubectl -n selmag exec -it deploy/selmag-loki-deployment  -- sh -lc 'wget -qO- http://127.0.0.1:3100/ready; echo'
kubectl -n selmag exec -it deploy/selmag-grafana-deployment -- sh -lc 'wget -qO- http://127.0.0.1:3000/api/health | head -n 20'
kubectl -n selmag exec -it deploy/selmag-victoria-metrics-deployment -- sh -lc 'wget -qO- http://127.0.0.1:8428/health; echo'
```

---

# Git diff

Показать только `+/-` строки, без заголовков `diff --git`, `index`, `@@`:

```bash
git diff --no-color --unified=0 | grep -E '^[+-][^+-]'
```

---

# Отдельная заметка из текста

```text
@Лекс , отдельное спасибо за превью и перед матчем и гостя Дмитрия Чельцова. Очень мне схож по взглядам.
Но скажи, что Интер смотрелся хорошо и обозначил слабые места Арсенала.
Потому что Интер мог играть, как минимум, в ничью. Хотя бы отдай должное Дмитрию!)
```

---

# Docker build / push примеры

## Config Server

```bash
docker build \
  -f docker/Dockerfile \
  --build-arg JAR_FILE=config-server/target/config-server-24.1.1-SNAPSHOT-exec.jar \
  -t host.docker.internal:5000/selmag/config-server:24.1.1 \
  .

docker push host.docker.internal:5000/selmag/config-server:24.1.1
```

## Feedback Service

```bash
docker build \
  -f docker/Dockerfile \
  --build-arg JAR_FILE=feedback-service/target/feedback-service-24.1.1-SNAPSHOT-exec.jar \
  -t host.docker.internal:5000/selmag/feedback-service:24.1.1 \
  .

docker push host.docker.internal:5000/selmag/feedback-service:24.1.1
```

---

# Разрозненные рабочие заметки

```text
            - __meta_kubernetes_pod_uid

            replacement: /var/log/pods/*$1/*$2/*.log
```

```bash
kubectl -n selmag-helm exec -it selmag-grafana-deployment-54bd59d995-m66v8 -- sh -c 'apk add --no-cache curl >/dev/null 2>&1 || true; curl -sS http://selmag-loki-svc:3100/ready'

kubectl -n selmag-helm logs selmag-api-gateway-deployment-76b5f6b758-kbjkg --tail=50

curl -G -sS "http://127.0.0.1:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={namespace="selmag-helm",pod="selmag-api-gateway-deployment-76b5f6b758-kbjkg"}' \
  --data-urlencode 'limit=20' \
  --data-urlencode 'start='$(date -u -d '30 minutes ago' +%s%N) \
  --data-urlencode 'end='$(date -u +%s%N) | head
```

```text
http://172.21.106.163:8888/selmag-admin-server-cloudconfig.properties
```

```bash
kubectl -n selmag-helm port-forward svc/selmag-config-server-svc 8888:8888 --address 0.0.0.0
kubectl -n selmag-helm port-forward svc/selmag-admin-server-svc 8085:8085 --address 0.0.0.0
```
