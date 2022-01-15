public with sharing class getBusinessDaySchedulable implements Schedulable {
    // 设置一个String 用来组成 设置时间的字符串 '0 0 22' + 'day +  month + ? +  year '0 0 15 13 1 ? 2022';
    String executeTime = '0 0 22 ';
    String exDay;
    String exMonth;
    String exYear;
    Date firstWorkDateInThisMonth = System.Today().toStartOfMonth();
    //找到工作日
    BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = TRUE];

    public void execute(SchedulableContext ctx) {
        //check 每个月的1号是不是工作日 不是则+1继续check
        while (!BusinessHours.isWithin(bh.id, firstWorkDateInThisMonth)) {
            firstWorkDateInThisMonth = firstWorkDateInThisMonth.addDays(1);
        }
        //毎月最初営業日の2日後
        exDay = String.valueOf(firstWorkDateInThisMonth.day() + 2) + ' ';
        exMonth = String.valueOf(firstWorkDateInThisMonth.month()) + ' ? ';
        exYear = String.valueOf(firstWorkDateInThisMonth.year());
        executeTime = executeTime + exDay + exMonth + exYear;
        //设置启动batch的Schedulable job
        InvoiceSchedulable is = new InvoiceSchedulable();
        String jobID = system.schedule('businessday execute', executeTime, is);
    }
}
