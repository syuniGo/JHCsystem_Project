public with sharing class InvoiceSchedulable implements Schedulable {
    public void execute(SchedulableContext ctx) {
        InvoiceBatchHandle ibh = new InvoiceBatchHandle();
        Database.executeBatch(ibh, 200);
    }
}
