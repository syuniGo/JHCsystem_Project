@isTest
public with sharing class test3 {
    @testSetup
    static void makeData() {
        //取引先30個登録する
        List<Account> accList = new List<Account>();
        for (Integer i = 0; i < 30; i++) {
            Account acc = new Account(name = 'test会社 ' + i);
            accList.add(acc);
        }
        insert accList;

        //取引先Listをループして、取引先責任者30人登録する
        List<Contact> conList = new List<Contact>();
        for (Account acc : accList) {
            for (Integer i = 0; i < 1; i++) {
                Contact con = new Contact(
                    LastName = acc.Name + '責任者' + i,
                    AccountId = acc.id
                );
                conList.add(con);
            }
        }
        insert conList;

        //案件情報３つ登録する
        List<Anken__c> anList = new List<Anken__c>();
        for (Integer i = 0; i < 3; i++) {
            Anken__c an = new Anken__c(
                AnkenStatus__c = '進行中',
                WorkStartDay__c = date.newInstance(2021, 4, 21),
                AnkenName__c = 'anken' + i
            );
            anList.add(an);
        }
        insert anList;

        //取引先listをループして、ひとつごと作業員3人を登録する　総計30*3＝90人
        List<OperatorInformation__c> opList = new List<OperatorInformation__c>();
        for (Account acc : accList) {
            for (Integer i = 0; i < 3; i++) {
                OperatorInformation__c op = new OperatorInformation__c(
                    Name__c = acc.name + '作業員' + i,
                    FuLiGana__c = acc.name + 'SaGyoIn' + i,
                    TelephoneNumber__c = '111111',
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
        System.debug('作业员情报' + opList.size());

        //案件listと取引先責任者listをループして、一つの案件と一つの取引先責任者の形で見積を登録する　総計3*30＝90
        List<PjQuote__c> pjList = new List<PjQuote__c>();
        for (Anken__c an : anList) {
            for (Contact con : conList) {
                PjQuote__c pj = new PjQuote__c(
                    QuoteYm__c = 'test',
                    QuoteStatus__c = '作成済',
                    ProjectNo__c = an.id,
                    OrdersReceivedCompany__c = con.AccountId,
                    OrdersReceivedEmp__c = con.id
                );
                pjList.add(pj);
            }
        }

        insert pjList;
        System.debug('主見積' + pjList.size());

        //見積listをループと作業員をループして、一つの案件と一つの作業員の形で見積明細を登録する　総計3*30*3＝270
        List<PjQuoteDtil__c> pjqdList = new List<PjQuoteDtil__c>();
        for (PjQuote__c pj : pjList) {
            for (OperatorInformation__c op : opList) {
                if (pj.OrdersReceivedCompany__c == op.Account__c) {
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

                /*   // 先进行公司筛选如果見積公司==作业公司 获取作业员name string的之后一个字节 转换为integer 首先把编号为200之前的都分配案件0 价格为100
                if (
                    pj.OrdersReceivedCompany__c == op.Account__c &&
                    pj.ProjectNo__r.AnkenName__c == 'anken0'
                ) {
                    if (
                        integer.valueof(
                            (op.Name__c).substring((op.Name__c).length() - 1)
                        ) < 2
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
                    if (
                        pj.OrdersReceivedCompany__c == op.Account__c &&
                        pj.ProjectNo__r.AnkenName__c == 'anken1'
                    ) {
                        PjQuoteDtil__c pjqd = new PjQuoteDtil__c(
                            QuoteName__c = pj.id,
                            MemberName__c = op.id,
                            WorkQt__c = 1,
                            Price__c = 200,
                            OverTimePrice__c = 0,
                            DeductionPrice__c = 0
                        );
                        pjqdList.add(pjqd);
                    }F
                    if (
                        pj.OrdersReceivedCompany__c == op.Account__c &&
                        pj.ProjectNo__r.AnkenName__c == 'anken2'
                    ) {
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
                } */
            }
        }
        insert pjqdList;

        //見積をループして、受発注を登録する　総計3*30＝90
        List<PurchaseOrder__c> poList = new List<PurchaseOrder__c>();
        for (PjQuote__c pj : pjList) {
            PurchaseOrder__c po = new PurchaseOrder__c(
                EstimateId__c = pj.id,
                ContractType__c = '作業請負',
                ContractStatus__c = '新規契約',
                WorkMonth__c = '202201',
                OrderStatus__c = '作成済'
            );
            poList.add(po);
        }

        insert poList;

        //見積明細listと受発注listをループして、受発注参照の見積id==見積明細参照の見積idの場合　受発注明細を作成して登録する　総計270
        List<PurchaseOrderDetail__c> podList = new List<PurchaseOrderDetail__c>();
        for (PjQuoteDtil__c pjqd : pjqdList) {
            for (PurchaseOrder__c po : poList) {
                if (pjqd.QuoteName__c == po.EstimateId__c) {
                    PurchaseOrderDetail__c pod = new PurchaseOrderDetail__c(
                        PurchaseOrderId__c = po.id,
                        PartnerMember__c = pjqd.MemberName__c,
                        WorkQt__c = 1,
                        StandardPrice__c = 100,
                        OverTimePrice__c = 200,
                        DeductionPrice__c = 100
                    );

                    podList.add(pod);
                }
            }
        }

        insert podList;
        System.debug('受发注明細数' + podList.size());

        //???  作成した受発注明細をsoqlして、参照の作業員情報の会社idをゲットして、podList2に与える
        List<PurchaseOrderDetail__c> podList2 = [
            SELECT PartnerMember__c, PartnerMember__r.Account__c, id
            FROM PurchaseOrderDetail__c
            WHERE id IN :podList
        ];

        //受発注明細Listをループして、作業実績を作成する
        List<WorkTime__c> wtList = new List<WorkTime__c>();
        for (PurchaseOrderDetail__c pod : podList2) {
            WorkTime__c wt = new WorkTime__c(
                TotalUptime__c = 140,
                ApprovalStatus__c = '承認完了',
                WorkingYearsMonth__c = '202011',
                PersonalID__c = pod.PartnerMember__c,
                TypeOfContract__c = '作業請負', //pod.PurchaseOrderId__r.ContractType__c
                PurchaseOrderDetail__c = pod.id,
                StandardTime__c = 100,
                MinustimeHour__c = 0,
                OvertimeHour__c = 0,
                Account__c = pod.PartnerMember__r.Account__c
            );

            wtList.add(wt);
        }
        insert wtList;
        System.debug('作业实绩个数' + wtList.size());
    }
    //检查最后是否创建了3个 主请求 1800个请求明细  最后主请求的金额是否为100*200+130*100+160*100  * 税收

    @isTest
    static void methodName() {
        Test.startTest();
        InvoiceBatchHandle2 ibh = new InvoiceBatchHandle2();
        Database.executeBatch(ibh, 200);
        Test.stopTest();
        List<InvoiceDetail__c> results1 = [SELECT id FROM InvoiceDetail__c];
        System.assertEquals(270, results1.size());
        List<Invoice__c> results2 = [SELECT id FROM Invoice__c];
        System.assertEquals(30, results2.size());
        //??? System.assertEquals(1, Limits.getEmailInvocations());
    }

    /*     Account account = new Account(Name = 'Test');
insert account;

Datetime yesterday = Datetime.now().addDays(-1);
Test.setCreatedDate(account.Id, yesterday); */
}
