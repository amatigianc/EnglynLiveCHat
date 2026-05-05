@isTest
private class MSChatTranscriptTest {

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"entries": [{"entryType": "Message", "actorType": "EndUser", "timestamp": "2026-05-05T10:00:00.000Z", "messageText": "Hello"}, {"entryType": "Message", "actorType": "Agent", "actorName": "John Doe", "timestamp": "2026-05-05T10:01:00.000Z", "messageText": "Hi"}]}');
            return res;
        }
    }

    private class ErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

   @testSetup
static void setup() {
    User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

    System.runAs(thisUser) {
        // 1. Create MessagingChannel (Setup Object)
        MessagingChannel chan = new MessagingChannel(
            DeveloperName = 'Test_Channel_Final', 
            MasterLabel = 'Test Channel', 
            MessageType = 'Text', 
            MessagingPlatformKey = 'TestKey123'
        );
        insert chan;

        // 2. Create MessagingEndUser (Non-Setup Object)
        // MessagingEndUser REQUIRES MessageType to be explicitly set
        MessagingEndUser deu = new MessagingEndUser(
            MessagingChannelId = chan.Id,
            Name = 'Test User',
            MessagingPlatformKey = 'TestKey123',
            MessageType = 'Text' // Must match the Channel's MessageType
        );
        insert deu;

        // 3. Create MessagingSession (Non-Setup Object)
        MessagingSession ms = new MessagingSession(
            MessagingChannelId = chan.Id,
            MessagingEndUserId = deu.Id,
            Status = 'Active'
        );
        insert ms;
    }
}

    @isTest
    static void testCompleteFlow() {
        MessagingSession ms = [SELECT Id FROM MessagingSession LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        
        Test.startTest();
        // Execute the Batch specifically to ensure logic is covered
        MSChatTranscriptBatchable batch = new MSChatTranscriptBatchable();
        Database.executeBatch(batch);
        Test.stopTest();

        List<MSChat_Transcript__c> results = [SELECT Id, Status__c FROM MSChat_Transcript__c WHERE Messaging_Session__c = :ms.Id];
        System.assertEquals(1, results.size(), 'A transcript record should have been created.');
        System.assertEquals('Completed', results[0].Status__c);
    }

    @isTest
    static void testErrorPath() {
        MessagingSession ms = [SELECT Id FROM MessagingSession LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new ErrorMock());
        
        Test.startTest();
        // Call service directly to verify error handling
        MSChatTranscriptService.processSessions(new List<MessagingSession>{ ms });
        Test.stopTest();

        List<MSChat_Transcript__c> results = [SELECT Id, Status__c FROM MSChat_Transcript__c WHERE Messaging_Session__c = :ms.Id];
        System.assertEquals(1, results.size());
        System.assertEquals('Error', results[0].Status__c);
    }

    @isTest
    static void testScheduler() {
        Test.startTest();
        String jobId = System.schedule('TestMSChatSched', '0 0 0 * * ?', new MSChatTranscriptScheduler());
        Test.stopTest();
        System.assertNotEquals(null, jobId, 'The job should be successfully scheduled.');
    }
}