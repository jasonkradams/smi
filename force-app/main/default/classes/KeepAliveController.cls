public with sharing class KeepAliveController {
    @AuraEnabled(cacheable=false)
    public static void ping() {
        // No-op for session keep-alive
    }
}
