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
