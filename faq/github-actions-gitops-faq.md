# FAQ: CI/CD и GitOps в проекте (GitHub Actions + ArgoCD + Helm)

Этот документ объясняет **как в проект был добавлен CI/CD pipeline**,
как он работает и как его проверять.

Документ предназначен для разработчиков, которые впервые открывают
репозиторий.

------------------------------------------------------------------------

# 1. Где находятся pipeline файлы

Pipeline в GitHub называется **GitHub Actions**.

Все workflow файлы должны лежать строго в папке:

    .github/workflows/

В нашем проекте используются два pipeline:

    .github/workflows/ci-pr.yml
    .github/workflows/gitops-ci.yml

Именно эти два файла управляют всей автоматизацией.

------------------------------------------------------------------------

# 2. Как добавить GitHub Actions в проект

### Шаг 1

Создать папку:

``` bash
mkdir -p .github/workflows
```

### Шаг 2

Добавить workflow файлы:

    .github/workflows/ci-pr.yml
    .github/workflows/gitops-ci.yml

### Шаг 3

Закоммитить изменения:

``` bash
git add .github/workflows
git commit -m "Add CI/CD workflows"
git push
```

После этого GitHub автоматически начнёт запускать pipeline.

------------------------------------------------------------------------

# 3. Где смотреть выполнение pipeline

Открыть вкладку:

    Repository → Actions

Там отображаются все pipeline.

Pipeline запускаются автоматически при:

Событие   Что запускается
  --------- -----------------
PR        CI pipeline
merge     GitOps pipeline

------------------------------------------------------------------------

# 4. Первый pipeline --- CI проверка Pull Request

Файл:

    .github/workflows/ci-pr.yml

Запускается при создании Pull Request:

``` yaml
on:
  pull_request:
    branches:
      - kubernetes-test-helm
```

Этот pipeline делает только одно:

    build + tests

Команда:

    mvn verify

Если тесты не проходят --- PR нельзя мержить.

------------------------------------------------------------------------

# 5. Второй pipeline --- GitOps CI

Файл:

    .github/workflows/gitops-ci.yml

Запускается при:

    push в kubernetes-test-helm

Он выполняет:

1.  сборку jar
2.  сборку docker images
3.  push images в GHCR
4.  создание PR с обновлением Helm тегов

------------------------------------------------------------------------

# 6. Где хранятся Docker images

Все образы публикуются в:

    GitHub Container Registry

URL:

    https://github.com/<owner>/<repo>/packages

Пример:

    ghcr.io/gitueser/selmag/admin-server
    ghcr.io/gitueser/selmag/api-gateway

Теги образов:

    sha-<commit hash>

Пример:

    sha-da4518d

Это обеспечивает **immutable deployment**.

------------------------------------------------------------------------

# 7. Как собираются Docker images

Pipeline выполняет:

    mvn package

Создаются jar:

    */target/*-exec.jar

Затем выполняется:

    docker build
    docker push

Dockerfile лежит в:

    docker/Dockerfile

------------------------------------------------------------------------

# 8. Почему используется tag = sha

Каждый образ получает тег:

    sha-<short commit hash>

Пример:

    sha-da4518d

Это позволяет:

-   точно определить версию
-   избежать latest
-   воспроизводить deployment

------------------------------------------------------------------------

# 9. Как обновляются Helm манифесты

После сборки pipeline автоматически создаёт PR:

    ci/update-image-tags-<sha>

Он обновляет:

    helm/selmag/subcharts/services/*/values.yaml

Пример:

``` yaml
image:
  repository: ghcr.io/gitueser/selmag/admin-server
  tag: "sha-da4518d"
```

После merge этого PR ArgoCD делает deploy.

------------------------------------------------------------------------

# 10. Как работает ArgoCD

ArgoCD использует GitOps.

Он следит за веткой:

    kubernetes-test-helm

Когда меняется Helm манифест:

    tag: sha-xxxx

ArgoCD делает:

    sync
    ↓
    deployment update
    ↓
    pod restart

------------------------------------------------------------------------

# 11. Где лежат ArgoCD манифесты

ArgoCD приложения находятся в репозитории:

    argocd/apps/

Главный файл:

    argocd/apps/root.yaml

В нём указана ветка:

``` yaml
targetRevision: kubernetes-test-helm
```

------------------------------------------------------------------------

# 12. Как проверить какие образы запущены в Kubernetes

Команда:

``` bash
kubectl -n selmag-helm get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.containerStatuses[*]}  {.name}{"\n"}    image:   {.image}{"\n"}    imageID: {.imageID}{"\n"}{end}{"\n"}{end}'
```

Пример результата:

    admin-server
    image: ghcr.io/gitueser/selmag/admin-server:sha-da4518d
    imageID: sha256:4ece8dc988c...

------------------------------------------------------------------------

# 13. Как проверить digest образа

Сравнить:

1️⃣ digest в Kubernetes

    imageID: sha256:XXXX

2️⃣ digest в GHCR

Открыть:

    Packages → service → version

Если совпадает --- значит кластер использует правильный образ.

------------------------------------------------------------------------

# 14. Что не входит в pipeline

Pipeline собирает **только сервисы**.

Он **не собирает**:

компонент
---------------------
MongoDB
PostgreSQL
Keycloak
observability stack

Эти сервисы используются как инфраструктура.

------------------------------------------------------------------------

# 15. Почему базы данных не собираются в pipeline

В production БД обычно:

-   managed services
-   отдельные сервера
-   backup policies

Поэтому они не входят в CI pipeline.

------------------------------------------------------------------------

# 16. Полный flow разработки

1️⃣ создать ветку

    git checkout -b feature/my-feature

2️⃣ push

    git push origin feature/my-feature

3️⃣ создать PR

    feature → kubernetes-test-helm

4️⃣ CI pipeline проверяет код

5️⃣ merge

6️⃣ GitOps pipeline:

    build images
    push images
    create PR for helm tags

7️⃣ merge PR

8️⃣ ArgoCD deploy

------------------------------------------------------------------------

# 17. Как вручную проверить deployment

    kubectl get pods -n selmag-helm

    kubectl describe pod <pod>

------------------------------------------------------------------------

# 18. Где проверять ArgoCD

Открыть:

    ArgoCD UI

Там можно увидеть:

    Healthy
    Progressing
    OutOfSync

------------------------------------------------------------------------

# 19. Итоговая схема

    Developer
      ↓
    Pull Request
      ↓
    CI pipeline
      ↓
    Merge
      ↓
    Build Docker images
      ↓
    Push to GHCR
      ↓
    Bot PR updates Helm
      ↓
    Merge PR
      ↓
    ArgoCD detects change
      ↓
    Deploy to Kubernetes
