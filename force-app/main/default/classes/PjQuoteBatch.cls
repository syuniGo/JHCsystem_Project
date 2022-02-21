public with sharing class PjQuoteBatch implements Database.Batchable<sObject>, Database.Stateful {
    //设置一个计数最后生成多少个请求
    public Integer recordsProcessed1 = 0;
    //设置一个计数最后生成多少个请求明细
    public Integer recordsProcessed2 = 0;
    //請求の登録失敗したら、エラーを記録する
    public String recordsProcessederr1 = '';
    //請求明細の登録失敗したら、エラーを記録する
    public String recordsProcessederr2 = '';
    //来月の初日を取得する
    public date firstOfNextMonth = date.today().addmonths(1).toStartOfMonth();
    //来月の末日を取得する
    public date endOfNextMonth = date.today()
        .addmonths(2)
        .toStartOfMonth()
        .addDays(-1);

    public Database.QueryLocator start(Database.BatchableContext bc) {
        //来月の見積用の案件を出す(案件開始日 <= 来月末日(来月末日まで開始する)
        //かつ　(案件終了日 is null or 案件終了日 >= 来月初日)(来月初日までまだ終わってない))
        //発注会社名,案件番号,案件名,所有者を取得する
        return Database.getQueryLocator(
            'select OrderCompany__c,Name,AnkenName__c,OwnerId,(select Account__c,Account__r.name,id,Name,Price__c,MaxTime__c,MinimumTime__c,AnkenNumber__c ,Status__c from OperatorInformation__r) from Anken__c where WorkStartDay__c <= :endOfNextMonth ' +
            'and (WorkEndDay__c = null or WorkEndDay__c >= :firstOfNextMonth ) '
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
            //List<OperatorInformation__c> oldAnkenOWorkers = new List<OperatorInformation__c>();
            //mapID
            String mapID = null;
            //初期値の受注会社
            String orderedCompany = null;
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

        //找到所有受注公司的 责任者用户
        //如果这个案件没有相关作业员 则是新案件 見積根据作业员情报和案件情报填数据
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
        }

        List<User> CompanyManagers = [
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
        }

        //新案件根据 案件 ——作业员.公司———来作成見積
        Map<String, Id> mapCompanyIdAndAnkenIdToPjQuoteId = new Map<String, Id>();

        for (
            Anken__c newAnken : newAnkenToOperatorInformationListMap.keySet()
        ) {
            Set<String> companyId1 = new Set<String>();
            for (
                List<OperatorInformation__c> OperatorInformations : newAnkenToOperatorInformationListMap.Values()
            ) {
                for (
                    OperatorInformation__c OperatorInformation : OperatorInformations
                ) {
                    if (!companyName.contains(OperatorInformation.Account__c)) {
                        PjQuote__c estimate = new PjQuote__c();
                        //見積名:案件情報.案件名_YYYYMM
                        system.debug('nextYM:' + nextYM);
                        estimate.Name = '12';
                        //見積年月:システム日より次月をセット
                        estimate.QuoteYm__c = nextYM;
                        //発注会社責任者:案件情報．所有者
                        estimate.WorkManagerName__c = newAnken.OwnerId;
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
                        estimate.OrdersReceivedEmp__c = companyNameToUserIdMap.get(
                            OperatorInformation.Account__r.name
                        );
                        System.debug()
                        companyId1.add(OperatorInformation.Account__c);
                        String mapKey =estimate.OrdersReceivedCompany__c + estimate.ProjectNo__c;
                        mapCompanyIdAndAnkenIdToPjQuoteId.put(
                            mapKey,
                            estimate.id
                        );
                        estimates.add(estimate);
                    }
                }
            }
        }

        List<Database.SaveResult> saveResult1 = Database.insert(
            estimates,
            false
        );

        //見積登録成功の数を記録する
        recordsProcessed1 = saveResult1.size();
        system.debug('saveResult1:' + saveResult1);

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
                estimateDetail.QuoteName__c = mapCompanyIdAndAnkenIdToPjQuoteId.get(
                        OperatorInformation.Account__c + newAnken.id
                    )
                    .id;

                system.debug('test QuoteName:' + estimateDetail.QuoteName__c);
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
                estimateDetails.add(estimateDetail);
            }
            //見積明細を登録する　 戻り値を保存する
            List<Database.SaveResult> saveResult2 = Database.insert(
                estimateDetails,
                false
            );

            recordsProcessed2 = saveResult2.size();
            //見積明細登録の戻り値をループする
            for (Database.SaveResult sr : saveResult2) {
                //登録失敗した場合はエラーを記録して、logに出力する
                if (!sr.isSuccess()) {
                    List<Database.Error> errors = sr.getErrors();
                    recordsProcessederr2 = String.join(errors, ',');
                }else{
                    
                }
            }
        }
    }
    public void finish(Database.BatchableContext bc) {
        System.debug(recordsProcessed1 + '見積作成');
        System.debug(recordsProcessed2 + '見積明细作成');
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
