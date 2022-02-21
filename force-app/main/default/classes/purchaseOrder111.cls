public with sharing class purchaseOrder111 implements Database.Batchable<sObject>, Database.Stateful {
    //受发注の登録数を記録する
    public Integer recordsProcessed1 = 0;
    //受发注明細の登録数を記録する
    public Integer recordsProcessed2 = 0;
    //受发注の登録失敗したら、エラーを記録する
    public String recordsProcessederr1 = '';
    //受发注明細の登録失敗したら、エラーを記録する
    public String recordsProcessederr2 = '';

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // 找到这个月 見積（提出締日：毎月最後営業日の２日前　作成れた）（承认终了）groupby 案件 之后拿到是的 承认了的見積的案件id
        // 今月　提出締日：毎月最後営業日の２日前　承认终了　作成れた 見積　を探す出せ　そして　案件　を単位して　groupby　その故で承認された見積の案件idをゲット

        return Database.getQueryLocator(
            'select ProjectNo__c from PjQuote__c where QuoteStatus__c =\'受注承認済\'  GROUP BY ProjectNo__c'
        );
    }
    //CreateDate__c = LAST_MONTH
    public void execute(
        Database.BatchableContext bc,
        List<AggregateResult> pjQuotes
    ) {
        //取出案件相关見積id  装入 projectNameList 中
        List<String> projectNameList = new List<String>();

        Map<Id, List<PjQuoteDtil__c>> pjQuoteIdToPjQuoteDtilInfos = new Map<Id, List<PjQuoteDtil__c>>();

        //(pjQuote.get('ProjectNo__c') 这一步根据 案件id获取 見積id
        for (AggregateResult pjQuote : pjQuotes) {
            projectNameList.add(pjQuote.get('ProjectNo__c').toString());
        }

        // 通过案件id 重新找到所有关联的但是需要承认终了見積 之类返回的是一个id in 案件List的 所有被承认的見積的List
        // 找出所有承认了的 見積 id

        List<PjQuote__c> pjQuoteInfos = [
            SELECT id
            FROM pjQuote__c
            WHERE
                ProjectNo__c IN :projectNameList
                AND QuoteStatus__c = '受注承認済'
                AND CreateDate__c = LAST_MONTH
        ];
        // 再soql 一次見積明细 見積id in 上面那个見積List  根据見積id构建map Map<見積id,見積明细id>
        // 找出所有承认了的 見積 id 相关的 見積詳細id

        List<PjQuoteDtil__c> pjQuoteDtilInfos = [
            SELECT id, QuoteName__c
            FROM PjQuoteDtil__c
            WHERE
                QuoteName__c IN (
                    SELECT id
                    FROM pjQuote__c
                    WHERE
                        id IN :projectNameList
                        AND QuoteStatus__c = '受注承認済'
                        AND CreateDate__c = LAST_MONTH
                )
        ];

        for (PjQuoteDtil__c pjQuoteDtilInfo : pjQuoteDtilInfos) {
            if (
                pjQuoteIdToPjQuoteDtilInfos.containsKey(
                    pjQuoteDtilInfo.QuoteName__c
                )
            ) {
                pjQuoteIdToPjQuoteDtilInfos.get(pjQuoteDtilInfo.QuoteName__c)
                    .add(pjQuoteDtilInfo);
            } else {
                List<PjQuoteDtil__c> newPjqdList = new List<PjQuoteDtil__c>();
                newPjqdList.add(pjQuoteDtilInfo);
                pjQuoteIdToPjQuoteDtilInfos.put(
                    pjQuoteDtilInfo.QuoteName__c,
                    newPjqdList
                );
            }
        }

        // 根据見積 创建 受发注
        // 根据 見積明细 创建 受发注明细
        List<PurchaseOrder__c> purchaseOrderList = new List<PurchaseOrder__c>();

        for (PjQuote__c pjQuoteInfo : pjQuoteInfos) {
            PurchaseOrder__c hacyu = new PurchaseOrder__c(
                //見積番号
                EstimateId__c = pjQuoteInfo.id,
                //契約種別
                ContractType__c = '作業請負',
                //契約状態
                ContractStatus__c = '新規契約',
                //発注年月日
                OrderYMD__c = System.today(),
                //作業年月
                WorkMonth__c = String.valueof(
                    pjQuoteInfo.WorkStartDay__c.daysBetween(
                        pjQuoteInfo.WorkEndDay__c
                    )
                ),
                //発注締切日
                // DeadlineDay__c = '20220129',
                //ステータス
                OrderStatus__c = '作成済'
            );
            purchaseOrderList.add(hacyu);
        }

        List<Database.SaveResult> saveResult1 = Database.insert(
            purchaseOrderList,
            false
        );

        for (Database.SaveResult sr : saveResult1) {
            if (!sr.isSuccess()) {
                //受发注登録失敗した場合はエラーを記録して、logに出力する
                List<Database.Error> errors = sr.getErrors();
                recordsProcessederr1 = String.join(errors, ',');
            } else {
                //受发注請求登録成功の数を記録する
                recordsProcessed1++;
            }
        }

        List<PurchaseOrderDetail__c> purchaseOrderDetailList = new List<PurchaseOrderDetail__c>();
        for (PjQuoteDtil__c pjQuoteDtilInfo : pjQuoteDtilInfos) {
            PurchaseOrderDetail__c hacyud = new PurchaseOrderDetail__c(
                //受発注番号
                PurchaseOrderId__c = pjQuoteDtilInfo.QuoteName__c,
                //作業員氏名
                PartnerMember__c = pjQuoteDtilInfo.MemberName__c,
                //工数
                WorkQt__c = pjQuoteDtilInfo.WorkQt__c,
                //標準単価
                StandardPrice__c = pjQuoteDtilInfo.Price__c,
                //時間外単価
                OverTimePrice__c = pjQuoteDtilInfo.OverTimePrice__c,
                //控除単価
                DeductionPrice__c = pjQuoteDtilInfo.DeductionPrice__c
            );
            purchaseOrderDetailList.add(hacyud);
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
                //受发注明细請求登録成功の数を記録する
                recordsProcessed2++;
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(recordsProcessed1 + '受发注作成');
        System.debug(recordsProcessed2 + '受发注明細作成');
        System.debug('受发注登録エラー:' + recordsProcessederr1);
        System.debug('受发注明細登録エラー:' + recordsProcessederr2);
        //発注会社管理員へ送信する
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new List<String>{ 'diamondjsf@gmail.com' };
        mail.setToAddresses(toAddresses);
        mail.setSenderDisplayName('本月バーチ受发注作成');
        mail.setSubject('本月バーチ受发注作成');
        mail.setHtmlBody(
            '受发注作成数：' +
            recordsProcessed1 +
            'br/' +
            '受发注明细作成数：' +
            recordsProcessed2
        );
        Messaging.sendEmail(new List<Messaging.Email>{ mail });
    }
}
