help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "} {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: serve
serve: ## Run Docs Server
	@echo ➤ starting dev server
	@docker run --rm -it -p 8000:8000 -v ${PWD}:/docs squidfunk/mkdocs-material

.PHONY: lint
lint: ## Run linters
	@$(MAKE) lint-lwc
	@$(MAKE) lint-aura
	@$(MAKE) lint-docs

.PHONY: lint-lwc
lint-lwc: ## Lint Lightning Web Components with ESLint
	@echo ➤ linting LWC
	@npx eslint 'force-app/main/default/lwc/**/*.js'

.PHONY: lint-aura
lint-aura: ## Lint Aura components with ESLint
	@echo ➤ linting Aura
	@npx eslint 'force-app/main/default/aura/**/*.js'

.PHONY: lint-docs
lint-docs: ## Lint the documentation for issues
	@echo ➤ linting docs
	@docker run --platform=linux/amd64 --rm -v $(CURDIR):/code -w /code markdownlint/markdownlint **/*.md
