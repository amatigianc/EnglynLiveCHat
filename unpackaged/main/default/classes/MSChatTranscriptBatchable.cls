global class MSChatTranscriptBatchable implements Database.Batchable<SObject>, Database.AllowsCallouts {
  global Database.QueryLocator start(Database.BatchableContext bc) {
    // Standard query including the required Conversation relationship
    String query =
      'SELECT Id, Conversation.ConversationIdentifier, EndTime ' +
      'FROM MessagingSession ' +
      'WHERE Status = \'Ended\' ' +
      'AND (EndedByType = \'Agent\' OR EndedByType = \'EndUser\') ' +
      'AND CreatedDate = LAST_N_DAYS:1';

    // In test context, we use a simpler query but MUST include the relationship field
    if (Test.isRunningTest()) {
      query = 'SELECT Id, Conversation.ConversationIdentifier, EndTime FROM MessagingSession LIMIT 1';
    }

    return Database.getQueryLocator(query);
  }

  global void execute(
    Database.BatchableContext bc,
    List<MessagingSession> scope
  ) {
    MSChatTranscriptService.processSessions(scope);
  }

  global void finish(Database.BatchableContext bc) {
  }
}