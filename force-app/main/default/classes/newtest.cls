
public with sharing class PjQuoteBatchHandle implements Database.Batchable<sObject>, Database.Stateful {
//设置一个计数最后生成多少个请求
public Integer recordsProcessed1 = 0;
//设置一个计数最后生成多少个请求明细
public Integer recordsProcessed2 = 0;

public void execute(SchedulableContext scon) {
Database.executeBatch(new CreateEstimate (),200);
}

//来月の初日を取得する
public date firstOfNextMonth = date.today().addmonths(1).toStartOfMonth();
//来月の末日を取得する
public date endOfNextMonth = date.today().addmonths(2).toStartOfMonth().addDays(-1);

public Database.QueryLocator start(Database.BatchableContext bc) {
//来月の見積用の案件を出す(案件開始日 <=  来月末日(来月末日まで開始する)  
//かつ　(案件終了日 is null or 案件終了日 >= 来月初日)(来月初日までまだ終わってない))
//発注会社名,案件番号,案件名,所有者を取得する
return Database.getQueryLocator(
'select OrderCompany__c,Name,AnkenName__c,OwnerId from Anken__c where WorkStartDay__c <= :endOfNextMonth  ' +
'and (WorkEndDay__c = null or WorkEndDay__c >= :firstOfNextMonth ) '
);
}

public void execute(Database.BatchableContext bc, List<Anken__c> ankens) {  
//見積リスト
List<PjQuote__c> pjQuotes = new List<PjQuote__c>();
//見積明細リスト
List<PjQuote_Dtil__c> estimateDetails = new List<PjQuote_Dtil__c>();
//見積明細リスト_insert用
List<PjQuote_Dtil__c> estimateDetails_insert = new List<PjQuote_Dtil__c>();
//見積と見積明細のMAP
Map<String, List<PjQuote_Dtil__c>> mapPjQuoteDetail = new Map<String, List<PjQuote_Dtil__c>>();  

//来月を取得する(例:202202)
String nextYM = datetime.now().addMonths(1).format().substring(0,4) + datetime.now().addMonths(1).format().substring(5,7); 

//案件情報をループする
for(Anken__c anken : ankens) {
//mapID
String mapID = null;
//初期値の受注会社
String orderedCompany = null;
//受注会社情報(所属会社,個人識別ID,単価,作業時間上限 ,作業時間下限)を取得する
List<OperatorInformation__c> accountOfWorkers = [select Account__c,Name,Price__c,MaxTime__c,MinimumTime__c from OperatorInformation__c where AnkenNumber__c = :anken.Name and Status__c = '継続'];
//受注会社情報ループ開始
for(OperatorInformation__c accountOfWorker:accountOfWorkers) {
//受注会社管理責任者氏名を取得する
String OrderCompanyManager = [select Name from Contact where AccountId = :accountOfWorker.Account__c];
 
//初期値の受注会社とリストの受注会社違う時、見積を作成する
if(orderedCompany != accountOfWorker.Account__c) {
//map見積IDはnullではない場合、見積明細リストをMapに入れる
if (mapID != null) {
mapPjQuoteDetail.put(mapID,estimateDetails);
estimateDetails = new List<PjQuote_Dtil__c>();
}
//リストの受注会社の値を初期値の受注会社に与える
orderedCompany = accountOfWorker.Account__c;
//見積を作成する
PjQuote__c estimate = new PjQuote__c();
//見積名:案件情報.案件名_YYYYMM
estimate.Name = anken.ProjectName__c + '_' + nextYM;  
//見積年月:システム日より次月をセット
estimate.QuoteYm__c = nextYM;
//発注会社責任者:案件情報．所有者
estimate.WorkManagerName__c = anken.OwnerId;  
//見積ステータス
estimate.QuoteStatus__c = '作成済';  
//案件番号:変数．案件番号
estimate.ProjectNo__r = anken.Name;  
//案件名:案件情報.案件名
estimate.ProjectName__c = anken.AnkenName__c;  
//発注会社名:案件情報.発注会社
estimate.OrderCompanyName__c = anken.OrderCompany__c; 
//受注会社名:変数．受注会社名
estimate.OrdersReceivedCompany__r = accountOfWorker.Account__c;
//受注会社管理責任者氏名:変数．受注会社責任者
estimate.OrdersReceivedEmp__c= OrderCompanyManager;
//mapKey:受注会社+案件
mapID = estimate.OrdersReceivedCompany__r.to15() + estimate.ProjectName__c.to15();
estimates.add(estimate);
}
//見積明細を作成する
PjQuote_Dtil__c estimateDetail = new PjQuote_Dtil__c();
//見積名称:案件情報.案件名_YYYYMM
estimateDetail.QuoteName__c = anken.ProjectName__c + '_' + nextYM; 
//氏名:個人識別ID
estimateDetail.MemberName__r = accountOfWorker.Name;
//工数:1
estimateDetail.WorkQt__c = '1';
//単価:作業者情報.単価
estimateDetail.Price__c = accountOfWorker.Price__c;
//控除単価:作業者情報.単価/作業者情報.作業時間下限 
estimateDetail.DeductionPrice__c = floor(accountOfWorker.Price__c/accountOfWorker.MinimumTime__c);
//時間外単価:作業者情報.単価/作業者情報.作業時間上限
estimateDetail.OverTimePrice__c = floor(accountOfWorker.Price__c/accountOfWorker.MaxTime__c);
estimateDetails.add(estimateDetail);
}
//map見積IDはnullではない場合、見積リストをMapに入れる
if (mapID != null) {
mapPjQuoteDetail.put(mapID,estimateDetails);
estimateDetails = new List<PjQuote_Dtil__c>();
}
}
 
//見積を登録する　 戻り値を保存する
List<Database.SaveResult> saveResult1 = Database.insert(
estimates,
false
);
//請求登録の戻り値をループする
for (Database.SaveResult sr : saveResult1) {
if (!sr.isSuccess()) {
//登録失敗した場合はエラーを記録して、logに出力する
List<Database.Error> errors = sr.getErrors();
recordsProcessederr1 = String.join(errors, ',');
} else {
//見積登録成功の数を記録する
recordsProcessed1++;
}
}

//見積をループする
for(PjQuote__c estimate : estimates) {
//見積明細リストを取得する
estimateDetails = mapPjQuoteDetail.get(estimate.OrdersReceivedCompany__r.to15() + estimate.ProjectName__c.to15());
if (estimateDetails != null){
//見積明細をループする
for(PjQuote_Dtil__c estimateDetail : estimateDetails) {
//新規した見積番号を見積明細の見積に与える
estimateDetail.QuoteName__c = estimate.QuoteCode__c;
estimateDetails_insert.add(estimateDetail);
}
}
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
'見積明细作成'
);
Messaging.sendEmail(new List<Messaging.Email>{ mail });
}
}
