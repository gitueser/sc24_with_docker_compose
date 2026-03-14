# Kubernetes / Helm — операции развёртывания и диагностики (selmag)

---

# 0. Общие предпосылки (всегда)

Контекст и namespace.

```bash
kubectl config current-context
kubectl get ns | grep selmag-helm
```

Если namespace нет:

```bash
kubectl create ns selmag-helm
```

---

# 1. Полный цикл развёртывания всего кластера (umbrella chart)

## 1.1 Линт Helm-чарта

```bash
helm lint helm/selmag
```

Проверяет:

- синтаксис шаблонов
- values / templates consistency

---

## 1.2 Обновление зависимостей

```bash
helm dependency update helm/selmag
```

Обязательно выполнять:

- после изменения `Chart.yaml`
- после добавления / удаления сервиса

---

## 1.3 Рендер + применение манифестов

```bash
helm template selmag helm/selmag -n selmag-helm \
| kubectl apply -n selmag-helm -f -
```

Что происходит:

- Helm рендерит YAML
- Kubernetes применяет его как обычные манифесты
- Никакого `helm release state` → всё прозрачно и удобно дебажить

---

## 1.4 Проверка, что всё поднялось

```bash
kubectl -n selmag-helm get all,ingress,pvc,cm,secret
```

---

# 2. Общие команды диагностики (для любого сервиса)

## 2.1 Статус pod’ов

```bash
kubectl -n selmag-helm get pods
```

---

## 2.2 Логи (последние 200 строк)

```bash
kubectl -n selmag-helm logs deploy/<deployment-name> --tail=200
```

Пример:

```bash
kubectl -n selmag-helm logs deploy/selmag-api-gateway-deployment --tail=200
```

---

## 2.3 Перезапуск сервиса

```bash
kubectl -n selmag-helm rollout restart deploy/<deployment-name>
```

---

## 2.4 Статус rollout

```bash
kubectl -n selmag-helm rollout status deploy/<deployment-name> --timeout=300s
```

---

## 2.5 Вход внутрь pod’а

```bash
kubectl -n selmag-helm exec -it deploy/<deployment-name> -- sh
```

---

## 2.6 Внутрикластерная HTTP‑проверка

```bash
kubectl -n selmag-helm run tmp-curl --rm -it --restart=Never \
  --image=curlimages/curl -- sh
```

Внутри контейнера:

```bash
curl -i http://<service-name>:<port>/
```

---

# 3. ConfigMap / Secret (bootstrap)

Проверка, что они созданы:

```bash
kubectl -n selmag-helm get cm selmag-config
kubectl -n selmag-helm get secret selmag-secret
```

Посмотреть ключи:

```bash
kubectl -n selmag-helm describe cm selmag-config
kubectl -n selmag-helm describe secret selmag-secret
```

---

# 4. Keycloak

## 4.1 Проверка pod’а

```bash
kubectl -n selmag-helm get pod -l app=selmag-keycloak
```

---

## 4.2 Проверка realm import

```bash
kubectl -n selmag-helm get secret selmag-keycloak-realm
```

---

## 4.3 Проверка HTTP

```bash
curl -I http://keycloak.selm.ag.192.168.49.2.nip.io
```

---

## 4.4 UI

- Realm `selmag`
- Clients, roles, users — из `selmag-minikube.json`

---

# 5. Eureka Server

## 5.1 Проверка доступности

```bash
curl -I http://eureka.selm.ag.192.168.49.2.nip.io
```

---

## 5.2 Проверка зарегистрированных сервисов

```bash
kubectl -n selmag-helm run tmp-curl --rm -it --restart=Never \
  --image=curlimages/curl -- \
  sh -lc 'curl -sS http://selmag-eureka-server-svc:8761/eureka/apps'
```

Фильтр:

```bash
grep SELMAG
```

---

# 6. Config Server

Проверка выдачи конфигурации:

```bash
curl http://<config-server-ip>:8888/<app-name>-cloudconfig.properties
```

Пример:

```bash
curl http://selmag-config-server-svc:8888/selmag-admin-server-cloudconfig.properties
```

---

# 7. Spring Boot Admin

Проверка UI:

```
http://localhost:8085
```

(через ingress или port-forward)

Проверка зарегистрированных приложений:

- все сервисы должны быть **UP**
- количество инстансов = `replicaCount`

---

# 8. API Gateway

## 8.1 Readiness

```bash
kubectl -n selmag-helm exec deploy/selmag-api-gateway-deployment -- \
  curl -i http://127.0.0.1:8086/actuator/health/readiness
```

---

## 8.2 Ingress

```bash
kubectl -n selmag-helm describe ingress selmag-api-gateway-ingress
```

---

## 8.3 Проверка маршрутов

```bash
curl http://catalogue.api.selm.ag.192.168.49.2.nip.io
curl http://feedback.api.selm.ag.192.168.49.2.nip.io
```

---

# 9. Catalogue / Feedback / Customer / Manager services

Для каждого сервиса одинаково.

## Статус

```bash
kubectl -n selmag-helm get deploy <deployment-name>
```

---

## Логи

```bash
kubectl -n selmag-helm logs deploy/<deployment-name> --tail=200
```

---

## Проверка через gateway

```bash
curl http://<host>/<path>
```

---

# 10. PostgreSQL / MongoDB

## PVC

```bash
kubectl -n selmag-helm get pvc
```

---

## StatefulSet

```bash
kubectl -n selmag-helm get sts
```

---

## Проверка подключения

PostgreSQL:

```bash
kubectl -n selmag-helm exec -it pod/selmag-catalogue-db-0 -- psql -U <user>
```

MongoDB:

```bash
kubectl -n selmag-helm exec -it pod/selmag-feedback-db-0 -- mongosh
```

---

# 11. Применение изменений в одном сервисе

Пример: изменён `postgres-catalogue/templates/pvc.yaml`

```bash
helm template selmag helm/selmag -n selmag-helm \
| kubectl apply -n selmag-helm -f -
```

Проверка:

```bash
kubectl -n selmag-helm describe pvc selmag-catalogue-db-pvc
```

Если `PVC immutable` → удалить namespace или PVC вручную.

---

# 12. Полная “хардкорная” очистка

```bash
kubectl delete ns selmag-helm
kubectl create ns selmag-helm
```

Далее — полный цикл из пункта **1**.
