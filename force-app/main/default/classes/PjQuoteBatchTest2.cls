@isTest
public with sharing class PjQuoteBatchTest2 {
    @testSetup
    static void makeData() {
        //取引先30個登録する
        List<Account> accList = new List<Account>();
        for (Integer i = 0; i < 1; i++) {
            Account acc = new Account(name = 'test会社 ' + i);
            accList.add(acc);
        }
        insert accList;

        UserRole r = new UserRole(Name = 'testマネージャ');
        insert r;

        system.debug('--after insert accList--' + Datetime.now());
        //取引先Listをループして、取引先責任者30人登録する
        List<Contact> conList = new List<Contact>();
        List<User> userList = new List<User>();
        for (Account acc : accList) {
            for (Integer i = 0; i < 1; i++) {
                Contact con = new Contact(
                    LastName = acc.Name + '責任者' + i,
                    AccountId = acc.id
                );
                conList.add(con);
                User u = new User(
                    ProfileId = [
                        SELECT Id
                        FROM Profile
                        WHERE Name = 'System Administrator'
                    ]
                    .Id,
                    LastName = con.LastName,
                    Email = 'puser000@amamama.com',
                    Username = 'puser000@amamama.com' +
                        System.currentTimeMillis(),
                    CompanyName = 'TEST',
                    Title = 'title',
                    Alias = 'alias',
                    TimeZoneSidKey = 'America/Los_Angeles',
                    EmailEncodingKey = 'UTF-8',
                    LanguageLocaleKey = 'en_US',
                    LocaleSidKey = 'en_US',
                    UserRoleId = r.Id
                );
                userList.add(u);
            }
        }
        insert conList;
        insert userList;

        system.debug('--after insert conList--' + Datetime.now());
        //案件情報３つ登録する
        List<Anken__c> anList = new List<Anken__c>();
        for (Integer i = 0; i < 1; i++) {
            Anken__c an = new Anken__c(
                AnkenStatus__c = '進行中',
                WorkStartDay__c = date.newInstance(2021, 4, 21),
                AnkenName__c = 'anken' + i
            );
            anList.add(an);
        }
        insert anList;
        system.debug('--after insert anList--' + Datetime.now());
        //取引先listをループして、ひとつごと作業員3人を登録する　総計30*1＝30人
        List<OperatorInformation__c> opList = new List<OperatorInformation__c>();

        //マッピング用MAPを作成する
        Map<ID, List<OperatorInformation__c>> OPMap = new Map<ID, List<OperatorInformation__c>>();
        for (Account acc : accList) {
            for (Integer i = 0; i < 1; i++) {
                OperatorInformation__c op = new OperatorInformation__c(
                    Name__c = acc.name + '作業員' + i,
                    FuLiGana__c = acc.name + 'SaGyoIn' + i,
                    TelephoneNumber__c = '111111',
                    EmailAddress__c = 'qqqqq@qq.com',
                    Price__c = 40,
                    Status__c = '継続',
                    MaxTime__c = 180,
                    MinimumTime__c = 140,
                    AnkenNumber__c = anList[0].id,
                    Account__c = acc.id
                );

                opList.add(op);
            }
        }
        insert opList;
    }

    @isTest
    static void methodName() {
        Test.startTest();
        PjQuoteBatch2 ibh = new PjQuoteBatch2();
        Database.executeBatch(ibh, 200);
        Test.stopTest();
        //List<PjQuote__c> results1 = [SELECT id FROM PjQuote__c];
        //system.debug('results1:'+ results1.size());
        //System.assertEquals(30, results1.size());
        //List<PjQuoteDtil__c> results2 = [SELECT id FROM PjQuoteDtil__c];
        //System.assertEquals(90, results2.size());
        //system.debug('results2:'+ results2.size());
        //??? System.assertEquals(1, Limits.getEmailInvocations());
    }

    /*     Account account = new Account(Name = 'Test');
insert account;

Datetime yesterday = Datetime.now().addDays(-1);
Test.setCreatedDate(account.Id, yesterday); */
}
