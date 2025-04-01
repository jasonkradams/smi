public with sharing class KeepAliveController {
    @AuraEnabled(cacheable=false)
    public static void ping() {
        // No-op: Keeps session alive
    }
}
