# Custom Calendar LWC Guide

This guide provides detailed instructions on deploying, configuring, and using the Custom Calendar Lightning Web Component (LWC).

## Features

- Display a calendar with selectable days.
- Support for multiple calendars with color-coded events.
- Create, edit, and display events.
- Mock data support for local development.

## Project Structure

- **LWC Component**: `customCalendarLWC`
    - `customCalendarLWC.js`: JavaScript logic for the calendar.
    - `customCalendarLWC.html`: HTML template for the calendar UI.
    - `customCalendarLWC.css`: Styling for the calendar.
    - `customCalendarLWC.js-meta.xml`: Metadata configuration for the component.
    - `customCalendarLWC.design`: Design configuration for Experience Builder.
- **Apex Classes**:
    - `CalendarController.cls`: Apex class to fetch and manage calendar data.
    - `CalendarControllerTest.cls`: Test class for `CalendarController`.

## Prerequisites

1. **Salesforce CLI**: Ensure you have the Salesforce CLI installed. You can download it from [Salesforce CLI](https://developer.salesforce.com/tools/sfdxcli).
2. **Authentication**: Authenticate with your Salesforce org using the following command:
    ```bash
    sf login
    ```

## Deployment

To deploy the component and its related Apex classes to your Salesforce org, use the following command:

```bash
sf project deploy start \
    --source-dir force-app/main/default/classes/CalendarController.cls \
    --source-dir force-app/main/default/classes/CalendarControllerTest.cls \
    --source-dir force-app/main/default/lwc/customCalendarLWC \
    --test-level RunSpecifiedTests \
    --tests CalendarControllerTest \
    --target-org webdev5@smi.org
```

### Deployment Notes

- Replace `webdev5@smi.org` with your target org's username if different.
- The `--test-level RunSpecifiedTests` flag ensures that only the specified test class (`CalendarControllerTest`) is executed during deployment.

## Usage

1. After deployment, add the `customCalendarLWC` component to a Lightning App Builder page or an Experience Builder site.
2. Configure the `Calendar Title` property in the Experience Builder to customize the title displayed on the calendar.

## Local Development

To test the component locally:

1. Use the Salesforce CLI to start the local development server:
    ```bash
    sfdx force:lightning:lwc:start
    ```
2. Open the local development server in your browser to view and test the component.

## Testing

The `CalendarControllerTest.cls` class includes unit tests for the `CalendarController` Apex class. These tests are executed during deployment to ensure the functionality is working as expected.

To run the tests manually, use the following command:

```bash
sf apex run test --classnames CalendarControllerTest --target-org webdev5@smi.org
```

## Support

For any issues or questions, please contact the project maintainer or refer to the Salesforce documentation for Lightning Web Components and Apex development.
