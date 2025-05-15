@isTest
private class GASUserSyncFlowHelperTest {

    @isTest
    static void testEmptyListReturnsList() {
        List<UserSyncInput> result = GASUserSyncFlowHelper.emptyList();
        System.assertNotEquals(null, result);
        System.assertEquals(0, result.size());
    }
}