// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents

string tempvar = 'Enter_your_name_here';
System.debug('Hello World!');
System.debug('My name is ' + tempvar);

date myDate = System.today();
System.debug('aaaaaaa' + myDate);
//2022-01-13 00:00:00
Integer day = myDate.day();
Integer month = myDate.month();
Integer year = myDate.year();
System.debug('day' + day + 'month' + month + 'year' + year);

Acccount a = new Account(name = 'ssss');
insert a;
System.debug(a.id);

String executeTime = '0 0 22 ';
String exDay;
String exMonth;
String exYear;
Date firstWorkDateInThisMonth = System.Today().toStartOfMonth();
//找到工作日
BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = TRUE];
while (!BusinessHours.isWithin(bh.id, firstWorkDateInThisMonth)) {
    firstWorkDateInThisMonth = firstWorkDateInThisMonth.addDays(1);
}
//毎月最初営業日の2日後
exDay = String.valueOf(firstWorkDateInThisMonth.day() + 2) + ' ';
exMonth = String.valueOf(firstWorkDateInThisMonth.month()) + ' ? ';
exYear = String.valueOf(firstWorkDateInThisMonth.year());
executeTime = executeTime + exDay + exMonth + exYear;
System.debug(executeTime);
list<account> a = [
    SELECT
        id,
        name,
        (
            SELECT
                id,
                Account__c,
                PersonalID__r.Account__c,
                PersonalID__r.id,
                PersonalID__r.name,
                PurchaseOrderDetail__c,
                PurchaseOrderDetail__r.StandardPrice__c,
                PurchaseOrderDetail__r.OverTimePrice__c,
                PurchaseOrderDetail__r.DeductionPrice__c,
                StandardTime__c,
                MinustimeHour__c,
                OvertimeHour__c
            FROM WorkTime__r
            WHERE CreatedDate = THIS_MONTH
        )
    FROM Account
    WHERE
        Id IN (
            SELECT Account__c
            FROM WorkTime__c
            WHERE CreatedDate = THIS_MONTH
        )
];
System.debug(a);
for (account aa : a) {
    List<WorkTime__c> wts = aa.WorkTime__r;
    System.debug(wts);
}

List<AggregateResult> pjQuotes = [
    SELECT ProjectNo__c, count(ProjectNo__c)
    FROM PjQuote__c
    WHERE QuoteStatus__c = '受注承認済' AND CreateDate__c = LAST_MONTH
    GROUP BY ProjectNo__c
];
System.debug(pjQuotes.size());
for (AggregateResult pjQuote : pjQuotes) {
    system.debug(pjQuote.get('ProjectNo__c'));
}
