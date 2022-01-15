public with sharing class InvoiceBatchHandle implements Database.Batchable<sObject>, Database.Stateful {
    //设置一个计数最后生成多少个请求明细
    public Integer recordsProcessed = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        //找到所有上个月登陆的作业实绩
        return Database.getQueryLocator(
            'select id,PersonalID__r.Account__c,PersonalID__r.id,PersonalID__r.name,PurchaseOrderDetail__c,PurchaseOrderDetail__r.StandardPrice__c,PurchaseOrderDetail__r.OverTimePrice__c,PurchaseOrderDetail__r.DeductionPrice__c,StandardTime__c,MinustimeHour__c,OvertimeHour__c from WorkTime__c,OvertimeHour__cwhere CreatedDate = LAST_MONTH'
        );
    }

    public void execute(Database.BatchableContext bc, List<sObject> workTimes) {
        //如果找到的作业实绩不为空
        if (!workTimes.isEmpty()) {
            //创建一个set 来存放 作业员所属公司的id
            Set<Id> companyIds = new Set<Id>();
            for (WorkTime__c workTime : workTimes) {
                companyId.add(workTime.PersonalID__r.Account__c);
                System.debug(
                    'CompanyId: ' + WorkTime__r.PersonalID__r.Account__c
                );
            }
            //aa创建一个map key 为受注会社accountid value为每个公司的主请求
            Map<Id, Invoice__c> companyIdToInvoice__c = new Map<Id, Invoice__c>();
            List<Invoice__c> lastMonthInvoices = new List<Invoice__c>();

            //获取这个月最后一天的日期
            Date lastDay = System.today()
                .addMonths(1)
                .toStartofMonth()
                .addDays(-1);
            String year = String.valueOf(lastDay.year());
            String month = String.valueOf(lastDay.month());

            for (Id companyId : companyIds) {
                Invoice__c lastMonthInvoice = new Invoice__c(
                    //計上年月
                    InvoiceYM__c = month + year,
                    //請求ステータス
                    InvoiceStatus__c = '作成済',
                    //振込期限日  具体哪一天 暂定本月最后最后1天
                    PaymentDeadlineYmd__c = System.today()
                        .addMonths(1)
                        .toStartofMonth()
                        .addDays(-1),
                    //受注会社
                    PartnerId__c = companyId,
                    //請求確定日  具体哪一天 暂定本月倒数第10天
                    InvoiceDecideYmd__c = System.today()
                        .addMonths(1)
                        .toStartofMonth()
                        .addDays(-10)
                );
                companyIdToInvoice__c.put(companyId, lastMonthInvoice);
                lastMonthInvoices.add(lastMonthInvoice);
            }
            insert lastMonthInvoices;

            //循环所有的作业实绩 每一个新建一个请求明细 根据作业员的公司绑定到对应公司的主请求上
            List<InvoiceDetail__c> newInvoiceDetailList = new List<InvoiceDetail__c>();
            for (WorkTime__c workTime : workTimes) {
                InvoiceDetail__c newInvoiceDetail = new InvoiceDetail__c(
                    //請求id
                    InvoiceId__c = companyIdToInvoice__c.get(
                        workTime.PersonalID__r.Account__c
                    ),
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
            //databese insert请求明细list 并接受结果

            List<Database.SaveResult> saveResult = Database.insert(
                newInvoiceDetailList
            );
            recordsProcessed = saveResult.size();
            //如果insert不成功把错误信息加入字符串并输出到log
            for (Database.SaveResult sr : saveResult) {
                if (!sr.isSuccess()) {
                    List<Database.Error> errors = sr.getErrors();
                    String errorInString = String.join(errors, ',');
                    System.debug(errorInString);
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(recordsProcessed + '请求明细作成');
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new List<String>{ 'useizen01@gmail.com' };
        mail.setToAddresses(toAddresses);
        mail.setSenderDisplayName('本月バーチ請求作成');
        mail.setSubject('本月バーチ請求作成');
        mail.setHtmlBody(recordsProcessed + '请求明细作成');
        Messaging.sendEmail(new List<Messaging.Email>{ mail });
    }
}
