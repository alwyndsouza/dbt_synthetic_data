.PHONY: help data install dbt-deps clean clean-data clean-dbt clean-all

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

data: ## Generate synthetic Parquet data files
	@echo "Generating synthetic data..."
	uv run generate_data.py
	@echo "✓ Data generation complete"

install: ## Create uv environment and install Python dependencies
	@echo "Setting up uv environment..."
	uv sync
	@echo "✓ Python environment ready"

dbt-deps: ## Install dbt packages
	@echo "Installing dbt packages..."
	uv run dbt deps --profiles-dir .
	@echo "✓ dbt packages installed"

env-setup: install dbt-deps ## Setup complete uv environment with all packages
	@echo "✓ Environment setup complete"

setup: env-setup data ## Full setup: environment, packages, and synthetic data
	@echo "✓ Complete setup done - ready to use!"

clean-data: ## Remove generated Parquet files
	@echo "Removing generated data files..."
	rm -f data/raw/*.parquet
	@echo "✓ Data files removed"

clean-dbt: ## Remove dbt artifacts
	@echo "Removing dbt artifacts..."
	rm -rf target/ dbt_packages/ logs/ *.duckdb *.duckdb.wal
	@echo "✓ dbt artifacts removed"

clean: clean-data clean-dbt ## Clean data and dbt artifacts

clean-all: clean ## Complete clean (alias for clean)
	@echo "✓ All artifacts cleaned"
