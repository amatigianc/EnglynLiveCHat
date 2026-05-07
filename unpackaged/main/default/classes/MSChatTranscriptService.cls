public with sharing class MSChatTranscriptService {
    public static void processSessions(List<MessagingSession> sessions) {
        Map<String, MSChat_Transcript__c> toUpsertMap = new Map<String, MSChat_Transcript__c>();
        List<MSChat_Transcript__c> toInsertErrors = new List<MSChat_Transcript__c>();

        for (MessagingSession ms : sessions) {
            String convId = ms.Conversation?.ConversationIdentifier;
            if (String.isBlank(convId)) continue;

            try {
                MSChat_Transcript__c rec = buildTranscript(ms);
                if (rec != null) toUpsertMap.put(convId, rec);
            } catch (Exception e) {
                toInsertErrors.add(new MSChat_Transcript__c(
                    Messaging_Session__c = ms.Id,
                    Conversation_Identifier__c = convId,
                    Error_Message__c = e.getMessage() + ' (Line: ' + e.getLineNumber() + ')',
                    Status__c = 'Error'
                ));
            }
        }

        if (!toUpsertMap.isEmpty()) upsert toUpsertMap.values() Conversation_Identifier__c;
        if (!toInsertErrors.isEmpty()) insert toInsertErrors;
    }

    private static MSChat_Transcript__c buildTranscript(MessagingSession ms) {
        String convId = ms.Conversation.ConversationIdentifier;
        String endpoint = URL.getOrgDomainUrl().toExternalForm() + 
                         '/services/data/v60.0/connect/conversation/' + convId + '/entries';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');

        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() != 200) throw new CalloutException('HTTP ' + res.getStatusCode());

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> entries = (List<Object>) payload.get('conversationEntries');

        String htmlTranscript = '<div style="font-family: sans-serif; line-height: 1.5;">';
        Integer total = 0;
        String firstHumanMsg = null;
        String firstHumanName = null;
        Datetime firstHumanTime = null;

        if (entries != null && !entries.isEmpty()) {
            // STEP 1: Reverse the list to get Oldest -> Newest order
            List<Object> chronologicalEntries = new List<Object>();
            for(Integer i = entries.size() - 1; i >= 0; i--) {
                chronologicalEntries.add(entries[i]);
            }

            for (Object obj : chronologicalEntries) {
                Map<String, Object> entry = (Map<String, Object>) obj;
                String msg = (String) entry.get('messageText');

                if (String.isNotBlank(msg)) {
                    total++;
                    Map<String, Object> sender = (Map<String, Object>) entry.get('sender');
                    String role = (sender != null) ? (String) sender.get('role') : 'System';
                    String actorType = (String) entry.get('actorType'); 
                    String displayName = (sender != null) ? (String) sender.get('displayName') : 'Agent';

                    Object tsObj = entry.get('serverReceivedTimestamp');
                    Datetime msgDt = (tsObj != null) ? Datetime.newInstance((Long) tsObj) : null;
                    String formattedTime = (msgDt != null) ? msgDt.format('yyyy-MM-dd HH:mm:ss') : 'Unknown';

                    // STEP 2: Logic - The first 'Agent' we hit in Chronological order is the REAL first response
                    Boolean isHumanAgent = (actorType == 'Agent') || (role == 'Agent' && actorType == null);
                    if (isHumanAgent && firstHumanMsg == null) {
                        firstHumanMsg = msg;
                        firstHumanName = displayName;
                        firstHumanTime = msgDt;
                    }

                    // STEP 3: HTML - Standard appending (+=) puts oldest at the top
                    String color = (role == 'EndUser') ? '#005fb2' : (role == 'Agent') ? '#027e36' : '#747474';
                    htmlTranscript += '<p style="margin-bottom: 10px; border-left: 3px solid ' + color + '; padding-left: 10px;">' +
                                      '<span style="color: #747474; font-size: 0.85em;">' + formattedTime + '</span><br/>' +
                                      '<b style="color: ' + color + ';">' + role.toUpperCase() + ':</b> ' + msg + '</p>';
                }
            }
        }
        htmlTranscript += '</div>';

        return new MSChat_Transcript__c(
            Messaging_Session__c = ms.Id,
            Conversation_Identifier__c = convId,
            Full_Transcript__c = (total > 0) ? htmlTranscript : 'No Transcript Available',
            Total_Messages__c = total,
            First_Agent_Message__c = (firstHumanMsg != null) ? firstHumanMsg.left(255) : null,
            First_Agent_Name__c = firstHumanName,
            First_Agent_Response_Time__c = firstHumanTime,
            Session_End_Time__c = ms.EndTime,
            Status__c = (total > 0) ? 'Completed' : 'No Text Found'
        );
    }
}