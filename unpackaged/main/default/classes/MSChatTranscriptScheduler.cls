global class MSChatTranscriptScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new MSChatTranscriptBatchable(), 50);
    }
}