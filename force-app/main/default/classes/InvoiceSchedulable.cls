public with sharing class InvoiceSchedulable implements Schedulable {
    public void execute(SchedulableContext ctx) {
        InvoiceBatchHandle2 ibh = new InvoiceBatchHandle2();
        Database.executeBatch(ibh, 200);
    }
}
