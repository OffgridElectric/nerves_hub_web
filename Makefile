make-lazy = $(eval $1 = $$(eval $1 := $(value $(1)))$$($1))

help:
	@echo "Make targets:"
	@echo
	@echo "server - start the server"
	@echo "iex-server - start the server with the interactive shell"
	@echo "reset-db - reinitialize the database"
	@echo "reset-test-db - reinitialize the test database"
	@echo "test - run the unit tests"

.env:
	@echo "Please create a '.env' file first. Copy 'dev.env' to '.env' for a start."
	@exit 1

server: .env
	. ./.env && \
	mix phx.server

iex:
	make iex-server

iex-server: .env
	. ./.env && \
	iex -S mix phx.server

mix:
	iex -S mix

format:
	mix cmd mix format

check-format:
	mix cmd mix format --check-formatted

reset-db: .env
	. ./.env && \
	make rebuild-db

reset-test-db: .env
	DB=db_test \
	MIX_ENV=test \
	make reset-db

rebuild-db:
	mix ecto.drop && \
	mix ecto.create && \
	mix ecto.migrate && \
	mix run apps/nerves_hub_web_core/priv/repo/seeds.exs

test: .env
	DB=db_test \
	. ./.env && \
	mix test

test-watch: .env
	DB=db_test \
	. ./.env && \
	mix test.watch

.PHONY: test rebuild-db reset-db reset-test-db mix iex-server server help

###
### Access to remote instances
###
ifeq ($(ENV),staging)
AWS_CLUSTER=nerves-hub-staging
else ifeq ($(ENV),prod)
AWS_CLUSTER=nerves-hub-prod
else
AWS_CLUSTER=
endif

AWS_SERVICE = nerves-hub-$(SERVICE)
AWS_TASK = $(shell aws ecs list-tasks --cluster $(AWS_CLUSTER) --service $(AWS_SERVICE) | jq '.taskArns[0]' | sed -e 's/"//g')
AWS_CONTAINER = $(shell aws ecs describe-tasks --cluster $(AWS_CLUSTER) --tasks $(AWS_TASK) | jq '.tasks[0].containers[0].name' | sed -e 's/"//g')

$(call make-lazy,AWS_TASK)
$(call make-lazy,AWS_CONTAINER)

console: remote-prereqs  ## Connects to elixir console of running instance (iex)

shell: remote-prereqs ## Connects to shell of running instance

ifneq ($(findstring local,$(ENV)),)
console: console-local

shell: shell-local
else
console: console-aws

shell: shell-aws
endif

console-aws:
	@echo "Not implemented"

console-local: $(release)
	@echo "Not implemented"

shell-aws:
	aws ecs execute-command \
		--cluster $(AWS_CLUSTER) \
		--task $(AWS_TASK) \
		--container $(AWS_CONTAINER) \
		--interactive \
		--command "/bin/sh"

shell-local:
	@echo "You are here!"

remote-prereqs: remote-check-env remote-check-service

ifeq ($(ENV),staging)
remote-check-env:
else ifeq ($(ENV),prod)
remote-check-env:
else ifeq ($(ENV),local)
remote-check-env:
else
remote-check-env:
	@echo "ENV must be set to staging | prod | local"; false
endif

ifeq ($(SERVICE),ca)
remote-check-service:
else ifeq ($(SERVICE),api)
remote-check-service:
else ifeq ($(SERVICE),device)
remote-check-service:
else ifeq ($(SERVICE),www)
remote-check-service:
else
remote-check-service:
	@echo "SERVICE must be set to ca | api | device | www"; false
endif

.PHONY: console console-local console-aws shell shell-local shell-aws
