public with sharing class PurchaseOrderBatchHaCyu implements Database.Batchable<AggregateResult>, Database.Stateful {
    //受发注の登録数を記録する
    public Integer recordsProcessed1 = 0;
    //受发注明細の登録数を記録する
    public Integer recordsProcessed2 = 0;
    //受发注の登録失敗したら、エラーを記録する
    public String recordsProcessederr1 = '';
    //受发注明細の登録失敗したら、エラーを記録する
    public String recordsProcessederr2 = '';

    public Iterable<AggregateResult> start(Database.BatchableContext bc) {
        // 找到这个月 見積（提出締日：毎月最後営業日の２日前　作成れた）（承认终了）groupby 案件 之后拿到是的 承认了的見積的案件id
        // 今月　提出締日：毎月最後営業日の２日前　承认终了　作成れた 見積　を探す出せ　そして　案件　を単位して　groupby　その故で承認された見積の案件idをゲット

        String query = 'select ProjectNo__c from PjQuote__c where QuoteStatus__c =\'受注承認済\' And CreateDate__c = THIS_MONTH  GROUP BY ProjectNo__c';
        return new AggregateResultIterable(query);
    }
    //CreateDate__c = LAST_MONTH
    public void execute(
        Database.BatchableContext bc,
        List<AggregateResult> pjQuotes
    ) {
        //将案件id  装入 projectNameList 中
        List<String> projectNameList = new List<String>();

        Map<Id, List<PjQuoteDtil__c>> pjQuoteIdToPjQuoteDtilInfos = new Map<Id, List<PjQuoteDtil__c>>();

        //(pjQuote.get('ProjectNo__c') 获得案件id
        for (AggregateResult pjQuote : pjQuotes) {
            projectNameList.add(pjQuote.get('ProjectNo__c').toString());
        }

        // 通过案件id 重新找到所有关联的但是需要承认终了見積 之类返回的是一个id in 案件List的 所有被承认的見積的List
        // 找出所有承认了的 見積 id

        List<PjQuote__c> pjQuoteInfos = [
            SELECT
                id,
                WorkStartDay__c,
                WorkEndDay__c,
                ProjectNo__r.OwnerId,
                QuoteYm__c,
                OverTime__c,
                StandardTime__c,
                DeductionTime__c,
                MaxTime__c
            FROM pjQuote__c
            WHERE
                ProjectNo__c IN :projectNameList
                AND QuoteStatus__c = '受注承認済'
                AND CreateDate__c = THIS_MONTH
        ];
        // 再soql 一次見積明细 見積id in 上面那个見積List  根据見積id构建map Map<見積id,見積明细id>
        // 找出所有承认了的 見積 id 相关的 見積詳細id

        List<PjQuoteDtil__c> pjQuoteDtilInfos = [
            SELECT
                id,
                QuoteName__c,
                MemberName__c,
                WorkQt__c,
                Price__c,
                OverTimePrice__c,
                DeductionPrice__c
            FROM PjQuoteDtil__c
            WHERE QuoteName__c IN :pjQuoteInfos
        ];
        system.debug(pjQuoteDtilInfos.size());

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
                WorkMonth__c = pjQuoteInfo.QuoteYm__c,
                //発注締切日
                // DeadlineDay__c = '20220129',
                //ステータス
                OrderStatus__c = '作成済',
                //这个地方后面新加的
                OwnerId = pjQuoteInfo.ProjectNo__r.OwnerId,
                //超過発生時間
                OverTime__c = pjQuoteInfo.OverTime__c,
                //基準作業時間
                StandardTime__c = pjQuoteInfo.StandardTime__c,
                //控除発生時間
                DeductionTime__c = pjQuoteInfo.DeductionTime__c,
                //最大作業時間
                MaxTime__c = pjQuoteInfo.MaxTime__c
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
        for (PurchaseOrder__c hacyu : purchaseOrderList) {
            for (
                PjQuoteDtil__c pjQuoteDtilInfo : pjQuoteIdToPjQuoteDtilInfos.get(
                    hacyu.EstimateId__c
                )
            ) {
                PurchaseOrderDetail__c hacyud = new PurchaseOrderDetail__c(
                    //受発注番号
                    PurchaseOrderId__c = hacyu.id,
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