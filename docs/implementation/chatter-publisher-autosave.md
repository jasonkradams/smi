# Chatter Publisher with Autosave Implementation

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Implementation Details](#implementation-details)
- [Component Details](#component-details)
- [Testing Strategy](#testing-strategy)
- [Deployment Instructions](#deployment-instructions)
- [Lessons Learned](#lessons-learned)

## Overview

This implementation provides a custom Lightning Web Component that replaces the standard Chatter publisher with autosave capabilities to prevent loss of drafted messages when composing updates to activity groups.

### The Problem

Members were losing composed Chatter posts when:

- Browser windows needed updates or crashed
- Users navigated away from the page accidentally
- Sessions timed out requiring re-login
- Browsers were closed without posting

The standard Salesforce Chatter publisher in Experience Cloud provides no draft saving functionality, resulting in frustration and wasted time, especially for longer or more thoughtful messages to activity groups.

### The Solution

A custom Lightning Web Component (`chatterPublisherWithAutosave`) that provides:

1. **Automatic Draft Saving** - Saves to browser localStorage every 10 seconds after typing stops
2. **Rich Text Support** - Full formatting preservation (bold, italic, lists, links, etc.)
3. **Draft Restoration** - Prompts users to restore saved drafts when returning to pages
4. **Navigation Warnings** - Warns users before leaving with unsaved changes
5. **Visual Feedback** - Shows "Draft saved" with relative timestamps
6. **Draft Expiration** - Auto-expires drafts older than 7 days
7. **Per-Group Drafts** - Each Chatter group maintains its own separate draft

### Goals

1. Prevent loss of composed messages across all user scenarios
2. Support rich text formatting in drafts
3. Provide seamless user experience with minimal friction
4. Work reliably across browser sessions and crashes
5. Ensure comprehensive test coverage for Apex controllers

## Architecture

### Component Overview

```
Chatter Autosave System
│
├── chatterPublisherWithAutosave (Lightning Web Component)
│   ├── chatterPublisherWithAutosave.js (Component logic)
│   ├── chatterPublisherWithAutosave.html (Template)
│   ├── chatterPublisherWithAutosave.css (Styling)
│   └── chatterPublisherWithAutosave.js-meta.xml (Metadata)
│
├── ChatterPublisherController.cls (Apex Controller)
│   └── ChatterPublisherControllerTest.cls (Test Class)
│
└── Configuration
    └── Experience Builder (Component Placement)
```

### Key Design Decisions

**Lightning Web Component Over Aura**: We chose LWC because:

- Modern framework with better performance
- Native support for localStorage and browser APIs
- Better developer experience and tooling
- `lightning-input-rich-text` component provides robust formatting
- Easier to maintain and extend

**localStorage for Draft Persistence**: We chose browser localStorage over server-side storage because:

- Instant save with no network latency
- Works offline and survives browser restarts
- No additional database objects or storage limits needed
- Simpler implementation and faster user experience
- Drafts automatically scoped to device/browser (privacy benefit)

**Debounced Autosave**: Draft saving uses a 10-second debounce to:

- Avoid excessive localStorage writes
- Balance responsiveness with performance
- Match user expectations from other editing tools

**Rich Text HTML Storage**: We store full HTML rather than plain text to:

- Preserve all formatting applied by users
- Support restoration of complex content
- Allow for future enhancement of formatting options

## Implementation Details

### localStorage Key Structure

Drafts are stored with keys in the format:

```
chatterDraft_<groupId>
```

Each Chatter group maintains its own separate draft, allowing users to have in-progress posts for multiple groups simultaneously.

### Draft Data Structure

```javascript
{
  "content": "<p>Draft message content with HTML</p>",
  "timestamp": "2026-02-08T10:30:00.000Z",
  "groupId": "0F9xxxxxxxxxx"
}
```

### Autosave Flow

1. User types in rich text editor
2. Component detects change via `onchange` event
3. Debounce timer starts (10 seconds)
4. If user stops typing, timer fires and saves to localStorage
5. Visual indicator shows "Draft saved X minutes ago"
6. On page load, component checks for existing draft
7. If found and not expired, shows restoration modal
8. User can restore or discard draft

### Navigation Warning Flow

1. User starts typing (sets `hasUnsavedChanges = true`)
2. On successful save to localStorage, flag cleared
3. `beforeunload` event listener checks flag
4. If unsaved changes exist, browser shows native confirmation dialog
5. User can choose to stay or leave page

### Draft Expiration

- Drafts expire after 7 days
- Cleanup runs on component initialization
- Expired drafts are automatically removed from localStorage
- Prevents storage bloat from abandoned drafts

## Component Details

### ChatterPublisherWithAutosave (LWC)

**Purpose**: Provides custom Chatter publisher with autosave functionality

**Key Properties**:

```javascript
@api groupId; // Can be set explicitly or auto-detected from page
_internalGroupId; // Auto-detected from CurrentPageReference
effectiveGroupId; // Computed property that returns groupId || _internalGroupId
```

**Key Methods**:

```javascript
handleTextChange(event);
```

Responds to text changes in the rich text editor:

1. Updates `draftContent` with new value
2. Sets `hasUnsavedChanges` flag
3. Clears existing debounce timeout
4. Sets new 10-second timeout for autosave

```javascript
saveDraftToLocalStorage();
```

Saves current draft to browser localStorage:

1. Validates content is not empty
2. Creates draft object with content, timestamp, groupId
3. Stores in localStorage with prefixed key
4. Updates visual indicator with "Draft saved" message
5. Clears `hasUnsavedChanges` flag

```javascript
loadDraftFromLocalStorage();
```

Loads existing draft from localStorage:

1. Retrieves draft by groupId key
2. Checks if draft is expired (>7 days)
3. If expired, deletes and returns
4. If valid, shows restoration modal with relative timestamp

```javascript
handlePost();
```

Posts content to Chatter via Apex:

1. Validates content is not empty
2. Calls `ChatterPublisherController.postToChatter`
3. On success, clears draft and shows success toast
4. Reloads page to show new post in feed
5. On error, shows error toast and keeps draft

```javascript
beforeUnloadHandler(event);
```

Warns user before leaving with unsaved changes:

1. Checks `hasUnsavedChanges` flag and content not empty
2. If true, prevents default navigation
3. Sets `returnValue` to trigger browser confirmation dialog

**Helper Methods**:

- `cleanupExpiredDrafts()` - Removes drafts older than 7 days
- `getDraftKey()` - Returns localStorage key for current group
- `isContentNotEmpty()` - Strips HTML and checks for actual text
- `isDraftExpired()` - Checks if draft is older than 7 days
- `getRelativeTime()` - Formats timestamp as "X minutes ago"
- `showToast()` - Displays lightning toast messages

### ChatterPublisherController (Apex)

**Purpose**: Handles posting messages to Chatter groups via ConnectApi

**Key Methods**:

```apex
@AuraEnabled
public static String postToChatter(String groupId, String content)
```

Posts a message to a Chatter group:

1. Validates groupId and content are provided
2. Verifies Chatter group exists and user has access
3. Converts rich text HTML to plain text
4. Builds ConnectApi.FeedItemInput
5. Posts via `ConnectApi.ChatterFeeds.postFeedElement`
6. Returns feed item ID on success

```apex
private static Id getNetworkId()
```

Gets the network ID for community context:

1. Tries `Network.getNetworkId()` first
2. Falls back to querying for "Spokane Mountaineers" network
3. Returns network ID or null

```apex
private static String stripHtmlTags(String html)
```

Converts rich text HTML to plain text:

1. Converts `<br>` and `</p>` tags to newlines
2. Converts list items to bullet points
3. Removes all other HTML tags
4. Decodes HTML entities (&amp;, &lt;, etc.)
5. Cleans up multiple consecutive newlines

## Testing Strategy

### Test Coverage Goals

**ChatterPublisherController**: Achieved 100% code coverage

**Test Scenarios Covered**:

1. **Successful Posting**:
    - Plain text content
    - Rich text with formatting
    - Content with HTML entities
    - Content with line breaks
    - Content with lists
    - Long content
    - Content with special characters

2. **Error Handling**:
    - Null group ID
    - Empty group ID
    - Null content
    - Empty content
    - Invalid/non-existent group ID

3. **Edge Cases**:
    - Group ID validation
    - HTML to text conversion
    - Entity decoding
    - List formatting

### Test Data Strategy

Tests use:

- Dynamic Chatter group creation with unique names (timestamp suffix)
- Query for existing Public Chatter groups when possible
- Proper use of `Test.startTest()` and `Test.stopTest()`
- Comprehensive assertions for positive and negative cases
- Mock HTML content representing real-world usage

### Running Tests

```bash
# Run all tests for the controller
sf apex run test --tests ChatterPublisherControllerTest --target-org staging --code-coverage --result-format human

# Check code coverage
sf apex get test --code-coverage --target-org staging
```

## Deployment Instructions

### Prerequisites

1. Salesforce CLI installed
2. Access to staging and production orgs
3. Git repository cloned locally
4. Feature branch created: `feature/chatter-autosave`

### Step 1: Deploy to Staging

```bash
# Deploy the component and Apex classes to staging
sf project deploy start --target-org staging

# Monitor deployment
sf project deploy report --target-org staging
```

### Step 2: Run Apex Tests

```bash
# Run tests and verify >75% coverage
sf apex run test --tests ChatterPublisherControllerTest \
  --target-org staging \
  --code-coverage \
  --result-format human \
  --wait 10

# Get detailed coverage report
sf apex get test --code-coverage --target-org staging
```

Expected output:

- All test methods passing
- Code coverage >75% for ChatterPublisherController
- No test failures or errors

### Step 3: Add Component to Experience Cloud

1. **Open Experience Builder**:
    - Navigate to Digital Experiences > All Sites
    - Find "Spokane Mountaineers" site
    - Click "Builder"

2. **Navigate to Group Detail Page**:
    - In Experience Builder, go to any Chatter group page
    - Or configure via Settings > Theme > Group Pages template

3. **Add Component**:
    - In left sidebar, find "Custom Components"
    - Drag "Chatter Publisher with Autosave" onto the page
    - Position it above the standard Chatter feed
    - Leave "Chatter Group ID" property blank (auto-detects from page)

4. **Publish Changes**:
    - Click "Publish" button
    - Confirm publication to make changes live

### Step 4: Test in Staging

**Test Scenarios**:

1. **Draft Saving**:
    - Navigate to a Chatter group page in staging
    - Start typing a message with formatting
    - Wait 10 seconds
    - Verify "Draft saved" indicator appears
    - Check browser console: `localStorage.getItem('chatterDraft_<groupId>')`

2. **Draft Restoration**:
    - With a saved draft, refresh the page
    - Verify restoration modal appears
    - Click "Restore Draft"
    - Confirm content is restored with formatting intact

3. **Navigation Warning**:
    - Start typing without waiting for autosave
    - Try to navigate away or close tab
    - Verify browser shows confirmation dialog

4. **Posting**:
    - Compose a message with rich text formatting
    - Click "Share" button
    - Verify post appears in Chatter feed
    - Confirm draft is cleared from localStorage
    - Verify "Draft saved" indicator is gone

5. **Draft Expiration**:
    - Manually create expired draft in console:
        ```javascript
        const groupId = "0F9..."; // Current group ID
        const expiredDraft = {
            content: "<p>Old draft</p>",
            timestamp: new Date(
                Date.now() - 8 * 24 * 60 * 60 * 1000
            ).toISOString(), // 8 days ago
            groupId: groupId
        };
        localStorage.setItem(
            `chatterDraft_${groupId}`,
            JSON.stringify(expiredDraft)
        );
        ```
    - Refresh page
    - Verify no restoration modal appears
    - Check localStorage to confirm draft was removed

### Step 5: Deploy to Production

After successful staging testing:

```bash
# Switch to production org
sf config set target-org production

# Deploy
sf project deploy start --target-org production

# Run tests in production
sf apex run test --tests ChatterPublisherControllerTest \
  --target-org production \
  --code-coverage \
  --result-format human \
  --wait 10
```

### Step 6: Rollout Strategy

**Phased Approach**:

1. Deploy component to one test group (e.g., Ecomm) first
2. Monitor for 1-2 days
3. Roll out to all activity group pages
4. Communicate to members about new autosave feature

**Rollback Plan**:

If issues arise:

1. Remove component from Experience Builder (immediate)
2. Members revert to standard Chatter publisher
3. No data loss (drafts remain in localStorage)
4. Fix issues and redeploy

## Lessons Learned

### What Worked Well

**localStorage for Persistence**: Using browser localStorage provided instant saves with no network latency and survived browser crashes perfectly. The approach proved more reliable than we initially expected, with no storage quota issues even with rich HTML content.

**Debounced Autosave**: The 10-second debounce struck the right balance between responsiveness and performance. Users appreciated seeing the "Draft saved" confirmation without being distracted by constant saves.

**Rich Text Component**: The `lightning-input-rich-text` component provided robust formatting out of the box. The toolbar was familiar to users from other editing tools, reducing the learning curve.

**ESLint Enforcement**: Pre-commit hooks caught several issues early:

- Invalid `@api` property reassignment
- Missing return statements
- Async operation restrictions
- innerHTML security concerns

These catches prevented bugs from reaching production.

**Comprehensive Test Coverage**: Achieving 100% coverage for the Apex controller gave us confidence to deploy. Edge cases like null values, empty strings, and invalid group IDs were all covered.

### Challenges Overcome

**LWC Platform Restrictions**: Hit several ESLint rules specific to LWC:

- `@lwc/lwc/no-api-reassignments` - Can't reassign `@api` properties
    - **Solution**: Created `_internalGroupId` private property and `effectiveGroupId` getter
- `@lwc/lwc/no-async-operation` - Can't use `setTimeout` without eslint-disable
    - **Solution**: Added inline eslint-disable comment with justification
- `@lwc/lwc/no-inner-html` - Can't use `innerHTML` for security
    - **Solution**: Added eslint-disable where needed for HTML parsing in helper method

**ConnectApi HTML Limitations**: The Connect API doesn't support rich HTML posting directly. Initial implementation tried to post HTML but Chatter stripped formatting.

- **Solution**: Built `stripHtmlTags` method to intelligently convert HTML to plain text while preserving structure (line breaks, lists)

**beforeunload Event Handling**: The browser's `beforeunload` event requires returning a value, but ESLint flagged missing return in else branch.

- **Solution**: Added explicit `return undefined` for consistency

**Draft Restoration UX**: Initial implementation restored drafts automatically, which was jarring if users didn't remember they had a draft.

- **Solution**: Added modal dialog with "Restore" vs "Discard" options, showing timestamp so users can decide

**Multiple Chatter Groups**: Needed to handle users composing drafts for multiple groups simultaneously.

- **Solution**: Keyed drafts by groupId, allowing independent drafts per group

### Future Considerations

**Server-Side Draft Backup**: Consider adding optional server-side draft storage for:

- Cross-device access (draft on desktop, restore on mobile)
- Draft sharing/collaboration
- Audit trail of draft history
- Recovery if localStorage is cleared

This could be implemented as an enhancement without changing the current localStorage-first approach.

**Rich Text Posting**: Explore options for preserving rich text formatting in Chatter posts:

- ConnectApi rich text segments (may support some formatting)
- Markdown conversion for structured content
- Image paste support

**@Mention and #Hashtag Preservation**: Current implementation doesn't preserve Chatter-specific syntax. Future enhancement could:

- Parse @mentions from HTML
- Convert to ConnectApi.MentionSegmentInput
- Parse #hashtags and convert to ConnectApi.HashtagSegmentInput

**Draft Versioning**: For long-form posts, users might appreciate:

- Multiple draft versions
- Undo/redo functionality
- Draft comparison view

**Analytics Integration**: Track usage metrics:

- How often drafts are saved
- How often drafts are restored vs discarded
- Average draft lifespan
- Most common draft content lengths

**Mobile Optimization**: While the component works on mobile, consider:

- Touch-optimized toolbar
- Simplified formatting options for small screens
- Better modal sizing for mobile viewports

**Accessibility Improvements**:

- ARIA labels for screen readers
- Keyboard shortcuts for common actions
- Focus management in restoration modal
- High contrast mode support

## Related Documentation

- [Activity Group Event Notifications](../articles/activity-group-event-notifications.md) - Related Chatter automation
- [Setup Staging Sandbox](../how-to-guides/setup-staging-sandbox.md) - Staging environment setup
- [Salesforce Development Console Cheatsheet](../how-to-guides/salesforce-development-console-cheatsheet.md) - Debugging tools

## Code References

**Lightning Web Component**:

- `force-app/main/default/lwc/chatterPublisherWithAutosave/chatterPublisherWithAutosave.js`
- `force-app/main/default/lwc/chatterPublisherWithAutosave/chatterPublisherWithAutosave.html`
- `force-app/main/default/lwc/chatterPublisherWithAutosave/chatterPublisherWithAutosave.css`
- `force-app/main/default/lwc/chatterPublisherWithAutosave/chatterPublisherWithAutosave.js-meta.xml`

**Apex Classes**:

- `force-app/main/default/classes/ChatterPublisherController.cls`
- `force-app/main/default/classes/ChatterPublisherController.cls-meta.xml`
- `force-app/main/default/classes/ChatterPublisherControllerTest.cls`
- `force-app/main/default/classes/ChatterPublisherControllerTest.cls-meta.xml`

**Configuration**:

- `force-app/main/default/lwc/.eslintrc.json` - ESLint configuration for LWC

## Issue Reference

Addresses [Issue #10: No Autosave When Composing Messages](https://github.com/jasonkradams/smi/issues/10)
