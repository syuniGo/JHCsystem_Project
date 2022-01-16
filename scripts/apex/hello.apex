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
