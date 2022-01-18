public with sharing class InvoiceBatchHandle2 {
    public InvoiceBatchHandle2() {
    }
    //设置一个计数最后生成多少个请求
    public Integer recordsProcessed1 = 0;
    //设置一个计数最后生成多少个请求明细
    public Integer recordsProcessed2 = 0;
    public String recordsProcessederr1 = '';
    public String recordsProcessederr2 = '';

    public Database.QueryLocator start(Database.BatchableContext bc) {
        //找到所有创建了作业实绩的会社
        return Database.getQueryLocator(
            'select id,name,(select id,Account__c,PersonalID__r.Account__c,PersonalID__r.id,PersonalID__r.name,PurchaseOrderDetail__c,PurchaseOrderDetail__r.StandardPrice__c,PurchaseOrderDetail__r.OverTimePrice__c,PurchaseOrderDetail__r.DeductionPrice__c,StandardTime__c,MinustimeHour__c,OvertimeHour__c from WorkTime__r where CreatedDate = LAST_MONTH) from Account Where Id IN (SELECT Account__c FROM WorkTime__c where CreatedDate = LAST_MONTH)'
        );
    }

    public void execute(Database.BatchableContext bc, List<sObject> accounts) {
        Map<Id, List<WorkTime__c>> accIdToWorkTimes = new Map<Id, List<WorkTime__c>>();
        for (Account acc : accounts) {
            List<WorkTime__c> wts = acc.WorkTime__r;
            accIdToWorkTimes.put(acc.id, wts);
        }
        //如果map找到了会社
        if (!accIdToWorkTimes.keySet().isEmpty()) {
            //为作业实绩不为空的公司创建主请求
            List<Invoice__c> lastMonthInvoices = new List<Invoice__c>();
            for (Account acc : accounts) {
                Invoice__c lastMonthInvoice = new Invoice__c(
                    //計上年月  获取上个月的年月string.
                    InvoiceYM__c = String.valueOf(
                            System.today().toStartOfMonth().addDays(-1).year()
                        ) +
                        String.valueOf(
                            System.today().toStartOfMonth().addDays(-1).month()
                        ),
                    //請求ステータス
                    InvoiceStatus__c = '作成済',
                    //振込期限日  具体哪一天 暂定本月最后最后1天
                    PaymentDeadlineYmd__c = System.today()
                        .addMonths(1)
                        .toStartofMonth()
                        .addDays(-1),
                    //受注会社
                    PartnerId__c = acc.id,
                    //請求確定日  具体哪一天 暂定本月倒数第10天
                    InvoiceDecideYmd__c = System.today()
                        .addMonths(1)
                        .toStartofMonth()
                        .addDays(-10)
                );
                lastMonthInvoices.add(lastMonthInvoice);
            }
            List<Database.SaveResult> saveResult1 = Database.insert(
                lastMonthInvoices
            );

            for (Database.SaveResult sr1 : saveResult2) {
                if (!sr.isSuccess()) {
                    List<Database.Error> errors = sr.getErrors();
                    recordsProcessederr1 = String.join(errors, ',');
                    System.debug(recordsProcessederr1);
                }
            }

            recordsProcessed1 = saveResult1.size();

            //循环所有的作业实绩 每一个新建一个请求明细 根据作业员的公司绑定到对应公司的主请求上
            List<InvoiceDetail__c> newInvoiceDetailList = new List<InvoiceDetail__c>();
            //循环刚刚创建好的明细 根据这里的accountid 从map中提取上个月的作业实绩list 来创建请求明细
            for (Invoice__c lastMonthInvoice : lastMonthInvoices) {
                List<WorkTime__c> lastMonthWts = accIdToWorkTimes.get(
                    lastMonthInvoice.PartnerId__c
                );
                for (WorkTime__c lastMonthWt : lastMonthWts) {
                    InvoiceDetail__c newInvoiceDetail = new InvoiceDetail__c(
                        //請求id
                        InvoiceId__c = companyIdToInvoice__c.get(
                                workTime.PersonalID__r.Account__c
                            )
                            .id,
                        //作業員工数実績id
                        PartnerStaffWorkTime__c = workTime.id,
                        //作業員ID
                        PartnerStaffId__c = workTime.PersonalID__r.id,
                        //作業員名
                        PartnerStaffName__c = workTime.PersonalID__r.name,
                        //受発注明細id
                        PurchaseOrderDetail__c = workTime.PurchaseOrderDetail__c,
                        //標準単価
                        Price__c = workTime.PurchaseOrderDetail__r.StandardPrice__c,
                        //時間外単価
                        OverTimePrice__c = workTime.PurchaseOrderDetail__r.OverTimePrice__c,
                        //控除単価
                        DeductionPrice__c = workTime.PurchaseOrderDetail__r.DeductionPrice__c,
                        //標準時間
                        StandardHour__c = workTime.StandardTime__c,
                        //控除時間
                        MinustimeHour__c = workTime.MinustimeHour__c,
                        //残業時間
                        OvertimeHour__c = workTime.OvertimeHour__c,
                        //消費税率
                        TaxRate__c = 10
                    );
                    newInvoiceDetailList.add(newInvoiceDetail);
                }
            }
            //databese insert请求明细list 并接受结果

            List<Database.SaveResult> saveResult2 = Database.insert(
                newInvoiceDetailList
            );

            recordsProcessed2 = saveResult2.size();
            //如果insert不成功把错误信息加入字符串并输出到log
            for (Database.SaveResult sr2 : saveResult2) {
                if (!sr.isSuccess()) {
                    List<Database.Error> errors = sr.getErrors();
                    recordsProcessederr2 = String.join(errors, ',');
                    System.debug(recordsProcessederr2);
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(recordsProcessed1 + '请求作成');
        System.debug(recordsProcessed2 + '请求明细作成');
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new List<String>{ 'useizen01@gmail.com' };
        mail.setToAddresses(toAddresses);
        mail.setSenderDisplayName('本月バーチ請求作成');
        mail.setSubject('本月バーチ請求作成');
        mail.setHtmlBody(
            recordsProcessed1 +
            '请求作成' +
            recordsProcessed2 +
            '请求明细作成'
        );
        Messaging.sendEmail(new List<Messaging.Email>{ mail });
    }
}
