@isTest
public with sharing class InvoiceSchedulableTest {
    static testMethod void test() {
        // 创建一个单独的作业实绩
        //创建一个请求 主
        //创建一个请求明细连接到作业实绩上  然后汇总到 请求上
        //设置一个jobid 然后启动schedule
        //获取刚刚那个job的执行时间 与之前设定的schedule执行时间进行check
        //获取是否执行schedule
        //获取执行的时间
        //获取当前的请求 在test end之前 check 没有找到请求
        //test end之后 对这个请求进行查找

        Test.startTest();
        Account a = new Account();
        a.Name = 'testScheduledApexFromTestMethod';
        insert a;

        String jobId = System.schedule(
            'testBasicScheduledApex',
            TestScheduledApexFromTestMethod.CRON_EXP,
            new TestScheduledApexFromTestMethod()
        );

        CronTrigger ct = [
            SELECT Id, CronExpression, TimesTriggered, NextFireTime
            FROM CronTrigger
            WHERE id = :jobId
        ];

        // Verify the expressions are the same
        System.assertEquals(
            TestScheduledApexFromTestMethod.CRON_EXP,
            ct.CronExpression
        );

        // Verify the job has not run
        System.assertEquals(0, ct.TimesTriggered);

        // Verify the next time the job will run
        System.assertEquals(
            '2022-09-03 00:00:00',
            String.valueOf(ct.NextFireTime)
        );
        System.assertNotEquals(
            'testScheduledApexFromTestMethodUpdated',
            [SELECT id, name FROM account WHERE id = :a.id]
            .name
        );

        Test.stopTest();

        System.assertEquals(
            'testScheduledApexFromTestMethodUpdated',
            [SELECT Id, Name FROM Account WHERE Id = :a.Id]
            .Name
        );
    }
}
