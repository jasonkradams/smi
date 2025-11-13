EntitySubscription es = new EntitySubscription();
es.ParentId = '00UUm00000QudZBMAZ';
es.SubscriberId = '0052G00000AVquPQAT';
try {
    insert es;
    System.debug('Inserted: ' + es.Id);
} catch (Exception ex) {
    System.debug('Insert failed: ' + ex.getMessage());
}
