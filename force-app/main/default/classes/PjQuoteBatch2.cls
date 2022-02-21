public with sharing class PjQuoteBatch2 implements Database.Batchable<sObject>, Database.Stateful {
    //设置一个计数最后生成多少个请求
    public Integer recordsProcessed1 = 0;
    //设置一个计数最后生成多少个请求明细
    public Integer recordsProcessed2 = 0;
    //請求の登録失敗したら、エラーを記録する
    public String recordsProcessederr1 = '';
    //請求明細の登録失敗したら、エラーを記録する
    public String recordsProcessederr2 = '';
    //来月の初日を取得する
    public date firstOfNextMonth = System.today().addmonths(1).toStartOfMonth();
    //来月の末日を取得する
    public date endOfNextMonth = System.today()
        .addmonths(2)
        .toStartOfMonth()
        .addDays(-1);

    public Database.QueryLocator start(Database.BatchableContext bc) {
        //来月の見積用の案件を出す(案件開始日 <= 来月末日(来月末日まで開始する)
        //かつ　(案件終了日 is null or 案件終了日 >= 来月初日)(来月初日までまだ終わってない))
        //発注会社名,案件番号,案件名,所有者を取得する
        return Database.getQueryLocator(
            'select OrderCompany__c,Name,AnkenName__c,OwnerId,(select Account__c,Account__r.name,id,Name,Price__c,AnkenNumber__c ,Status__c,MaxTime__c,StandardTime__c,MinimumTime__c from OperatorInformation__r) from Anken__c where WorkStartDay__c <= :endOfNextMonth and (WorkEndDay__c = null or WorkEndDay__c >= :firstOfNextMonth ) '
        );
    }

    public void execute(Database.BatchableContext bc, List<Anken__c> ankens) {
        //見積リスト
        List<PjQuote__c> estimates = new List<PjQuote__c>();
        //見積明細リスト
        List<PjQuoteDtil__c> estimateDetails = new List<PjQuoteDtil__c>();
        //見積明細リスト_insert用
        List<PjQuoteDtil__c> estimateDetails_insert = new List<PjQuoteDtil__c>();
        //見積と見積明細のMAP

        //来月を取得する(例:202202)
        String nextYM =
            datetime.now().addMonths(1).format().substring(0, 4) +
            datetime.now().addMonths(1).format().substring(5, 7);
        //找到所有正在进行的案件和与这个案件相关的作业员
        //有作业员的案件
        Map<Anken__c, List<OperatorInformation__c>> newAnkenToOperatorInformationListMap = new Map<Anken__c, List<OperatorInformation__c>>();
        List<OperatorInformation__c> allAnkenWorkers = new List<OperatorInformation__c>();

        //案件情報をループする
        for (Anken__c anken : ankens) {
            List<OperatorInformation__c> newAnkenOWorkers = new List<OperatorInformation__c>();

            //受注会社情報(所属会社,個人識別ID,単価,作業時間上限 ,作業時間下限)を取得する
            //查看每一个作业员的该的作业状态是否继续
            for (
                OperatorInformation__c OperatorInformation : anken.OperatorInformation__r
            ) {
                if (
                    OperatorInformation.AnkenNumber__c == anken.id &&
                    OperatorInformation.Status__c == '継続'
                ) {
                    newAnkenOWorkers.add(OperatorInformation);
                }
            }
            newAnkenToOperatorInformationListMap.put(anken, newAnkenOWorkers);
        }

        /*    //找到所有受注公司的 责任者用户
        Map<String, Id> companyNameToUserIdMap = new Map<String, Id>();
        //所有案件的所属作业员的公司id的set
        Set<String> companyName = new Set<String>();
        for (
            List<OperatorInformation__c> OperatorInformations : newAnkenToOperatorInformationListMap.Values()
        ) {
            for (
                OperatorInformation__c OperatorInformation : OperatorInformations
            ) {
                companyName.add(OperatorInformation.Account__r.name);
            }
        } */

        /*      List<User> CompanyManagers = [
            SELECT Id, CompanyName
            FROM User
            WHERE
                CompanyName IN :companyName
                AND UserRole.name LIKE '%マネージャ%'
        ];
        for (User CompanyManager : CompanyManagers) {
            companyNameToUserIdMap.put(
                CompanyManager.CompanyName,
                CompanyManager.id
            );
        } */

        //新案件根据 案件 ——作业员.公司———来作成見積
        Map<String, Id> mapCompanyIdAndAnkenIdToPjQuoteId = new Map<String, Id>();

        for (
            Anken__c newAnken : newAnkenToOperatorInformationListMap.keySet()
        ) {
            Set<String> companyId1 = new Set<String>();
            for (
                OperatorInformation__c OperatorInformation : newAnkenToOperatorInformationListMap.get(
                    newAnken
                )
            ) {
                if (!companyId1.contains(OperatorInformation.Account__c)) {
                    PjQuote__c estimate = new PjQuote__c();
                    //見積名:案件情報.案件名_YYYYMM
                    system.debug('nextYM:' + nextYM);
                    estimate.Name =
                        newAnken.name +
                        OperatorInformation.Account__r.Name +
                        nextYM;
                    //見積年月:システム日より次月をセット
                    estimate.QuoteYm__c = nextYM;
                    //発注会社責任者:案件情報．所有者
                    //estimate.WorkManagerName__c = newAnken.OwnerId;
                    //見積ステータス
                    estimate.QuoteStatus__c = '作成済';
                    //案件番号:変数．案件番号
                    estimate.ProjectNo__c = newAnken.id;
                    //案件名:案件情報.案件名
                    //estimate.ProjectName__c = newAnken.AnkenName__c;
                    //発注会社名:案件情報.発注会社
                    //estimate.OrderCompanyName__c = newAnken.OrderCompany__c;
                    //受注会社名:変数．受注会社名
                    estimate.OrdersReceivedCompany__c = OperatorInformation.Account__c;
                    //受注会社管理責任者氏名:変数．受注会社責任者
                    //estimate.OrdersReceivedEmp__c = companyNameToUserIdMap.get(
                    //OperatorInformation.Account__r.name
                    //);

                    estimate.OwnerId = newAnken.OwnerId;

                    //超過発生時間
                    estimate.OverTime__c = OperatorInformation.MaxTime__c;
                    //基準作業時間
                    estimate.StandardTime__c = OperatorInformation.StandardTime__c;
                    //控除発生時間
                    estimate.DeductionTime__c = OperatorInformation.MinimumTime__c;
                    //最大作業時間
                    estimate.MaxTime__c = estimate.OverTime__c + 45;

                    companyId1.add(OperatorInformation.Account__c);
                    estimates.add(estimate);
                }
            }
        }

        List<Database.SaveResult> saveResult1 = Database.insert(
            estimates,
            false
        );
        for (Database.SaveResult sr : saveResult1) {
            //登録失敗した場合はエラーを記録して、logに出力する
            if (!sr.isSuccess()) {
                List<Database.Error> errors = sr.getErrors();
                recordsProcessederr1 = String.join(errors, ',');
            } else {
                recordsProcessed1++;
            }
        }
        //見積登録成功の数を記録する

        system.debug('saveResult1:' + saveResult1);

        for (PjQuote__c estimate : estimates) {
            String mapKey1 = estimate.OrdersReceivedCompany__c;
            String mapKey2 = estimate.ProjectNo__c;
            mapCompanyIdAndAnkenIdToPjQuoteId.put(
                mapKey1 + mapKey2,
                estimate.id
            );
        }

        for (
            Anken__c newAnken : newAnkenToOperatorInformationListMap.keySet()
        ) {
            for (
                OperatorInformation__c OperatorInformation : newAnkenToOperatorInformationListMap.get(
                    newAnken
                )
            ) {
                //見積明細を作成する
                PjQuoteDtil__c estimateDetail = new PjQuoteDtil__c();
                //見積名称:案件情報.案件名_YYYYMM
                String mapKey1 = OperatorInformation.Account__c;
                String mapKey2 = newAnken.id;
                estimateDetail.QuoteName__c = mapCompanyIdAndAnkenIdToPjQuoteId.get(
                    mapKey1 + mapKey2
                );

                system.debug(
                    'test QuoteName:' +
                    mapCompanyIdAndAnkenIdToPjQuoteId.get(mapKey1 + mapKey2)
                );
                //氏名:個人識別ID
                estimateDetail.MemberName__c = OperatorInformation.id;
                //工数:1
                estimateDetail.WorkQt__c = 1;
                //単価:作業者情報.単価
                estimateDetail.Price__c = OperatorInformation.Price__c;
                //控除単価:作業者情報.単価/作業者情報.作業時間下限
                estimateDetail.DeductionPrice__c = (OperatorInformation.Price__c /
                    OperatorInformation.MinimumTime__c)
                    .round(System.RoundingMode.DOWN);
                //時間外単価:作業者情報.単価/作業者情報.作業時間上限
                estimateDetail.OverTimePrice__c = (OperatorInformation.Price__c /
                    OperatorInformation.MaxTime__c)
                    .round(System.RoundingMode.DOWN);
                estimateDetail.AnkenId__c = newAnken.id;

                estimateDetails.add(estimateDetail);
            }
            //見積明細を登録する　 戻り値を保存する
            List<Database.SaveResult> saveResult2 = Database.insert(
                estimateDetails,
                false
            );

            //見積明細登録の戻り値をループする
            for (Database.SaveResult sr : saveResult2) {
                //登録失敗した場合はエラーを記録して、logに出力する
                if (!sr.isSuccess()) {
                    List<Database.Error> errors = sr.getErrors();
                    recordsProcessederr2 = String.join(errors, ',');
                } else {
                    recordsProcessed2++;
                }
            }
        }
    }
    public void finish(Database.BatchableContext bc) {
        System.debug(recordsProcessed1 + '見積作成');
        System.debug(recordsProcessed2 + '見積明细作成');
        System.debug('見積error' + recordsProcessederr1);
        System.debug('見積明细error' + recordsProcessederr2);
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = new List<String>{ 'useizen01@gmail.com' };
        mail.setToAddresses(toAddresses);
        mail.setSenderDisplayName('来月バーチ見積作成');
        mail.setSubject('来月バーチ見積作成');
        mail.setHtmlBody(
            recordsProcessed1 +
            '見積作成' +
            recordsProcessed2 +
            '見積明细作成' +
            recordsProcessederr1 +
            'エラー件数見積作成' +
            recordsProcessederr2 +
            'エラー件数見積明细作成'
        );
        Messaging.sendEmail(new List<Messaging.Email>{ mail });
    }
}
