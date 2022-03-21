public with sharing class InvoiceBatchHandle implements Database.Batchable<sObject>, Database.Stateful {
    //請求の登録数を記録する
    public Integer recordsProcessed1 = 0;
    //請求明細の登録数を記録する
    public Integer recordsProcessed2 = 0;
    //請求の登録失敗したら、エラーを記録する
    public String recordsProcessederr1 = '';
    //請求明細の登録失敗したら、エラーを記録する
    public String recordsProcessederr2 = '';

    public Database.QueryLocator start(Database.BatchableContext bc) {
        //先月作業実績を作成した取引先とその取引先関連の先月作業実績を出す
        return Database.getQueryLocator(
            'select id,OwnerId,name,(select id,Account__c,PersonalID__r.Account__c,PersonalID__r.id,PersonalID__r.name,PersonalID__r.Name__c,PurchaseOrderDetail__c,PurchaseOrderDetail__r.StandardPrice__c,PurchaseOrderDetail__r.OverTimePrice__c,PurchaseOrderDetail__r.WorkQt__c,PurchaseOrderDetail__r.DeductionPrice__c,StandardTime__c,MinustimeHour__c,OvertimeHour__c,WorkBeginDay__c,WorkingYearsMonth__c from WorkTime__r where WorkBeginDay__c = NEXT_MONTH And ApprovalStatus__c= \'承認済\' ) from Account where id in (SELECT Account__c FROM WorkTime__c WHERE WorkBeginDay__c = NEXT_MONTH)'
        );
    }

    public void execute(Database.BatchableContext bc, List<Account> accounts) {
        //取引先Idとその取引先関連の先月作業実績のＭap
        Map<Id, List<WorkTime__c>> accIdToWorkTimes = new Map<Id, List<WorkTime__c>>();

        //請求insert用
        List<Invoice__c> lastMonthInvoices = new List<Invoice__c>();
        //請求明細insert用
        List<InvoiceDetail__c> newInvoiceDetailList = new List<InvoiceDetail__c>();

        //前ＳOQLで出した取引先Id数!=0の場合
        if (!accounts.isEmpty()) {
            //取引先をループする
            for (Account acc : accounts) {
                //取引先idとその関連作業実績をMAPに入れる
                List<WorkTime__c> wts = acc.WorkTime__r;
                accIdToWorkTimes.put(acc.id, wts);
                WorkTime__c wts0 = wts[0];

                //請求を作成する
                Invoice__c lastMonthInvoice = new Invoice__c(
                    //請求書
                    Name = acc.Name + wts0.WorkingYearsMonth__c + '請求書タ',
                    //計上年月　先月の年ナンバーと月ナンバー
                    InvoiceYM__c = wts0.WorkingYearsMonth__c,
                    //請求ステータス
                    InvoiceStatus__c = '作成済',
                    //振込期限日   仮定本月逆算にすると一つ目の日
                    PaymentDeadlineYmd__c = wts0.WorkBeginDay__c
                        .addMonths(2)
                        .toStartofMonth()
                        .addDays(-1),
                    //受注会社
                    PartnerId__c = acc.id,
                    //請求確定日  仮定本月逆算にすると十本目の日
                    InvoiceDecideYmd__c = wts0.WorkBeginDay__c
                        .addMonths(2)
                        .toStartofMonth()
                        .addDays(-10),
                    //所有者　受注会社所有者
                    OwnerId = acc.OwnerId
                );
                lastMonthInvoices.add(lastMonthInvoice);
            }
            //請求を登録する　 戻り値を保存する
            List<Database.SaveResult> saveResult1 = Database.insert(
                lastMonthInvoices,
                false
            );
            //請求登録の戻り値をループする
            for (Database.SaveResult sr : saveResult1) {
                if (!sr.isSuccess()) {
                    //登録失敗した場合はエラーを記録して、logに出力する
                    List<Database.Error> errors = sr.getErrors();
                    recordsProcessederr1 = String.join(errors, ',');
                } else {
                    //請求登録成功の数を記録する
                    recordsProcessed1++;
                }
            }

            //登録した請求をループする　
            for (Invoice__c lastMonthInvoice : lastMonthInvoices) {
                //請求の受注会社をKEYにして、Mapからこの受注会社の関連作業実績をゲットして、lastMonthWtsに与える
                List<WorkTime__c> lastMonthWts = accIdToWorkTimes.get(
                    lastMonthInvoice.PartnerId__c
                );
                //作業実績Listをループする
                for (WorkTime__c lastMonthWt : lastMonthWts) {
                    //請求明細を作成する

                    InvoiceDetail__c newInvoiceDetail = new InvoiceDetail__c(
                        //請求id
                        InvoiceId__c = lastMonthInvoice.id,
                        //作業員工数実績id
                        PartnerStaffWorkTime__c = lastMonthWt.id,
                        //作業員ID 　  lastMonthWt.PersonalID__r.id 11:48:47:896 FATAL_ERROR System.DmlException: Insert failed. First exception on row 0; first error: STRING_TOO_LONG, 作業員ID: データ値が大きすぎる: a015h00000xom7dAAA (max length=16): [PartnerStaffId__c]
                        PartnerStaffId__c = lastMonthWt.PersonalID__r.id,
                        PartnerStaffName__c = lastMonthWt.PersonalID__r.Name__c,
                        //受発注明細id
                        PurchaseOrderDetail__c = lastMonthWt.PurchaseOrderDetail__c,
                        //標準単価
                        Price__c = lastMonthWt.PurchaseOrderDetail__r.StandardPrice__c,
                        //時間外単価
                        OverTimePrice__c = lastMonthWt.PurchaseOrderDetail__r.OverTimePrice__c,
                        //控除単価
                        DeductionPrice__c = lastMonthWt.PurchaseOrderDetail__r.DeductionPrice__c,
                        //標準時間
                        StandardHour__c = lastMonthWt.StandardTime__c,
                        //控除時間
                        MinustimeHour__c = lastMonthWt.MinustimeHour__c,
                        //残業時間
                        OvertimeHour__c = lastMonthWt.OvertimeHour__c,
                        //消費税率
                        TaxRate__c = 10
                    );
                    Decimal wqt = lastMonthWt.PurchaseOrderDetail__r.WorkQt__c;
                    Decimal standardHour = lastMonthWt.StandardTime__c;
                    Decimal overtimeHour = lastMonthWt.OvertimeHour__c;
                    Decimal minustimeHour = lastMonthWt.MinustimeHour__c;
                    Decimal standPrice = lastMonthWt.PurchaseOrderDetail__r.StandardPrice__c;
                    Decimal deductionPrice = lastMonthWt.PurchaseOrderDetail__r.DeductionPrice__c;
                    Decimal overTimePrice = lastMonthWt.PurchaseOrderDetail__r.OverTimePrice__c;

                    newInvoiceDetail.InvoiceAmount__c = (minustimeHour == 0) &&
                        (overtimeHour) == 0
                        ? standPrice * wqt
                        : overtimeHour == 0
                              ? standPrice * wqt -
                                deductionPrice * minustimeHour
                              : standPrice * wqt + overTimePrice * overtimeHour;
                    newInvoiceDetailList.add(newInvoiceDetail);
                }
            }
            //請求明細を登録する　 戻り値を保存する
            List<Database.SaveResult> saveResult2 = Database.insert(
                newInvoiceDetailList,
                false
            );
            system.debug(newInvoiceDetailList.size());

            //請求登録の戻り値をループする
            for (Database.SaveResult sr : saveResult2) {
                //登録失敗した場合はエラーを記録して、logに出力する
                if (!sr.isSuccess()) {
                    List<Database.Error> errors = sr.getErrors();
                    recordsProcessederr2 = String.join(errors, ',');
                } else {
                    //請求登録成功の数を記録する
                    recordsProcessed2++;
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(recordsProcessed1 + '請求作成');
        System.debug(recordsProcessed2 + '請求明細作成');
        System.debug('請求登録エラー:' + recordsProcessederr1);
        System.debug('請求明細登録エラー:' + recordsProcessederr2);
        //発注会社管理員へ送信する
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new List<String>{ 'diamondjsf@gmail.com' };
        mail.setToAddresses(toAddresses);
        mail.setSenderDisplayName('本月バーチ請求作成');
        mail.setSubject('本月バーチ請求作成');
        mail.setHtmlBody(
            '请求作成数：' +
            recordsProcessed1 +
            'br/' +
            '请求明细作成数：' +
            recordsProcessed2
        );
        Messaging.sendEmail(new List<Messaging.Email>{ mail });
    }
}