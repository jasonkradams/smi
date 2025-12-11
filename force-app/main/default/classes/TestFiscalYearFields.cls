public class TestFiscalYearFields {
    public static void test() {
        Fiscal_Year_Login_History__c rec = new Fiscal_Year_Login_History__c();
        rec.Login_History_Id__c = 'test';
        rec.User__c = UserInfo.getUserId();
        rec.Login_Time__c = DateTime.now();
        System.debug('Fields accessible');
    }
}

