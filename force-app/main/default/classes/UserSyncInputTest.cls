@isTest
private class UserSyncInputTest {

    @isTest
    static void testUserSyncInputConstruction() {
        UserSyncInput input = new UserSyncInput();
        input.email = 'example@spokanemountaineers.org';
        input.first_name = 'Example';
        input.last_name = 'User';
        input.federation_id = 'example@spokanemountaineers.org';

        System.assertNotEquals(null, input);
        System.assertEquals('example@spokanemountaineers.org', input.email);
        System.assertEquals('Example', input.first_name);
        System.assertEquals('User', input.last_name);
        System.assertEquals('example@spokanemountaineers.org', input.federation_id);
    }
}
