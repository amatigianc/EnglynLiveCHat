@isTest
public class MSChatTranscriptTest {
    @testSetup
    static void setup() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'testu', Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8', LastName = 'Testing', LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'mschat_test' + DateTime.now().getTime() + '@example.com'
        );

        System.runAs(testUser) {
            MessagingChannel chan = new MessagingChannel(
                DeveloperName = 'Test_Channel', MasterLabel = 'Test Channel',
                MessageType = 'Text', MessagingPlatformKey = 'Text:12345'
            );
            insert chan;

            MessagingEndUser meu = new MessagingEndUser(
                Name = 'Test User', MessagingChannelId = chan.Id,
                MessageType = 'Text', MessagingPlatformKey = 'Text:12345'
            );
            insert meu;

            MessagingSession ms = new MessagingSession(
                MessagingChannelId = chan.Id,
                MessagingEndUserId = meu.Id,
                Status = 'Ended'
            );
            insert ms;
        }
    }

    @isTest
    static void testCompleteFlow() {
        MessagingSession ms = [SELECT Id FROM MessagingSession LIMIT 1];

        // Inject Conversation relationship for the test
        String serializedMs = '{"attributes":{"type":"MessagingSession"},"Id":"' + ms.Id + '",' +
            '"Conversation":{"attributes":{"type":"Conversation"},"ConversationIdentifier":"MOCK_123"}}';
        MessagingSession mockMs = (MessagingSession) JSON.deserialize(serializedMs, MessagingSession.class);

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();
        MSChatTranscriptService.processSessions(new List<MessagingSession>{ mockMs });
        Test.stopTest();

        MSChat_Transcript__c result = [SELECT Status__c, Total_Messages__c, First_Agent_Name__c, First_Agent_Message__c 
                                      FROM MSChat_Transcript__c WHERE Messaging_Session__c = :ms.Id LIMIT 1];

        System.assertEquals('Completed', result.Status__c);
        System.assertEquals(3, result.Total_Messages__c, 'Should count User, Bot, and Agent');
        System.assertEquals('Giancarlo', result.First_Agent_Name__c, 'Bot should have been skipped');
        System.assertEquals('Hello, I am a human.', result.First_Agent_Message__c);
    }

    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            
            // Note: serverReceivedTimestamp must be Long (no quotes)
            String mockJson = '{ "conversationEntries": [' +
                '{ "messageText": "Help!", "serverReceivedTimestamp": 1714903200000, "actorType": "EndUser", "sender": {"role": "EndUser", "displayName": "Customer"}},' +
                '{ "messageText": "I am a Bot", "serverReceivedTimestamp": 1714903260000, "actorType": "Bot", "sender": {"role": "Agent", "displayName": "Chatbot"}},' +
                '{ "messageText": "Hello, I am a human.", "serverReceivedTimestamp": 1714903320000, "actorType": "Agent", "sender": {"role": "Agent", "displayName": "Giancarlo"}}' +
            ']}';

            res.setBody(mockJson);
            return res;
        }
    }
}