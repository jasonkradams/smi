/**
 * Utility: Send Alert Email for Sync Failures
 */

function sendAlert(subject, message) {
    const lastSent = PropertiesService.getScriptProperties().getProperty("lastAlertTime");
    const now = Date.now();
    const THROTTLE_MS = 15 * 60 * 1000; // 15 minutes
  
    if (lastSent && now - Number(lastSent) < THROTTLE_MS) {
      const throttleMsg = "[ALERT THROTTLED] Skipping alert: last sent " + Math.round((now - Number(lastSent)) / 60000) + " minutes ago.";
      Logger.log(throttleMsg);
      throw new Error(throttleMsg);
    }
  
    MailApp.sendEmail({
      to: ADMIN_EMAIL,
      subject: subject,
      body: message
    });
  
    PropertiesService.getScriptProperties().setProperty("lastAlertTime", String(now));
  }