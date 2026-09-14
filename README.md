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
- TCP-порты `9090` и `9100`, разрешённые только с внутреннего адреса сервера
  мониторинга;
- доступ к Managed PostgreSQL внутри облачной сети.

Docker, Docker Compose, Git, cURL, UFW, Node Exporter, rsyslog и необходимые
Python-библиотеки устанавливаются подготовительным playbook. Nginx и Certbot
устанавливаются во время деплоя.

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

Для Basic Auth management endpoint создайте отдельный пароль:

```bash
ansible-vault encrypt_string --ask-vault-pass --name vault_monitoring_basic_auth_password
```

Введите новый пароль для пользователя мониторинга, завершите ввод сочетанием
`Ctrl+D` и добавьте полученный YAML-блок в
`ansible/group_vars/app/vault.yml`. Используйте тот же пароль Ansible Vault,
которым уже зашифрованы остальные значения.

Пока отдельного сервера мониторинга нет, параметр
`monitoring_allowed_cidrs` в `ansible/group_vars/app/vars.yml` оставлен пустым:
порты метрик недоступны извне. После создания сервера мониторинга добавьте туда
его внутренний адрес с маской `/32`, например `192.168.1.30/32`, и разрешите
тот же источник для TCP `9090` и `9100` в Security Group Yandex Cloud. Не
открывайте эти порты для `0.0.0.0/0`.

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

Проверить доступность метрик приложения и Node Exporter с управляющего
компьютера через Ansible:

```bash
make metrics
make node-metrics
```

Playbook деплоя также автоматически ожидает успешный ответ
`/actuator/health/readiness` перед настройкой Nginx и проверяет редирект с HTTP
на HTTPS.

JSON-логи приложения сохраняются на сервере в
`/srv/project-devops-deploy/logs/application.log` и переживают замену
контейнера. Данные приложения находятся в Managed PostgreSQL, а изображения —
в Object Storage.

## Node Exporter и метрики приложения

Подготовительный playbook устанавливает Node Exporter как systemd-сервис и
включает дополнительные коллекторы `systemd` и `processes`. Его endpoint —
`http://<app-host>:9100/metrics`. Доступ к порту ограничивается UFW и Security
Group адресом сервера мониторинга.

Actuator внутри контейнера работает на порту `9090`, опубликованном на сервере
только как `127.0.0.1:19090`. Nginx слушает management-порт `9090` и
проксирует только следующие защищённые Basic Auth адреса:

- `/actuator/prometheus`;
- `/actuator/health`;
- `/actuator/health/liveness`;
- `/actuator/health/readiness`.

Остальные Actuator endpoint, включая `/actuator/logfile`, через Nginx не
доступны. Имя пользователя задаётся открытой переменной
`monitoring_basic_auth_username`, пароль хранится только в Ansible Vault.

### Обязательные метрики

| Источник | Что контролируем | Метрики Prometheus |
|---|---|---|
| Node Exporter | CPU и load average | `node_cpu_seconds_total`, `node_load1`, `node_load5`, `node_load15` |
| Node Exporter | Память | `node_memory_MemTotal_bytes`, `node_memory_MemAvailable_bytes` |
| Node Exporter | Файловые системы | `node_filesystem_size_bytes`, `node_filesystem_avail_bytes` |
| Node Exporter | Операции с дисками | `node_disk_read_bytes_total`, `node_disk_written_bytes_total` |
| Node Exporter | Сеть | `node_network_receive_bytes_total`, `node_network_transmit_bytes_total` |
| Node Exporter | Процессы | `node_procs_running`, `node_procs_blocked`, `node_processes_pids`, `node_processes_state` |
| Node Exporter | Системные сервисы | `node_systemd_unit_state`, `node_systemd_service_restart_total` |
| Node Exporter | Сам exporter | `node_exporter_build_info`, `node_scrape_collector_success` |
| Приложение | Запуск и доступность | `process_uptime_seconds`, `application_started_time_seconds`, `application_ready_time_seconds` |
| Приложение | CPU | `process_cpu_usage`, `system_cpu_usage`, `system_load_average_1m` |
| Приложение | JVM и сборка мусора | `jvm_memory_used_bytes`, `jvm_gc_pause_seconds_count`, `jvm_gc_pause_seconds_sum` |
| Приложение | HTTP-запросы | `http_server_requests_seconds_count`, `http_server_requests_seconds_sum`, `http_server_requests_seconds_bucket` |
| Приложение | Пул соединений с БД | `hikaricp_connections_active`, `hikaricp_connections_pending`, `jdbc_connections_active` |
| Приложение | События логирования | `logback_events_total` |

### Проверка через curl

На сервере приложения можно проверить оба экспортера локально:

```bash
ssh ubuntu@89.169.153.112
curl --fail http://127.0.0.1:9100/metrics
curl --fail http://127.0.0.1:19090/actuator/prometheus
curl --fail http://127.0.0.1:19090/actuator/health/readiness
```

Проверка именно через Nginx на management-порту (команда запросит пароль
Basic Auth):

```bash
curl --fail --user prometheus http://127.0.0.1:9090/actuator/prometheus
curl --fail --user prometheus http://127.0.0.1:9090/actuator/health/readiness
```

С сервера мониторинга вместо `127.0.0.1` используется внутренний IP сервера
приложения. Это сработает после добавления его `/32` в UFW и Security Group.

Access-логи Nginx записываются в JSON по путям
`/var/log/nginx/access-json.log` и
`/var/log/nginx/management-access-json.log`. Нативный error log Nginx
направляется в локальный syslog, а rsyslog преобразует каждую запись в JSON и
сохраняет её в `/var/log/nginx/error-json.ndjson`.

## Структура Ansible

Все Ansible-файлы находятся в директории `ansible/`:

- `ansible/playbook.yml` — подготовка целевого сервера;
- `ansible/deploy.yml` — деплой приложения, Nginx и HTTPS;
- `ansible/roles/deploy/` — роль приложения и миграций;
- `ansible/roles/node_exporter/` — установка и настройка Node Exporter;
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
