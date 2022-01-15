public with sharing class InvoiceSchedulable implements Schedulable {
    // 设置一个String 用来组成 设置时间的字符串 '0 0 22' + 'day +  month + ? +  year
    //一个select day 用来表示batch启动日
    //获取当月的第一个工作日  如果今天是当天  则firstday = today
    //如果否则 进行一个while 循环 来+1 来获取工作日
    //得到准确的当月第一个工作日之后 再+2 确定 selectday
    //执行batch就可以了

    Date firstDate = System.today().toStartOfMonth();
    String 
    //実績登録締め日夜の日付を得る
    Date today = System.today();
    //日のナンバー
    Integer day = today.day();
    //月のナンバー
    Integer month = today.month();
    //年のナンバー
    Integer year = today.year();

    Date selectedDate = Date.today().addMonths(11);
    Date lastDate = selectedDate.toStartOfMonth()
        .addDays(
            Date.daysInMonth(selectedDate.year(), selectedDate.month()) - 1
        );

    BusinessHours bh = [SELECT Id FROM BusinessHours WHERE IsDefault = TRUE];
    Boolean isWithin = BusinessHours.isWithin(bh.id, firstDate);

    public static String CRON_EXP = '0 0 15 13 1 ? 2022';
    public static String CRON_EXP_Time = '0 0 15 13 1 ? 2022';

    public void execute(SchedulableContext ctx) {
        if (firstDate != System.today()) {
            //找到第二个工作日 在当晚10点执行
        } else {
            //在今晚10点执行batch
        }

        Date firstDate = System.Today().toStartOfMonth();
        while (!BusinessHours.isWithin(bh.id, firstDate)) {
            firstDate = firstDate.addDays(1);
        }
        Integer day = today.day();
        //月のナンバー
        Integer month = today.month();
        //年のナンバー
        Integer year = today.year();

        Account a = [
            SELECT Id, Name
            FROM Account
            WHERE Name = 'testScheduledApexFromTestMethod'
        ];
        a.name = 'testScheduledApexFromTestMethodUpdated';
        update a;
    }
}
