###
#
##

START := mvn clean spring-boot:run

LAB_DIRECTORY = apps-spring-cloud-services-labs
CONFIG_SERVER = $(LAB_DIRECTORY)/config-server
SERVICE_REGISTRY = $(LAB_DIRECTORY)/service-registry
FORTUNE_SERVICE = $(LAB_DIRECTORY)/fortune-service
GREETING_FRONTEND = $(LAB_DIRECTORY)/greeting-frontend
GATEWAY_APP = $(LAB_DIRECTORY)/gateway-app

APP_FORTUNE_SERVICE = fortune-service
APP_GREETING_FRONTEND = greeting-frontend
APP_CONFIG_SERVER = config-server
APP_SERVICE_REGISTRY = service-registry
APP_GATEWAY_APP = gateway-app

define assertIsStarted =
	until [ $$(cf services | awk '{ if ($$1 == "$(1)") { print $$6; } }') == "started" ]; do sleep 2; done
endef

getGreetingUrl := cf apps | awk '{ if ($$1 == "$(APP_GREETING_FRONTEND)") { print $$6; } }'
getFortuneUrl := cf apps | awk '{ if ($$1 == "$(APP_FORTUNE_SERVICE)") { print $$6; } }'
getGatewayUrl := cf apps | awk '{ if ($$1 == "$(APP_GATEWAY_APP)") { print $$6; } }'

.PHONY: *

# TODO - How to run multiple maven processes in foreground simultaneously
start:
	[ -d logs ] || mkdir logs
	cd $(PWD)/$(CONFIG_SERVER) && $(START) > $(PWD)/logs/config-server.log 2>&1 &
	cd $(PWD)/$(SERVICE_REGISTRY) && $(START) > $(PWD)/logs/service-registry.log 2>&1 &
	cd $(PWD)/$(FORTUNE_SERVICE) && $(START) > $(PWD)/logs/fortune-service.log 2>&1 &
	cd $(PWD)/$(GREETING_FRONTEND) && $(START) > $(PWD)/logs/greeting-frontend.log 2>&1 &
	cd $(PWD)/$(GATEWAY_APP) && $(START) > $(PWD)/logs/gateway-app.log 2>&1 &
# start

deploy: deploy_service_registry deploy_config_server deploy_fortune_service deploy_greeting_frontend deploy_gateway_app
# deploy

deploy_fortune_service:
	cd $(FORTUNE_SERVICE) && mvn clean package
	cd $(FORTUNE_SERVICE) && cf push $(APP_FORTUNE_SERVICE) -p target/$(APP_FORTUNE_SERVICE)-0.0.1-SNAPSHOT.jar -m 1G --random-route --no-start
	cf bind-service $(APP_FORTUNE_SERVICE) $(APP_CONFIG_SERVER)
	cf bind-service $(APP_FORTUNE_SERVICE) $(APP_SERVICE_REGISTRY)
	cf set-env $(APP_FORTUNE_SERVICE) TRUST_CERTS $$($(getFortuneUrl))
	cf start $(APP_FORTUNE_SERVICE)
# deploy_fortune_service

deploy_greeting_frontend:
	cd $(GREETING_FRONTEND) && mvn clean package
	cd $(GREETING_FRONTEND) && cf push $(APP_GREETING_FRONTEND) -p target/$(APP_GREETING_FRONTEND)-0.0.1-SNAPSHOT.jar -m 512M --random-route --no-start
	cf bind-service $(APP_GREETING_FRONTEND) $(APP_CONFIG_SERVER)
	cf bind-service $(APP_GREETING_FRONTEND) $(APP_SERVICE_REGISTRY)
	cf set-env $(APP_GREETING_FRONTEND) TRUST_CERTS $$($(getGreetingUrl))
	cf start $(APP_GREETING_FRONTEND)
# deploy_greeting_frontend

deploy_gateway_app:
	cd $(GATEWAY_APP) && mvn clean package
	cd $(GATEWAY_APP) && cf push $(APP_GATEWAY_APP) -p target/$(APP_GATEWAY_APP)-0.0.1-SNAPSHOT.jar -m 512M --random-route --no-start
	cf bind-service $(APP_GATEWAY_APP) $(APP_CONFIG_SERVER)
	cf bind-service $(APP_GATEWAY_APP) $(APP_SERVICE_REGISTRY)
	cf set-env $(APP_GATEWAY_APP) TRUST_CERTS $$($(getGatewayUrl))
	cf start $(APP_GATEWAY_APP)
# deploy_greeting_frontend

deploy_config_server:
	cf create-service p-config-server standard $(APP_CONFIG_SERVER) -c ./app.json
	$(call assertIsStarted,$(APP_CONFIG_SERVER))
# deploy_config_server

deploy_service_registry:
	cf create-service p-service-registry standard $(APP_SERVICE_REGISTRY)
	$(call assertIsStarted,$(APP_SERVICE_REGISTRY))
# deploy_service_registry

cleanup:
	cf delete $(APP_FORTUNE_SERVICE) -f
	cf delete $(APP_GREETING_FRONTEND) -f
	cf delete-service $(APP_CONFIG_SERVER) -f
	cf delete-service $(APP_SERVICE_REGISTRY) -f
# cleanup

# Makefile
