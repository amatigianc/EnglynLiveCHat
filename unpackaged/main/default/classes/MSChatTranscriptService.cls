public with sharing class MSChatTranscriptService {

    public static void processSessions(List<MessagingSession> sessions) {
        List<MSChat_Transcript__c> toUpsert = new List<MSChat_Transcript__c>();
        List<MSChat_Transcript__c> toInsertErrors = new List<MSChat_Transcript__c>();

        for (MessagingSession ms : sessions) {
            try {
                MSChat_Transcript__c rec = buildTranscript(ms);
                if (rec != null) {
                    toUpsert.add(rec);
                }
            } catch (Exception e) {
                toInsertErrors.add(new MSChat_Transcript__c(
                    Messaging_Session__c = ms.Id,
                    Conversation_Identifier__c = String.valueOf(ms.Id),
                    Error_Message__c = e.getMessage(),
                    Status__c = 'Error'
                ));
            }
        }

        if (!toUpsert.isEmpty()) {
            upsert toUpsert Conversation_Identifier__c;
        }

        if (!toInsertErrors.isEmpty()) {
            insert toInsertErrors;
        }
    }

    private static MSChat_Transcript__c buildTranscript(MessagingSession ms) {
        String endpoint = URL.getOrgDomainUrl().toExternalForm() +
            '/services/data/v60.0/connect/messagingSessions/' +
            ms.Id + '/conversationEntries';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException('API failed: ' + res.getBody());
        }

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> entries = (List<Object>) payload.get('entries');

        String transcriptText = '';
        Integer total = 0;
        String firstAgentMessage = null;
        String firstAgentName = null;
        Datetime firstAgentTime = null;

        if (entries != null) {
            for (Object obj : entries) {
                Map<String, Object> entry = (Map<String, Object>) obj;
                if (entry.get('entryType') == 'Message') {
                    total++;
                    String actor = (String) entry.get('actorType');
                    String msg = (String) entry.get('messageText');
                    String timeStr = (String) entry.get('timestamp');

                    transcriptText += '[' + timeStr + '] ' + actor + ': ' + msg + '\n';

                    if (actor == 'Agent' && firstAgentMessage == null) {
                        firstAgentMessage = msg;
                        firstAgentName = (String) entry.get('actorName');
                        if (timeStr != null) {
                            firstAgentTime = (Datetime)JSON.deserialize('"' + timeStr + '"', Datetime.class);
                        }
                    }
                }
            }
        }

        return new MSChat_Transcript__c(
            Messaging_Session__c = ms.Id,
            Conversation_Identifier__c = String.valueOf(ms.Id),
            Full_Transcript__c = transcriptText,
            Total_Messages__c = total,
            First_Agent_Message__c = (firstAgentMessage != null && firstAgentMessage.length() > 255) ? firstAgentMessage.substring(0, 255) : firstAgentMessage,
            First_Agent_Name__c = firstAgentName,
            First_Agent_Response_Time__c = firstAgentTime,
            Session_End_Time__c = ms.EndTime,
            Status__c = 'Completed'
        );
    }
}