@isTest
public with sharing class InvoiceBatchTest {
    //创建1000个Account  分别有6个contact
    List<Account> accList = new List<Account>();
    @TestSetup
    static void makeData() {
        //创建2000个Account  分别有2个contact
        List<Account> accList = new List<Account>();
        for (Integer i = 0; i < 2000; i++) {
            Account acc = new Acc(name = 'test会社 ' + i);
            accList.add(acc);
        }
        insert accList;

        List<Contact> conList = new List<Contact>();
        for (Account acc : accList) {
            for (Integer i = 0; i < 2; i++) {
                Contact con = new Contact(
                    LastName = '責任者' + i,
                    AccountId = acc.id
                );
                conList.add(con);
            }
        }
        insert conList;
        //创建3个 案件  案件1 100日元  案件2 130 日元 案件3 160日元
        List<Anken__c> anList = new List<Anken__c>();
        for (Integer i = 0; i < 3; i++) {
            Anken__c an = new Anken__c(
                AnkenStatus__c = '進行中',
                WorkStartDay__c = '12/1/2021',
                AnkenName__c = 'anken' + i
            );
            anList.add(an);
        }
        insert anList;

        //根据900个作业员    每个公司300个作业员  每个公司最后100个员工都发两个案件
        List<OperatorInformation__c> opList = new List<OperatorInformation__c>();
        for (Account acc : accList) {
            for (Integer i = 0; i < 300; i++) {
                OperatorInformation__c op = new OperatorInformation__c(
                    Name__c = acc.name + '作業員' + i,
                    FuLiGana__c = acc.name + 'SaGyoIn' + i,
                    TelephoneNumber__c = 1111111,
                    EmailAddress__c = 'qqqqq@qq.com',
                    Price__c = 40,
                    Status__c = '継続',
                    MaxTime__c = 180,
                    MinimumTime__c = 140,
                    Account__c = acc.id
                );
                opList.add(op);
            }
        }
        insert opList;
        //创建每个公司的3个案件主見積
        List<PjQuote__c> pjList = new List<PjQuote__c>();
        for (Anken__c an : anList) {
            for (Account acc : accList) {
                PjQuote__c pj = new PjQuote__c(
                    QuoteYm__c = 'test',
                    QuoteStatus__c = '作成済',
                    ProjectNo__c = an.id,
                    OrdersReceivedCompany__c = acc.id,
                    OrdersReceivedEmp__c = acc.OperatorInformation__r[0]
                );
                pjList.add(pj);
            }
        }
        insert pjList;
        //创建（100+100）*3+（200*3）=1200个 見積もり明细 分别关联上案件和作业员
        List<PjQuoteDtil__c> pjqdList = new PjQuoteDtil__c();
        for (pjList pj : pjList) {
            for (
                OperatorInformation__c op : pj.OrdersReceivedCompany__r.OperatorInformation__r
            ) {
                //获取作业员name string的之后一个字节 转换为integer 首先把编号为200之前的都分配案件0 价格为100
                if (pj.ProjectNo__r.AnkenName__c == 'anken0') {
                    if (
                        integer.valueof(
                            string.substring(op.name.length() - 1) < 200
                        )
                    ) {
                        PjQuoteDtil__c pjqd = new PjQuoteDtil__c(
                            QuoteName__c = pj.id,
                            MemberName__c = op.id,
                            WorkQt__c = 1,
                            Price__c = 100,
                            OverTimePrice__c = 0,
                            DeductionPrice__c = 0
                        );
                        pjqdList.add(pjqd);
                    }
                } else {
                    //剩下的 编号为200之后的分配案件1 价格为200
                    if (pj.ProjectNo__r.AnkenName__c == 'anken1') {
                        PjQuoteDtil__c pjqd = new PjQuoteDtil__c(
                            QuoteName__c = pj.id,
                            MemberName__c = op.id,
                            WorkQt__c = 1,
                            Price__c = 200,
                            OverTimePrice__c = 0,
                            DeductionPrice__c = 0
                        );
                        pjqdList.add(pjqd);
                    }
                    if (pj.ProjectNo__r.AnkenName__c == 'anken2') {
                        PjQuoteDtil__c pjqd = new PjQuoteDtil__c(
                            QuoteName__c = pj.id,
                            MemberName__c = op.id,
                            WorkQt__c = 1,
                            Price__c = 300,
                            OverTimePrice__c = 0,
                            DeductionPrice__c = 0
                        );
                        pjqdList.add(pjqd);
                    }
                }
            }
        }
        insert pjqdList;
    }

    //创建3个公司的受发注明细
    //创建200*3+400*3=1800个 受发注明细

    //创建1800个作业实绩
    //检查最后是否创建了3个 主请求 1800个请求明细  最后主请求的金额是否为100*200+130*100+160*100  * 税收

    public InvoiceBatchTest() {
    }

    /*     Account account = new Account(Name = 'Test');
insert account;

Datetime yesterday = Datetime.now().addDays(-1);
Test.setCreatedDate(account.Id, yesterday); */
}
