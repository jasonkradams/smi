# 🔔 Flow: Notify Leader on RSVP

This automated Salesforce Flow sends an email notification to the event leader whenever someone RSVPs "Attending" to an event registration.

---

## Access

- Flow: [Notify Leader on RSVP](https://spokanemountaineers.lightning.force.com/lightning/setup/Flows/home)
- GitHub: [Notify_Leader_on_RSVP.flow-meta.xml](https://github.com/jasonkradams/smi/blob/main/force-app/main/default/flows/Notify_Leader_on_RSVP.flow-meta.xml)

---

## 🎯 Purpose

This Flow automatically notifies event leaders via email when a member RSVPs to their event. It:

- Triggers automatically when a new `Event_Participant__c` record is created
- Only processes participants with `Response__c = "Attending"`
- Retrieves the event leader's email from their associated Contact record
- Sends a formatted email with event and participant details
- Includes a direct link to view the event registration in Salesforce

---

## ⚡ Trigger

- **Object**: `Event_Participant__c`
- **Trigger Type**: Record-Triggered Flow
- **Trigger Timing**: After Save
- **Entry Conditions**:
    - Record is created (not updated)
    - `Response__c = "Attending"`

---

## 🧱 Flow Structure

### 1. Get Event Registration

Retrieves the related `Event_Registration__c` record to access:

- Event name
- Leader lookup (`Leader__c`)
- Event start time (`Start__c`)
- Event location (`Location__c`)

**Element**: `Get_Event_Registration`

---

### 2. Decision: Is Attending?

Checks if the participant's response is "Attending".

**Element**: `Is_Attending`

- ✅ **Response is Attending**: Proceeds to get leader information
- ❌ **Not Attending**: Flow exits (no email sent)

---

### 3. Get Leader User Record

Retrieves the User record from `Event_Registration__c.Leader__c` to access:

- User ID
- User Name (for email greeting)
- Contact ID (`ContactId`) - used to get the Contact email

**Element**: `Get_Leader`

**Note**: We get the leader's email from their Contact record rather than directly from the User record, as Contact.Email is more reliable for Community users.

---

### 4. Decision: Has Leader?

Validates that a leader is assigned to the event.

**Element**: `Has_Leader`

- ✅ **Leader Exists**: Proceeds to get leader's Contact record
- ❌ **No Leader**: Flow exits (no email to send)

---

### 5. Get Leader Contact (Parallel with Get Participant Contact)

Retrieves the Contact record associated with the leader User to access:

- Contact Email (primary email address)
- Contact Name

**Element**: `Get_Leader_Contact`

This runs in parallel with `Get_Participant_Contact` for efficiency.

---

### 6. Get Participant Contact (Parallel with Get Leader Contact)

Retrieves the Contact record of the person who RSVP'd to include their name in the email.

**Element**: `Get_Participant_Contact`

This runs in parallel with `Get_Leader_Contact` for efficiency.

---

### 7. Decision: Has Leader Email?

Validates that the leader's Contact record has an email address.

**Element**: `Has_Leader_Email`

- ✅ **Email Exists**: Proceeds to send email
- ❌ **No Email**: Flow exits (cannot send email)

---

### 8. Send Email to Leader

Sends a formatted email to the event leader.

**Element**: `Send_Email_to_Leader`

**Email Subject**:

```
New RSVP for {Event Registration Name}
```

**Email Body**:

```
Hi {Leader Name},

A member has RSVP'd for your event.

Event: {Event Registration Name}
Participant: {Participant Contact Name}
Response: Attending
Event Start: {Event Start Date/Time}
Location: {Event Location}

You can view the event here:
https://www.spokanemountaineers.org/s/event-registration/{Event Registration ID}

Best regards,
Spokane Mountaineers
```

**Email Configuration**:

- **To**: `Get_Leader_Contact.Email`
- **From/Sender**: `admin@spokanemountaineers.org` (Org-Wide Email Address)
- **Sender Type**: `OrgWideEmailAddress`

---

## 🔍 Data Model

### Objects Used

|       **Object**        |                   **Purpose**                    |                    **Key Fields**                    |
| :---------------------: | :----------------------------------------------: | :--------------------------------------------------: |
| `Event_Participant__c`  |   Trigger record - represents someone RSVPing    | `Event_Registration__c`, `Contact__c`, `Response__c` |
| `Event_Registration__c` |            The event being RSVP'd for            |    `Leader__c`, `Name`, `Start__c`, `Location__c`    |
|         `User`          |            Event leader's user record            |              `Id`, `Name`, `ContactId`               |
|        `Contact`        |       Leader's contact record (for email)        |                `Id`, `Email`, `Name`                 |
|        `Contact`        | Participant's contact record (for email content) |        `Id`, `Name`, `FirstName`, `LastName`         |

### Relationships

- `Event_Participant__c.Event_Registration__c` → `Event_Registration__c` (Master-Detail)
- `Event_Registration__c.Leader__c` → `User` (Lookup)
- `User.ContactId` → `Contact` (Lookup)
- `Event_Participant__c.Contact__c` → `Contact` (Lookup)

---

## ⚠️ Edge Cases Handled

1. **Response is not "Attending"**: Flow exits early, no email sent
2. **No Leader assigned**: Flow exits if `Event_Registration__c.Leader__c` is null
3. **Leader has no Contact**: Flow exits if `User.ContactId` is null
4. **Leader Contact has no Email**: Flow exits if `Contact.Email` is null
5. **Participant Contact lookup fails**: Flow still continues if participant contact cannot be retrieved (uses available data)

---

## 🔧 Why Use Contact Email Instead of User Email?

This flow intentionally retrieves the email address from the leader's **Contact** record rather than directly from the **User** record. This is because:

- **Community Users**: For Community/Experience Cloud users, the `User.Email` field may not always be reliable or up-to-date
- **Contact as Source of Truth**: The `Contact.Email` field is typically the primary communication email and is more likely to be current
- **Consistency**: Using Contact.Email ensures consistent email delivery across standard and community users

The flow retrieves the Contact via `User.ContactId`, then uses `Contact.Email` for the email notification.

---

## 📊 Monitoring & Troubleshooting

### Check Flow Execution

1. Go to **Setup → Flows**
2. Find **Notify Leader on RSVP**
3. Click **View Details and Versions**
4. Click **View** next to the active version
5. Review **Interview Logs** to see execution history

### Common Issues

|      **Issue**      |              **Possible Cause**               |                                      **Solution**                                      |
| :-----------------: | :-------------------------------------------: | :------------------------------------------------------------------------------------: |
|  No email received  |         Leader Contact missing email          |                   Verify `Contact.Email` is populated for the leader                   |
|  No email received  |         Leader User missing ContactId         |                          Verify `User.ContactId` is populated                          |
| Flow not triggering | Event Participant created with wrong Response |                   Verify `Response__c = "Attending"` on new records                    |
|  Email not sending  |            Invalid sender address             | Verify Org-Wide Email Address `admin@spokanemountaineers.org` is configured and active |

### Verify Email Delivery

- Review Flow Interview logs for errors
- Verify leader's Contact.Email is valid and active
- Verify Org-Wide Email Address `admin@spokanemountaineers.org` is configured and active
- Check email delivery logs in Setup → Email Administration → View Email Logs

---

## 🚀 Future Enhancements

|      **Feature**       |                                                           **Notes**                                                            |
| :--------------------: | :----------------------------------------------------------------------------------------------------------------------------: |
|     Handle Updates     | Currently only triggers on Create. Could add Update trigger to notify when someone changes from "Not Attending" to "Attending" |
|     Email Template     |                     Use Salesforce Email Template instead of hardcoded email body for easier customization                     |
|       HTML Email       |                                          Format email as HTML for better presentation                                          |
| Bulk RSVP Notification |                      Option to batch RSVP notifications (e.g., send one email per day with all new RSVPs)                      |
|   Opt-out Preference   |                                    Allow leaders to opt-out of RSVP notifications per event                                    |
|   Participant Count    |                                          Include total participant count in the email                                          |

---

## 📝 Related Documentation

- [Event Participant Redirect](../articles/event-participant-redirect.md): Related solution for event participant functionality
- [Custom Calendar LWC Guide](../how-to-guides/custom-calendar-lwc.md): Documentation on the calendar component used for events

---

## 🛠 Technical Details

- **API Version**: 65.0
- **Flow Type**: Auto-Launched Flow (Record-Triggered)
- **Process Type**: RecordAfterSave
- **Status**: Active
- **Bulk Support**: Yes (handles multiple Event_Participant\_\_c records created in same transaction)
- **Maintainability**: Each flow element includes a description explaining its purpose and intent for easier future maintenance

---

## 📞 Support

For issues or questions about this flow, contact the tech team at [webdev@spokanemountaineers.org](mailto:webdev@spokanemountaineers.org).
