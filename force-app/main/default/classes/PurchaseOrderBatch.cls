public with sharing class PurchaseOrderBatch {
    //請求の登録数を記録する
    public Integer recordsProcessed1 = 0;
    //請求明細の登録数を記録する
    public Integer recordsProcessed2 = 0;
    //請求の登録失敗したら、エラーを記録する
    public String recordsProcessederr1 = '';
    //請求明細の登録失敗したら、エラーを記録する
    public String recordsProcessederr2 = '';

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // 找到这个月見積提出日之前作成的見積（承认终了的） groupby 案件 之后拿到是的 承认了的見積的案件id
        return Database.getQueryLocator(
            'select ProjectNo__c from PjQuote__c where QuoteStatus__c =\'受注承認済\' And CreateDate__c = LAST_MONTH GROUP BY ProjectNo__c'
        );
    }

    public void execute(
        Database.BatchableContext bc,
        List<AggregateResult> pjQuotes
    ) {
        List<String> projectNameList = new List<String>();
        Map<Id, PjQuoteDtil__c> pjQuoteIdToPjQuoteDtilInfos = new Map<Id, PjQuoteDtil__c>();

        for (AggregateResult pjQuote : pjQuotes) {
            projectNameList.add(pjQuote.get('ProjectNo__c'));
        }

        // 通过这些案件id 重新找到所有关联的但是需要承认终了見積 之类返回的是一个id in 案件list的 所有被承认的見積的list
        List<PjQuote__c> pjQuoteInfos = [
            SELECT id
            FROM pjQuote__c
            WHERE
                id IN :projectNameList
                AND QuoteStatus__c = '受注承認済'
                AND CreateDate__c = LAST_MONTH
        ];
        // 再soql 一次見積明细 見積id in 上面那个見積list  根据見積构建map
        List<PjQuoteDtil__c> pjQuoteDtilInfos = [
            SELECT id, QuoteName__c
            FROM PjQuoteDtil__c
            WHERE id IN :pjQuoteInfos
        ];

        for (PjQuoteDtil__c pjQuoteDtilInfo : pjQuoteDtilInfos) {
            pjQuoteIdToPjQuoteDtilInfos.put(
                pjQuoteDtilInfo.QuoteName__c,
                pjQuoteDtilInfo
            );
        }

        // 根据見積 创建 受发注 根据 見積明细 创建 发注明细
        List<PurchaseOrder__c> purchaseOrderList = new List<PurchaseOrder__c>();
        for (PjQuote__c pjQuoteInfo : pjQuoteInfos) {
            PurchaseOrder__c po = new PurchaseOrder__c(
                EstimateId__c = pjQuoteInfo.id,
                ContractType__c = '作業請負',
                ContractStatus__c = '新規契約',
                WorkMonth__c = '202201',
                OrderStatus__c = '作成済'
            );
            purchaseOrderList.add(po);
        }

        List<Database.SaveResult> saveResult1 = Database.insert(
            purchaseOrderList,
            false
        );

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

        List<PurchaseOrderDetail__c> purchaseOrderDetailList = new List<PurchaseOrder__c>();
        for (PjQuoteDtil__c pjQuoteDtilInfo : pjQuoteDtilInfos) {
            PurchaseOrderDetail__c pod = new PurchaseOrderDetail__c(
                PurchaseOrderId__c = pjQuoteDtilInfo.QuoteName__c,
                PartnerMember__c = pjqd.MemberName__c,
                WorkQt__c = 1,
                StandardPrice__c = 100,
                OverTimePrice__c = 200,
                DeductionPrice__c = 100
            );
            purchaseOrderDetailList.add(pod);
        }
        List<Database.SaveResult> saveResult2 = Database.insert(
            purchaseOrderDetailList,
            false
        );

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

    public void finish(Database.BatchableContext bc) {
        /*         System.debug(recordsProcessed1 + '請求作成');
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
        Messaging.sendEmail(new List<Messaging.Email>{ mail }); */
    }
}
