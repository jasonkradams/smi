public class GASUserSyncFlowHelper {
    @AuraEnabled
    public static List<UserSyncInput> emptyList() {
        return new List<UserSyncInput>();
    }
}
