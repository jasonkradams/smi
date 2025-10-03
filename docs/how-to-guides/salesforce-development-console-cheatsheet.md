# Salesforce Development Console Cheatsheet

This page is a quick reference for using the Salesforce Developer Console, including common tasks and useful tips.

---

## Frequently Used Queries

- List all standard and custom objects:
    ```sql
    SELECT QualifiedApiName
    FROM EntityDefinition
    ORDER BY QualifiedApiName
    ```

## Frequently Used Commands

- List all fields related to a specific object using `sf`
    ```shell
    sf force:schema:sobject:describe -s Event_Participant__c | jq -r .fields[].name
    ```
