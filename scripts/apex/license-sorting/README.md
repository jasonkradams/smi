# License Sorting Scripts

This folder contains all scripts related to the automated license sorting system.

## Setup Scripts

- **`grant_fls_fiscal_year_login_history.apex`**: Grants Field-Level Security (FLS) access to System Administrator profile for all `Fiscal_Year_Login_History__c` fields. Run this after deploying the custom object.

- **`migrate_login_history_initial.apex`**: Executes `LoginHistoryMigrationBatch` to backfill the last 6 months of LoginHistory data into `Fiscal_Year_Login_History__c`. Run this once during initial setup.

## Utility Scripts

- **`check_user_login_counts.apex`**: Checks a specific user's current state and login count for debugging purposes. Edit the `userId` variable at the top to check different users.

- **`user_login_count_fiscal_year.apex`**: Calculates and displays login counts for users based on fiscal year logic. Useful for verifying login counting behavior.

- **`license_count_by_type.apex`**: Lists all active Community users and their license types (Premium vs Login). Helps verify current license distribution.

- **`check_license_change_logs.apex`**: Queries and displays `License_Change_Log__c` records to verify logging functionality. Shows all custom field values.

- **`verify_login_history.apex`**: Verifies LoginHistory records exist for test users. Useful during testing with artificial login data.

## Manual Execution

- **`run_license_monitor_manually.apex`**: Manually triggers `LicenseShuffleBatch` for immediate license optimization. Useful for testing or manual optimization runs.

## Usage

All scripts are designed to be run in Anonymous Apex (Salesforce Developer Console or VS Code with Salesforce CLI).

Example:
```bash
sf apex run --target-org staging --file scripts/apex/license-sorting/grant_fls_fiscal_year_login_history.apex
```

