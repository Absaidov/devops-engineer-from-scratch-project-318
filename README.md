# Доска объявлений (Observability)

[![hexlet-check](https://github.com/Absaidov/devops-engineer-from-scratch-project-318/actions/workflows/hexlet-check.yml/badge.svg)](https://github.com/Absaidov/devops-engineer-from-scratch-project-318/actions)
[![CI приложения](https://github.com/Absaidov/project-devops-deploy/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/Absaidov/project-devops-deploy/actions/workflows/main.yml)

Учебный проект Хекслета по развёртыванию и последующему мониторингу
контейнеризированного приложения «Доска объявлений» в Yandex Cloud.

Приложение доступно по адресам:

- [https://uit14.ru](https://uit14.ru)
- [https://www.uit14.ru](https://www.uit14.ru)

Публичный IP сервера: `89.169.153.112`.

## Приложение и Docker-образ

Исходный код находится в отдельном
[форке приложения](https://github.com/Absaidov/project-devops-deploy). В нём
находятся Dockerfile и CI/CD workflow, который запускает тесты, собирает образ и
публикует его в Yandex Container Registry с неизменяемым тегом — полным SHA
коммита.

Текущий образ:

```text
cr.yandex/crphrkv4imihhuukiv7q/project-devops-deploy:a100ed36995989034cee26c2cfd9e1558201bdaa
```

Для проверки локальной сборки клонируйте форк приложения и выполните в нём:

```bash
make docker-build
```

## Инфраструктура

В Yandex Cloud уже подготовлены:

- виртуальная машина с Ubuntu 24.04 LTS;
- Managed Service for PostgreSQL с базой `bulletins`;
- закрытый бакет Object Storage `uit14-bulletins-images`;
- Yandex Container Registry с образом приложения;
- DNS-записи `uit14.ru` и `www.uit14.ru`;
- Nginx и сертификат Let's Encrypt.

PostgreSQL доступен только с внутреннего IP сервера приложения. Бакет закрыт,
а приложение обращается к нему от имени отдельного сервисного аккаунта.

## Требования

### Управляющий компьютер

- Linux, macOS или Windows с WSL;
- Python 3, Ansible Core 2.18 или новее, Make, Git, cURL и SSH-клиент;
- SSH-ключ для пользователя `ubuntu` на целевом сервере;
- пароль от Ansible Vault;
- доступ в интернет для установки ролей и коллекций Ansible.

### Целевой сервер

- Ubuntu 24.04 LTS, Python 3, `apt` и SSH;
- пользователь с правами `sudo` без запроса пароля;
- исходящий доступ к Container Registry, PostgreSQL и Object Storage;
- открытые входящие TCP-порты `22`, `80` и `443`;
- доступ к Managed PostgreSQL внутри облачной сети.

Docker, Docker Compose, Git, cURL, UFW и Python-библиотека `requests`
устанавливаются подготовительным playbook. Nginx и Certbot устанавливаются во
время деплоя.

## Подготовка к запуску

После клонирования репозитория создайте локальный inventory:

```bash
cp ansible/inventory.ini.example ansible/inventory.ini
```

При необходимости измените IP и SSH-пользователя в `ansible/inventory.ini`.
Этот локальный файл игнорируется Git.

Настоящие секреты зашифрованы по отдельности в
`ansible/group_vars/app/vault.yml`. Структура переменных показана в
`ansible/group_vars/app/vault.yml.example`. Пароль Vault, JSON-ключи и
незашифрованные секреты хранить в репозитории нельзя.

## Команды

Все команды запускаются из корня репозитория.

Установить зафиксированные версии ролей и коллекций Ansible:

```bash
make install
```

Проверить синтаксис playbook:

```bash
make syntax
```

Подготовить новый сервер:

```bash
make prepare
```

Развернуть текущий образ приложения:

```bash
make deploy
```

Развернуть новый образ по полному SHA коммита:

```bash
make deploy IMAGE_TAG=<full-commit-sha>
```

Откатиться на предыдущий стабильный образ:

```bash
make rollback IMAGE_TAG=<previous-full-commit-sha>
```

Роль не принимает изменяемые теги наподобие `latest`.

## Проверка приложения и логов

Проверить главную страницу и API через публичный HTTPS-адрес:

```bash
make check
```

Проверить readiness endpoint на локальном management-порту сервера:

```bash
make health
```

Показать последние 100 строк stdout контейнера:

```bash
make logs
```

Playbook деплоя также автоматически ожидает успешный ответ
`/actuator/health/readiness` перед настройкой Nginx и проверяет редирект с HTTP
на HTTPS.

JSON-логи приложения сохраняются на сервере в
`/srv/project-devops-deploy/logs/application.log` и переживают замену
контейнера. Данные приложения находятся в Managed PostgreSQL, а изображения —
в Object Storage.

## Структура Ansible

Все Ansible-файлы находятся в директории `ansible/`:

- `ansible/playbook.yml` — подготовка целевого сервера;
- `ansible/deploy.yml` — деплой приложения, Nginx и HTTPS;
- `ansible/roles/deploy/` — роль приложения и миграций;
- `ansible/group_vars/app/vars.yml` — открытые параметры окружения;
- `ansible/group_vars/app/vault.yml` — зашифрованные секреты;
- `ansible/requirements.yml` — зафиксированные роли и коллекции;
- `ansible/templates/` — Jinja2-шаблон Nginx.

Подготовительный и основной playbook идемпотентны: повторный запуск применяет
только отсутствующие изменения. Контейнер приложения настроен с политикой
перезапуска `unless-stopped`.

## Ссылки

- [Учебный проект Хекслета](https://ru.hexlet.io/programs/devops-engineer-from-scratch)
- [Демонстрация ожидаемой работы](https://asciinema.org/a/v4evn7XjCdou7Yh71IG0ljb0W)
