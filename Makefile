ANSIBLE_DIR ?= ansible
ANSIBLE ?= ansible
ANSIBLE_PLAYBOOK ?= ansible-playbook
ANSIBLE_GALAXY ?= ansible-galaxy
INVENTORY ?= $(ANSIBLE_DIR)/inventory.ini
PREPARE_PLAYBOOK ?= $(ANSIBLE_DIR)/playbook.yml
DEPLOY_PLAYBOOK ?= $(ANSIBLE_DIR)/deploy.yml
PROMETHEUS_PLAYBOOK ?= $(ANSIBLE_DIR)/prometheus.yml
PROMETHEUS_CHECK_PLAYBOOK ?= $(ANSIBLE_DIR)/prometheus-check.yml
REQUIREMENTS_FILE ?= $(ANSIBLE_DIR)/requirements.yml
APP_GROUP ?= app
MONITORING_GROUP ?= monitoring
APP_URL ?= https://uit14.ru
MANAGEMENT_BACKEND_PORT ?= 19090
NODE_EXPORTER_PORT ?= 9100
CONTAINER_NAME ?= project-devops-deploy
PROMETHEUS_CONTAINER_NAME ?= prometheus
IMAGE_TAG ?=

.PHONY: install syntax prepare deploy rollback check health metrics \
	node-metrics logs monitoring-deploy prometheus-check \
	prometheus-config-check prometheus-logs

install:
	$(ANSIBLE_GALAXY) install -r $(REQUIREMENTS_FILE)

syntax:
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PREPARE_PLAYBOOK) --syntax-check
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(DEPLOY_PLAYBOOK) --syntax-check
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PROMETHEUS_PLAYBOOK) --syntax-check
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PROMETHEUS_CHECK_PLAYBOOK) --syntax-check

prepare:
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PREPARE_PLAYBOOK)

deploy:
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(DEPLOY_PLAYBOOK) --ask-vault-pass $(if $(IMAGE_TAG),--extra-vars "deploy_image_tag=$(IMAGE_TAG)",)

rollback:
	@test -n "$(IMAGE_TAG)" || { echo "Usage: make rollback IMAGE_TAG=<full-commit-sha>"; exit 1; }
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(DEPLOY_PLAYBOOK) --ask-vault-pass --extra-vars "deploy_image_tag=$(IMAGE_TAG)"

check:
	curl --fail --silent --show-error --location --output /dev/null "$(APP_URL)/"
	curl --fail --silent --show-error --location --output /dev/null "$(APP_URL)/api/bulletins"
	@echo "Application endpoints are available at $(APP_URL)"

health:
	$(ANSIBLE) -i $(INVENTORY) $(APP_GROUP) --become -m ansible.builtin.uri -a "url=http://127.0.0.1:$(MANAGEMENT_BACKEND_PORT)/actuator/health/readiness method=GET status_code=200 timeout=5"

metrics:
	$(ANSIBLE) -i $(INVENTORY) $(APP_GROUP) --become -m ansible.builtin.uri -a "url=http://127.0.0.1:$(MANAGEMENT_BACKEND_PORT)/actuator/prometheus method=GET status_code=200 timeout=5"

node-metrics:
	$(ANSIBLE) -i $(INVENTORY) $(APP_GROUP) --become -m ansible.builtin.uri -a "url=http://127.0.0.1:$(NODE_EXPORTER_PORT)/metrics method=GET status_code=200 timeout=5"

logs:
	$(ANSIBLE) -i $(INVENTORY) $(APP_GROUP) --become -m ansible.builtin.command -a "docker logs --tail 100 $(CONTAINER_NAME)"

monitoring-deploy:
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PROMETHEUS_PLAYBOOK) --ask-vault-pass

prometheus-check:
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PROMETHEUS_CHECK_PLAYBOOK) --tags targets

prometheus-config-check:
	$(ANSIBLE_PLAYBOOK) -i $(INVENTORY) $(PROMETHEUS_CHECK_PLAYBOOK) --tags config

prometheus-logs:
	$(ANSIBLE) -i $(INVENTORY) $(MONITORING_GROUP) --become -m ansible.builtin.command -a "docker logs --tail 100 $(PROMETHEUS_CONTAINER_NAME)"
