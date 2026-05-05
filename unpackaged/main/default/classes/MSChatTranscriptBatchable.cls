global class MSChatTranscriptBatchable implements Database.Batchable<SObject>, Database.AllowsCallouts {

    global Database.QueryLocator start(Database.BatchableContext bc) {
        if (Test.isRunningTest()) {
            return Database.getQueryLocator([SELECT Id, EndTime FROM MessagingSession LIMIT 1]);
        }
        return Database.getQueryLocator([SELECT Id, EndTime FROM MessagingSession WHERE CreatedDate = LAST_N_DAYS:1]);
    }

    global void execute(Database.BatchableContext bc, List<MessagingSession> scope) {
        MSChatTranscriptService.processSessions(scope);
    }

    global void finish(Database.BatchableContext bc) {}
}